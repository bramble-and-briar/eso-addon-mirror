if FCOCS == nil then FCOCS = {} end
local FCOChangeStuff = FCOCS
FCOChangeStuff.mailContextMenuButtons = {}

local EM = EVENT_MANAGER
local SM = SCENE_MANAGER

local tos = tostring
local strlow = string.lower
local strup = string.upper
local strsub = string.sub
local tins = table.insert
local tsort = table.sort

local addonVars = FCOChangeStuff.addonVars
local addonName = addonVars.addonName
local addonPrefix = "[" .. addonName .. "]"

local addButton = FCOChangeStuff.AddButton
local throttledUpdate = FCOChangeStuff.ThrottledUpdate

local allowedMailContextMenuOwners = {}
--FCOCS._allowedMailContextMenuOwners = allowedMailContextMenuOwners
local mailContextMenusAtEditFieldsHooked         = false

local uniqueSaveMailValuesUpdaterName = "FCOCS_saveMailUpdater"
local uniqueLoadMailValuesUpdaterName = "FCOCS_loadMailUpdater"

local LSM_contextMenuDefaultOptions = {
    visibleRowsDropdown = 20,
    visibleRowsSubmenu = 15,
    minDropdownWidth = 200,
    --maxDropdownWidth = 600,
    --maxDropdownHeight = 800,
    sortEntries = false,
    enableFilter = true,
    headerCollapsible = true,
    --headerCollapsed = false,
    submenuOpenToSide = "left",
}
local LSM_contextMenuSettingsDefaultOptions = {
    visibleRowsDropdown = 20,
    visibleRowsSubmenu = 15,
    minDropdownWidth = 200,
    --maxDropdownWidth = 600,
    --maxDropdownHeight = 800,
    sortEntries = false,
    enableFilter = true,
    headerCollapsible = true,
    --headerCollapsed = false,
}


local mailSendEditFields = {
    ["recipients"] =    ZO_MailSendToField,
    ["subjects"] =      ZO_MailSendSubjectField,
    ["texts"] =         ZO_MailSendBodyField,
}

local favoriteIcon = "EsoUI/Art/Inventory/inventory_tabIcon_quickslot_up.dds"
local profilesIcon = "/esoui/art/campaign/gamepad/gp_bonusicon_scrolls.dds"
local favoriteIconStr = zo_iconTextFormatNoSpace(favoriteIcon, 24, 24, "", true)

local favoriteText = "|cFFD700" .. favoriteIconStr .. "|rFavorites"
local addAsFavoriteStr = "+|c00FF00Add|r |cFFFFFF%q|r |c00FF00as|r |cFFD700" .. favoriteIconStr .. "|rfavorite"
local deleteFavoriteStr = "-|cFF0000Delete|r |cFFFFFF%q|r |cFF0000from|r |cFFD700" .. favoriteIconStr .. "|rfavorite"
local deleteCurrentFavoriteStr = "-|cFF0000Delete current|r |cFFFFFF%q|r |cFF0000from|r |cFFD700" .. favoriteIconStr .. "|rfavorite"


local profilesText = "|cFFD700" .. zo_iconTextFormatNoSpace(profilesIcon, 24, 24, "|rProfiles", true)
local addAsProfileStr = "+|c00FF00Add as profile|r |cFFFFFF%q|r |cFFD700" .. zo_iconTextFormatNoSpace(profilesIcon, 24, 24, "", true) .. "|r"
local deleteProfileStr = "-|cFF0000Delete profile|r |cFFFFFF%q|r |cFFD700" .. zo_iconTextFormatNoSpace(profilesIcon, 24, 24, "", true) .. "|r"

local maxLastSavedEntries = 25 --save this number of last send recipients/subjects/texts
local mailFavoritesSavedLower = {}
local mailTextsSavedLower = {}

------------------------------------------------------------------------------------------------------------------------
-- Mail --
------------------------------------------------------------------------------------------------------------------------

local mailContextMenutButtonsAdded = false
local isOnMailSendSuccessHooked = false
local isOnMailSendSuccessPostHooked = false
--local isShowMenuHooked = false



local arrowStr = " |u16:0::|u"
local function cleanSubMenuLabelText(labelTextWithArrow)
    return string.gsub(labelTextWithArrow, arrowStr, "")
end

local function mailTextShortener(entryData)
    local stringLength = string.len(entryData)
    if stringLength > 50 then
        return strsub(entryData, 1, 50) .. "..."
    else
        local lineBreakPos = string.find(entryData, '\n', 1, false)
        if lineBreakPos ~= nil and lineBreakPos > 1 then
            if stringLength > 10 then
                return strsub(entryData, 1, lineBreakPos - 1) .. " <line break>..."
            end
        end
    end
    return entryData
end

local function checkIfTabNeedsToBeTruncated(tabToCheck, maxEntries)
    local numEntries = #tabToCheck
    if numEntries > maxEntries then
        for idx=maxEntries+1, numEntries, 1 do
            tabToCheck[idx] = nil
        end
    end
end

local function validateTextField(fieldType, textToValidate, doNotAllowEmpty)
    doNotAllowEmpty = doNotAllowEmpty or false
    if type(textToValidate) ~= "string" then return false end
    if textToValidate == "" then
        return not doNotAllowEmpty
    end

    --Validate recipient
    if fieldType == "recipients" then
        --Do not allow a single @
        if textToValidate == "@" then return false end
    end
    return true
end

local function isAnyFavoriteSettingEnabled()
    local settingsFavorites = FCOChangeStuff.settingsVars.settings.mailFavorites
    for fieldType, isEnabled in pairs(settingsFavorites) do
        if isEnabled == true then return true end
    end
    return false
end


local function updateHiddenStateOfContextMenuButtons(doHide)
    for k,v in pairs(FCOChangeStuff.mailContextMenuButtons) do
        if v ~= nil then v:SetHidden(doHide) end
    end
end

local function getEditBoxByFieldType(fieldType)
    return mailSendEditFields[fieldType]
end

local function getCurrentText(fieldType, notEmpty)
    notEmpty = notEmpty or false
    local editField = getEditBoxByFieldType(fieldType)
    if editField == nil then return end
    local editBoxText = editField:GetText()
    if notEmpty == true and editBoxText == "" then return nil end
    return editBoxText
end

local function updateTextsSavedStringLower(fieldType, isFavorite, textToAdd)
    isFavorite = isFavorite or false
--d("[FCOCS]updateTextsSavedStringLower-fieldType: " ..tos(fieldType) .. ", isFavorite: " ..tos(isFavorite) .. ", textToAdd: " ..tos(textToAdd))
    if type(textToAdd) == "string" and textToAdd ~= "" then
        local textToAddLower = strlow(textToAdd)
        if isFavorite == true then
--d(">1adding lower favorite: " ..tos(textToAddLower))
            mailFavoritesSavedLower[fieldType][textToAddLower] = true
        else
            mailTextsSavedLower[fieldType][textToAddLower] = true
        end
    else
        local settings = FCOChangeStuff.settingsVars.settings
        if isFavorite == true then
            local mailFavoritesSaved = settings.mailFavoritesSaved[fieldType]
            mailFavoritesSavedLower[fieldType] = {}
            for _, textUpper in ipairs(mailFavoritesSaved) do
                local textToAddLower = strlow(textUpper)
--d(">2adding lower favorite: " ..tos(textToAddLower))
                mailFavoritesSavedLower[fieldType][textToAddLower] = true
            end
        else
            local mailTextsSaved = settings.mailTextsSaved[fieldType]
            mailTextsSavedLower[fieldType] = {}
            for _, textUpper in ipairs(mailTextsSaved) do
                local textToAddLower = strlow(textUpper)
                mailTextsSavedLower[fieldType][textToAddLower] = true
            end
        end
    end
end

local function updateLowercaseTextTables()
    --Prepare the lower case string searches
    for fieldType, _ in pairs(mailSendEditFields) do
        updateTextsSavedStringLower(fieldType, true, nil)
        updateTextsSavedStringLower(fieldType, false, nil)
    end
end

local function checkIfNotAlreadyIn(fieldType, isFavorite, entryName, ignoreAlreadyIn, isProfile)
    --d("[FCOCS]checkIfNotAlreadyIn-fieldType: " ..tos(fieldType) ..", isFavorite: " ..tos(isFavorite) .. ", entryName: " ..tos(entryName))
    local currentText
    ignoreAlreadyIn = ignoreAlreadyIn or false

    --Normal singlke editbox update
    if fieldType ~= nil and not isProfile then
        if type(entryName) == "string" and entryName ~= "" then
            currentText = entryName
        else
            --d(">>getting currentText new!")
            currentText = getCurrentText(fieldType)
        end
        local tabToAdd, tabToAddStrLower
        if type(currentText) == "string" and currentText ~= "" then
            local currentTextLower = strlow(currentText)
            --d(">currentText: " ..tos(currentText) .. ", lower: " ..tos(currentTextLower))
            local settings = FCOChangeStuff.settingsVars.settings
            tabToAdd = (isFavorite == true and settings.mailFavoritesSaved[fieldType]) or settings.mailTextsSaved[fieldType]
            tabToAddStrLower = (isFavorite == true and mailFavoritesSavedLower[fieldType]) or mailTextsSavedLower[fieldType]
            --FCOCS._tabToAdd = tabToAdd
            --FCOCS._tabToAddStrLower = tabToAddStrLower
            if tabToAdd ~= nil then
                if tabToAddStrLower[currentTextLower] then
                    if ignoreAlreadyIn == true then
                        --d("<<2 true is not in yet")
                        return true, currentText, tabToAdd, tabToAddStrLower
                    else
                        --d("<<1 false is in already")
                        return false, nil, tabToAdd, tabToAddStrLower
                    end
                else
                    --d("<<2 true is not in yet")
                    return true, currentText, tabToAdd, tabToAddStrLower
                end
            end
        end

    --Profiles
    elseif isProfile == true and type(entryName) == "number" then
        local settings = FCOChangeStuff.settingsVars.settings
        local tabToAdd = settings.mailProfiles
        if tabToAdd ~= nil then
            if tabToAdd[entryName] then
                if ignoreAlreadyIn == true then
                    return true, nil, tabToAdd, nil
                else
                    return false, nil, tabToAdd, nil
                end
            end
        else
            return false, nil, nil, nil
        end
    end

    --d("<<3 false unknown")
    return false, nil, nil, nil
end

local function removeSavedValue(fieldType, isFavorite, entryName, isProfile)
    isFavorite = isFavorite or false
    isProfile = isProfile or false
    --d("[FCOCS]removeSavedValue-fieldType: " ..tos(fieldType) .. ", isFavorite: " ..tos(isFavorite) .. ", entryName: " ..tos(entryName) .. ", isProfile: " .. tos(isProfile))

    --Update of a single field editbox
    if fieldType ~= nil and not isProfile and type(entryName) == "string" then
        local isNotIn, _, tabToRemove, tabToAddStrLower = checkIfNotAlreadyIn(fieldType, isFavorite, entryName, false, false)
    --d(">isNotIn: " ..tos(isNotIn) .. ", tabToRemove: " ..tos(tabToRemove))
        if isNotIn == true or tabToRemove == nil then return end
        local posInTab
        for idx, value in ipairs(tabToRemove) do
            if posInTab == nil and strlow(value) == strlow(entryName) then
                posInTab = idx
                break
            end
        end
    --d(">posInTab: " ..tos(posInTab))
        if posInTab ~= nil then
            table.remove(tabToRemove, posInTab)
            tabToAddStrLower[strlow(entryName)] = nil
        end


    --Profiles: Set multiple edit box values
    elseif fieldType == nil and isProfile == true and type(entryName) == "number" then
        local isNotIn, _, tabToRemove, _ = checkIfNotAlreadyIn(nil, false, entryName, false, true)
    --d(">isNotIn: " ..tos(isNotIn) .. ", tabToRemove: " ..tos(tabToRemove))
        if isNotIn == true or tabToRemove == nil then return end
        table.remove(tabToRemove, entryName)
    end
end

local function updateMailEditBoxText(fieldType, newText, doOverride)
    local editField = getEditBoxByFieldType(fieldType)
    if editField == nil then return end
    if doOverride == nil then
        doOverride = (FCOChangeStuff.settingsVars.settings.overwriteMailFields[fieldType] == true and true) or false
    end
    if doOverride == true or editField:GetText() == "" then
        --d(">doOverride: " ..tos(doOverride) ..", setText: " ..tos(entryData))
        editField:SetText(newText)
    end
end

local function setMailValue(fieldType, entryData, doOverride, isProfile)
--d("[FCOCS]setMailValue: " .. tos(fieldType) .. ", doOverride: " ..tos(doOverride))
    --Set value to single editbox
    if fieldType ~= nil and not isProfile then
        if type(entryData) ~= "string" or entryData == "" then return end

        updateMailEditBoxText(fieldType, entryData, doOverride)

    --Profiles: Set multiple edit box values
    elseif fieldType == nil and isProfile == true and type(entryData) == "number" then
        local profileEntries = FCOChangeStuff.settingsVars.settings.mailProfiles
        local profileEntryData = profileEntries[entryData]
        if profileEntryData == nil then return end

        local recipient = profileEntryData.recipient
        local subject = profileEntryData.subject
        local text = profileEntryData.text
        if ( recipient == nil and subject == nil and text == nil )
                or ( recipient == "" and subject == "" and text == "" ) then
            return
        end

        if recipient ~= "" then
            updateMailEditBoxText("recipients", recipient, doOverride)
        end
        if subject ~= "" then
            updateMailEditBoxText("subjects", subject, doOverride)
        end
        if text ~= "" then
            updateMailEditBoxText("texts", text, doOverride)
        end
    end
end

local function loadLastUsedValue(fieldType)
--d("[FCOCS]loadLastUsedValue-fieldType: " ..tos(fieldType))
    local lastUsedSettings = FCOChangeStuff.settingsVars.settings.mailLastUsed[fieldType]
    if type(lastUsedSettings) ~= "string" or lastUsedSettings == "" then return end
    setMailValue(fieldType, lastUsedSettings, true)
end

local function saveAsFavorit(fieldType, favoriteValue)
--d("[FCOCS]saveAsFavorit-fieldType: " ..tos(fieldType) .. ", favoriteText: " ..tos(favoriteValue))
    local isNotIn, currentText, tabToAdd = checkIfNotAlreadyIn(fieldType, true, favoriteValue, false)
    if isNotIn == true then
--d(">saving new favorite - " ..tos(fieldType) ..": " ..tos(currentText))
        --if validateMailText(fieldType, currentText) == true then
            tins(tabToAdd, currentText)
            tsort(tabToAdd)
            updateTextsSavedStringLower(fieldType, true, currentText)
            return true
        --end
    end
    return false
end

local function saveAsProfile(profileIndex, enteredProfileName)
    if profileIndex == nil or profileIndex <= 0 then return false end
    if enteredProfileName == nil or enteredProfileName == "" then return false end

    local profileEntries = FCOChangeStuff.settingsVars.settings.mailProfiles
    local profileEntryData = profileEntries[profileIndex]
    --Profile does not exist yet
    if profileEntryData == nil then
        --Get current texts of the editboxes and save them
        local newProfileData = {
            _name = enteredProfileName,
            recipient = getCurrentText("recipients", true),
            subject = getCurrentText("subjects", true),
            text = getCurrentText("texts", true),
        }
        profileEntries[profileIndex] = newProfileData
        return true
    else
        return false
    end
end

local function saveAsLastUsedList(fieldType, lastUsedValue)
--d("[FCOCS]saveAsLastUsedList-fieldType: " ..tos(fieldType) .. ", lastUsedText: " ..tos(lastUsedValue))
    local isNotIn, currentText, tabToAdd, tabToAddLower = checkIfNotAlreadyIn(fieldType, false, lastUsedValue, true)
    if isNotIn and type(currentText) ~= "string" or currentText == "" or tabToAdd == nil or tabToAddLower == nil then return false end
--d(">saving new last used list - " ..tos(fieldType) ..": " ..tos(currentText))
    tins(tabToAdd, 1, currentText)
    updateTextsSavedStringLower(fieldType, false, currentText)
    return true
end

local function saveAsLastUsed(fieldType, lastUsedValue)
--d("[FCOCS]saveAsLastUsed-fieldType: " ..tos(fieldType) .. ", lastUsedText: " ..tos(lastUsedValue))
    local currentText = lastUsedValue or getCurrentText(fieldType)
--d(">saving last used - " ..tos(fieldType) ..": " ..tos(currentText))
    local isString = (type(currentText) == "string" and true) or false
    local isNotEmptyString = (isString == true and currentText ~= "" and true) or false
    --Save only "last used" if either non-empty string or empty string at the "text" field
    if isNotEmptyString == true or (isString == true and fieldType == "texts" and currentText == "") then
        FCOChangeStuff.settingsVars.settings.mailLastUsed[fieldType] = currentText
    end
end


local function saveMailValue(fieldType, isFavorite, isLastUsed)
    isFavorite = isFavorite or false
    isLastUsed = isLastUsed or false
--d("[FCOCS]saveMailValue-fieldType: " ..tos(fieldType) .. ", isFavorite: " ..tos(isFavorite) .. ", isLastUsed: " ..tos(isLastUsed))
    if isLastUsed == true then
        saveAsLastUsed(fieldType, nil)
    elseif isFavorite == true then
        saveAsFavorit(fieldType, nil)
    end
end

local function saveLastUsedValue(fieldType)
--d("[FCOCS]saveLastUsedValue-fieldType: " ..tos(fieldType))
    saveAsLastUsed(fieldType)
end

local function addToFavorites(fieldType, favoriteValue)
--d("[FCOCS]addToFavorites-fieldType: " ..tos(fieldType) .. ", favoriteText: " ..tos(favoriteValue))
    return saveAsFavorit(fieldType, favoriteValue)
end

local function addToProfile(profileIndex, recipient, subject)
    --Show dialog where one enters the profile name
    if not ZO_Dialogs_IsDialogRegistered("FCOCS_ADD_MAIL_PROFILE_DIALOG") then
        ZO_Dialogs_RegisterCustomDialog("FCOCS_ADD_MAIL_PROFILE_DIALOG", {
            title =
            {
                text = string.format(addAsProfileStr, profileIndex),
            },
            mainText =
            {
                text = "Add new mail profile name",
            },
            editBox =
            {
                --matchingString = GetString(SI_DESTROY_ITEM_CONFIRMATION)
                --defaultText =
            },
            noChoiceCallback =  function()

            end,
            buttons =
            {
                {
                    requiresTextInput = true,
                    text =      "Save as profile",
                    callback =  function(dialog)
                        local enteredProfileName = ZO_Dialogs_GetEditBoxText(dialog)
                        if enteredProfileName ~= nil and enteredProfileName ~= "" then
                            --d(">dialog.data.profileIndex = " .. tos(dialog.data.profileIndex))
                            return saveAsProfile(dialog.data.profileIndex, enteredProfileName)
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                    callback = function(dialog)
                    end,
                }
            }
        })
    end
    ZO_Dialogs_ShowPlatformDialog("FCOCS_ADD_MAIL_PROFILE_DIALOG", { profileIndex = profileIndex, editBoxText = recipient .. "_" .. subject }, { title = { text = string.format(addAsProfileStr, profileIndex) } })
end

local function afterMailWasSend(doSaveLast, doLoadLast)
--d("[FCOCS]afterMailWasSend-doSaveLast: " ..tos(doSaveLast) .. ", doLoadLast: " ..tos(doLoadLast))
    if not doSaveLast and not doLoadLast then return end

    local settings = FCOChangeStuff.settingsVars.settings
    local autoLoadMailFields = settings.autoLoadMailFields
    local autoLoadMailWasSendSettings = settings.autoLoadMailFieldsAt.mailWasSend
    for fieldType, isEnabled in pairs(autoLoadMailFields) do
--d(">fieldType: " ..tos(fieldType) .. ", enabled: " ..tos(isEnabled))
        if isEnabled == true then
            if doSaveLast == true then
                --Save currently used data
                saveLastUsedValue(fieldType)

            elseif doLoadLast == true then
                if autoLoadMailWasSendSettings[fieldType] == true then
                    loadLastUsedValue(fieldType)
                end
            end
        end
    end
end

local function checkAndSaveMailValuesOfEnabledFields(wasSuccess, sendMailResult)
--d("[FCOCS]checkAndSaveMailValuesOfEnabledFields-success: " ..tos(wasSuccess))
    wasSuccess = wasSuccess or false
    local settings = FCOChangeStuff.settingsVars.settings

    --Save the curently send email recipient, subject & text to load it directly to next
    --email message?
    if wasSuccess == true then
        afterMailWasSend(true, false)

        --Save the 10 last used per field
        for fieldType, _ in pairs(mailSendEditFields) do
            saveAsLastUsedList(fieldType, nil)
        end
    end

    local saveMailFields = settings.saveMailFields
    for fieldType, isEnabled in pairs(saveMailFields) do
        if isEnabled == true then
            if sendMailResult ~= nil and fieldType == "recipient" and sendMailResult == MAIL_SEND_RESULT_FAIL_INVALID_NAME then
--d("<invalid recipient for mail: Do not save!")
            else
                --Save as last used
                saveMailValue(fieldType, false, true)
            end
        end
    end
end

local function checkAndLoadMailValuesOfEnabledFields()
--d("[FCOCS]checkAndLoadMailValuesOfEnabledFields")
    local settings = FCOChangeStuff.settingsVars.settings
    local autoLoadMailFields = settings.autoLoadMailFields
    local openMailFields = settings.autoLoadMailFieldsAt.mailOpen
    for fieldType, isEnabled in pairs(openMailFields) do
        if isEnabled == true and autoLoadMailFields[fieldType] == true then
            loadLastUsedValue(fieldType)
        end
    end
end

local function checkMaxFavoritesAndCreateSubMenus(fieldType, noAdd)
    noAdd = noAdd or false
    local wasSomethingAdded = false

    local settings = FCOChangeStuff.settingsVars.settings
    local favEntries = settings.mailFavoritesSaved[fieldType]
    local splitMailFavoritesIntoAlphabet = settings.splitMailFavoritesIntoAlphabet
    local numFavorites = #favEntries

    if numFavorites > 0 or not noAdd then
        AddCustomScrollableMenuEntry(favoriteText, function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
        wasSomethingAdded = true
    end

    --Existing favorites
    if numFavorites > 0 then

        if splitMailFavoritesIntoAlphabet == true then
            --Too many entries in favorites, build submenus A-E, F-J, K-O, P-T, U-Z
            local aToE = {}
            local fToJ = {}
            local kToO = {}
            local pToT = {}
            local uToZ = {}
            local others = {}

            for _, favEntryData in ipairs(favEntries) do
                local firstChar = strlow(strsub(favEntryData, 1, 1))
                --Skip the @displayName character
                if firstChar == "@" then
                    firstChar = strlow(strsub(favEntryData, 2, 2))
                end

                local tabToAdd
                if (firstChar >= 'a' and firstChar <= 'e') or firstChar == 'ä' then
                    tabToAdd = aToE
                elseif firstChar >= 'f' and firstChar <= 'j' then
                    tabToAdd = fToJ
                elseif (firstChar >= 'k' and firstChar <= 'o')  or firstChar == 'ö' then
                    tabToAdd = kToO
                elseif firstChar >= 'p' and firstChar <= 't' then
                    tabToAdd = pToT
                elseif (firstChar >= 'u' and firstChar <= 'z')  or firstChar == 'ü' then
                    tabToAdd = uToZ
                else
                    tabToAdd = others
                end
                if tabToAdd == nil then tabToAdd = others end

                local shortText = mailTextShortener(favEntryData)
                local favEntryDataInSubmenu = {
                    label    = shortText,
                    callback = function()
                        setMailValue(fieldType, favEntryData)
                    end,
                    isAlphabeticallySplitHeadline = true,
                    entries = {
                        {
                            label    = "Select \'" .. shortText .. "\'",
                            callback = function()
                                setMailValue(fieldType, favEntryData)
                            end,
                        },
                        {
                            entryType = LSM_ENTRY_TYPE_DIVIDER,
                        },
                        {
                            label = string.format(deleteFavoriteStr, shortText),
                            callback = function()
                                removeSavedValue(fieldType, true, favEntryData)
                            end,
                        },
                    }
                }
                tabToAdd[#tabToAdd + 1] = favEntryDataInSubmenu
            end

            if #aToE > 0 then
                AddCustomScrollableSubMenuEntry("A - E", aToE)
                wasSomethingAdded = true
            end
            if #fToJ > 0 then
                AddCustomScrollableSubMenuEntry("F - J", fToJ)
                wasSomethingAdded = true
            end
            if #kToO > 0 then
                AddCustomScrollableSubMenuEntry("K - O", kToO)
                wasSomethingAdded = true
            end
            if #pToT > 0 then
                AddCustomScrollableSubMenuEntry("P - T", pToT)
                wasSomethingAdded = true
            end
            if #uToZ > 0 then
                AddCustomScrollableSubMenuEntry("U - Z", uToZ)
                wasSomethingAdded = true
            end
            if #others > 0 then
                AddCustomScrollableSubMenuEntry("Other", others)
                wasSomethingAdded = true
            end

        else
            for _, favEntryData in ipairs(favEntries) do
                local shortText = mailTextShortener(favEntryData)
                local favEntryDataSubmenu = {
                    {
                        label    = "Select \'" .. shortText .. "\'",
                        callback = function()
                            setMailValue(fieldType, favEntryData)
                        end,
                    },
                    {
                        entryType = LSM_ENTRY_TYPE_DIVIDER,
                    },
                    {
                        --label    = "|cff0000- Delete|r \'" .. shortText .. "\'",
                        label = string.format(deleteFavoriteStr, shortText),
                        callback = function()
                            removeSavedValue(fieldType, true, favEntryData)
                        end,
                    },
                }
                --AddCustomScrollableMenuEntry(favEntryData, function() setMailValue(fieldType, favEntryData) end)
                AddCustomScrollableSubMenuEntry(favEntryData, favEntryDataSubmenu, function() setMailValue(fieldType, favEntryData)  end)
                --AddCustomScrollableMenuEntry(favEntryData, function() setMailValue(fieldType, favEntryData)  end, LSM_ENTRY_TYPE_SUBMENU, favEntryDataSubmenu, nil)
                wasSomethingAdded = true
            end
        end
    end

    --Add new favorite
    if not noAdd then
        local isNotIn, currentText, _ = checkIfNotAlreadyIn(fieldType, true, nil, false)
        if isNotIn == true then
            local shortText = mailTextShortener(currentText)
            currentText = string.format(addAsFavoriteStr, shortText)
            AddCustomScrollableMenuEntry(currentText, function() addToFavorites(fieldType, nil) end)
            wasSomethingAdded = true
        end
    end

    return wasSomethingAdded
end

local function checkMaxProfilesAndCreateSubMenus(noAdd)
    noAdd = noAdd or false
    local wasSomethingAdded = false

    local settings                      = FCOChangeStuff.settingsVars.settings
    local profileEntries                = settings.mailProfiles
    --local splitMailProfilesIntoAlphabet = settings.splitMailProfilesIntoAlphabet
    local numProfiles                   = #profileEntries

    if numProfiles > 0 and not noAdd then
        AddCustomScrollableMenuEntry(profilesText, function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
        wasSomethingAdded = true
    end

    --Existing profiles
    if numProfiles > 0 then
        for profileIndex, profileEntryData in ipairs(profileEntries) do
            local profileName = profileEntryData._name
            if profileName == nil then return end

            local recipient = profileEntryData.recipient
            local subject = profileEntryData.subject
            local text = profileEntryData.text
            if ( recipient == nil and subject == nil and text == nil )
                    or ( recipient == "" and subject == "" and text == "" ) then
                return
            end

            local shortText               = mailTextShortener(profileName)
            local profileEntryDataSubmenu = {
                {
                    label    = "Select \'" .. shortText .. "\'",
                    callback = function()
                        setMailValue(nil, profileIndex, nil, true)
                    end,
                },
            }



            local profileData = profileEntries[profileIndex]
            if profileData ~= nil then
                if profileData.recipient ~= nil then
                    profileEntryDataSubmenu[#profileEntryDataSubmenu +1] = {
                        label    = "Recipient: \'" .. profileData.recipient .. "\'",
                        callback = function()
                        end,
                        enabled = false,
                    }
                end
                if profileData.subject ~= nil then
                    local shortTextSubject = mailTextShortener(profileData.subject)
                    profileEntryDataSubmenu[#profileEntryDataSubmenu +1] = {
                        label    = "Subject: \'" .. shortTextSubject .. "\'",
                        callback = function()
                        end,
                        enabled = false,
                    }
                end
                if profileData.text ~= nil then
                    local shortTextText = mailTextShortener(profileData.text)
                    profileEntryDataSubmenu[#profileEntryDataSubmenu +1] = {
                        label    = "Text: \'" .. shortTextText .. "\'",
                        callback = function()
                        end,
                        enabled = false,
                    }
                end
            end
            profileEntryDataSubmenu[#profileEntryDataSubmenu +1] = {
                entryType = LSM_ENTRY_TYPE_DIVIDER,
            }
            profileEntryDataSubmenu[#profileEntryDataSubmenu +1] = {
                label = string.format(deleteProfileStr, shortText),
                callback = function()
                    removeSavedValue(nil, false, profileIndex, true)
                end,
            },

            --AddCustomScrollableMenuEntry(favEntryData, function() setMailValue(fieldType, favEntryData) end)
            AddCustomScrollableSubMenuEntry(profileName, profileEntryDataSubmenu, function() setMailValue(nil, profileIndex, nil, true)  end)
            --AddCustomScrollableMenuEntry(profileName, function() setMailValue(nil, profileIndex, nil, true)  end, LSM_ENTRY_TYPE_SUBMENU, profileEntryDataSubmenu, nil)
            wasSomethingAdded = true
        end
        --end
    end

    --Add new profile
    --[[
    if not noAdd then
        local isNotIn, currentText, _ = checkIfNotAlreadyIn(nil, false, nil, false, true)
        if isNotIn == true then
            local shortText = mailTextShortener(currentText)
            currentText = string.format(addAsProfileStr, shortText)
            AddCustomScrollableMenuEntry(currentText, function() addToProfile(nil) end)
            wasSomethingAdded = true
        end
    end
    ]]

    return wasSomethingAdded
end

local settingsForLSMContextMenu
local function onMouseUpAtMailEditBox(fieldType, isTriangleButton, editCtrl, button, upInside)
    if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
        ClearCustomScrollableMenu()
        settingsForLSMContextMenu = settingsForLSMContextMenu or ZO_ShallowTableCopy(LSM_contextMenuDefaultOptions)
        local loc_settings = FCOChangeStuff.settingsVars.settings
        if not loc_settings.mailContextMenus then
            if not isTriangleButton then
                return false
            end
        end

        local mailContextMenuButton = (isTriangleButton and FCOChangeStuff.mailContextMenuButtons[fieldType]) or nil
        local controlToAddContextMenuTo = (isTriangleButton and mailContextMenuButton) or editCtrl

        local mailProfilesContextMenusEntriesAtEditFieldsAdded = false
        local mailFavoritesContextMenusEntriesAtEditFieldsAdded = false
        local mailLastUsedContextMenusEntriesAtEditFieldsAdded = false
        local addProfilePossible = false
        local wasProfilesAdded         = false
        local addOrDeleteFavoriteAdded = false
        local wasFavoritesAdded        = false

        --d("[FCOCS]onMouseUpAtMailEditBox: " ..tos(editCtrl:GetName()) .. ", enabled: " ..tos(FCOChangeStuff.settingsVars.settings.mailFavoritesContextMenusAtEditFields) )
        local mailFavoritesContextMenusAtEditFields = (isTriangleButton and true) or loc_settings.mailFavoritesContextMenusAtEditFields
        local mailLastUsedContextMenusAtEditFields =  (isTriangleButton and true) or loc_settings.mailLastUsedContextMenusAtEditFields
        local mailprofilesEnabled = (isTriangleButton and true) or loc_settings.enableMailProfiles


        local currentText = editCtrl:GetText()
        local isEmpty = (type(currentText) == "string" and currentText == "" and true) or false
        --d(">currentText " ..tos(currentText))

        --Generic entries
        if isEmpty == false then
            AddCustomScrollableMenuEntry("Clear edit field", function() editCtrl:SetText("") end)
        else
            if not isTriangleButton then
                if (not mailFavoritesContextMenusAtEditFields and not mailLastUsedContextMenusAtEditFields and not mailprofilesEnabled) then return end
            end
        end


        --Mail profiles
        local addOrDeleteProfileAdded = false
        if mailprofilesEnabled and fieldType == "recipients" then
            editCtrl._type = fieldType
            allowedMailContextMenuOwners[editCtrl] = true

            local mailProfiles = loc_settings.mailProfiles

            --Check if profile can be saved, needs recipient and subject at least
            local recipient = currentText
            local subject = getCurrentText("subjects")
            local textVal = getCurrentText("texts")

            local isValidatedRecipient = validateTextField("recipients", recipient, true)
            local isValidatedSubject = validateTextField("subjects", subject, true)
            local isValidatedText = validateTextField("texts", textVal, true)
            if (isValidatedRecipient == true and isValidatedSubject == true) or (isValidatedRecipient == true and isValidatedText == true) or
                    (isValidatedSubject == true and isValidatedText == true) then
                addProfilePossible = true

                --Check if profile with same data exists already
                for idx, mailProfileData in ipairs(mailProfiles) do
                    if ((mailProfileData.recipient ~= nil and mailProfileData.recipient == recipient) or (mailProfileData.recipient == nil and recipient == "")) and
                            ((mailProfileData.subject ~= nil and mailProfileData.subject == subject) or (mailProfileData.subject == nil and subject == "")) and
                            ((mailProfileData.text ~= nil and mailProfileData.text == textVal) or (mailProfileData.text == nil and textVal == "")) then
                        addProfilePossible = false
                        break
                    end
                end

                if addProfilePossible == true then
                    AddCustomScrollableMenuEntry(profilesText, function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
                    mailProfilesContextMenusEntriesAtEditFieldsAdded = true
                end
            end


            wasProfilesAdded = checkMaxProfilesAndCreateSubMenus(addProfilePossible)
            if wasProfilesAdded == true then
                AddCustomScrollableMenuDivider()
            end

            --Profile could be added, so show menu entry for it
            if addProfilePossible == true then
                --Add new profile or remove existing
                local numProfiles = #mailProfiles
                local nextProfileNum = numProfiles + 1

                --How to check if profile is already in? Can't so just assume it isn't and user self cleans up duplicates
                local isNotIn = true

                if isNotIn == true then
                    --Add new profile
                    local addAsProfileText = string.format(addAsProfileStr, "#" .. tos(nextProfileNum))
                    AddCustomScrollableMenuEntry(addAsProfileText, function() addToProfile(nextProfileNum, recipient, subject) end)
                    addOrDeleteProfileAdded = true
                    mailProfilesContextMenusEntriesAtEditFieldsAdded = true
                --else
                    --[[
                    --Remove existing favorite
                    local deleteText = string.format(deleteProfileStr, "#" .. tos(nextProfileNum))
                    AddCustomScrollableMenuEntry(deleteText, function() removeSavedValue(nil, false, currentText, true) end)
                    addOrDeleteProfileAdded = true
                    ]]
                    --todo Provide submenu with profiles and a submenu entry "Remove #n"
                end
            end
        end

        --Favorites
        if mailFavoritesContextMenusAtEditFields and loc_settings.mailFavorites[fieldType] == true then
            --d(">>settings for favorites: ON")
            editCtrl._type = fieldType
            allowedMailContextMenuOwners[editCtrl] = true

            if addOrDeleteProfileAdded == true then
                AddCustomScrollableMenuDivider()
            end

            wasFavoritesAdded = checkMaxFavoritesAndCreateSubMenus(fieldType, true)
            if wasFavoritesAdded == true then
                AddCustomScrollableMenuDivider()
            end

            local isValidated = validateTextField(fieldType, currentText)
            --d(">>isValidated: " ..tos(isValidated))
            if isValidated == true then
                --Add new favorite or remove existing
                local isNotIn, _, shortText
                if isEmpty == true then
                    isNotIn = true
                else
                    isNotIn, _, _ = checkIfNotAlreadyIn(fieldType, true, currentText, false)
                    shortText = mailTextShortener(currentText)
                end
                if isEmpty == false then
                    if isNotIn == true then
                        --Add new favorite
                        currentText = string.format(addAsFavoriteStr, shortText)
                        AddCustomScrollableMenuEntry(currentText, function() addToFavorites(fieldType, nil) end)
                        addOrDeleteFavoriteAdded = true
                    else
                        --Remove existing favorite
                        local deleteText = string.format(deleteCurrentFavoriteStr, shortText)
                        AddCustomScrollableMenuEntry(deleteText, function() removeSavedValue(fieldType, true, currentText) end)
                        addOrDeleteFavoriteAdded = true
                    end
                    mailFavoritesContextMenusEntriesAtEditFieldsAdded = true
                end
            end
        end

        --Last used
        if mailLastUsedContextMenusAtEditFields then
            --The last used entry
            local lastUsedEntry = loc_settings.mailLastUsed[fieldType]
            if type(lastUsedEntry) == "string" and lastUsedEntry ~= ""  then
                AddCustomScrollableMenuEntry("Last used", function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
                AddCustomScrollableMenuEntry(lastUsedEntry, function() setMailValue(fieldType, lastUsedEntry) end)
                mailLastUsedContextMenusEntriesAtEditFieldsAdded = true
            end

            --Last 25 used
            local entries = loc_settings.mailTextsSaved[fieldType]
            checkIfTabNeedsToBeTruncated(entries, maxLastSavedEntries)
            FCOChangeStuff.settingsVars.settings.mailTextsSaved[fieldType] = entries --Update the last 25 to the SV again
            if #entries > 0 then
                AddCustomScrollableMenuEntry("Last " ..tos(maxLastSavedEntries), function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
                local lastUsedEntryDataSubmenu = {}
                for idx, entryData in ipairs(entries) do
                    local shortText = mailTextShortener(entryData)
                    tins(lastUsedEntryDataSubmenu,
                        {
                            label    = tos(idx) ..". \'" .. shortText .. "\'",
                            callback = function()
                                setMailValue(fieldType, entryData)
                            end,
                        }
                    )
                    --AddCustomScrollableMenuEntry(shortText, function() setMailValue(fieldType, entryData) end)
                end
                AddCustomScrollableSubMenuEntry(strup(fieldType), lastUsedEntryDataSubmenu)
                mailLastUsedContextMenusEntriesAtEditFieldsAdded = true
            end
        end



------------------------------------------------------------------------------------------------------------------------
        --Show the context menu now
        if isEmpty == false or (
                (mailFavoritesContextMenusEntriesAtEditFieldsAdded or addOrDeleteFavoriteAdded or wasFavoritesAdded)
                        or mailLastUsedContextMenusEntriesAtEditFieldsAdded
                        or (mailProfilesContextMenusEntriesAtEditFieldsAdded or wasProfilesAdded or addProfilePossible)
        ) then
            if loc_settings.mailContextMenuSubmenusForceOpenToTheLeft == true then
                settingsForLSMContextMenu.submenuOpenToSide = "left"
            else
                settingsForLSMContextMenu.submenuOpenToSide = nil --let LSM choose automatically
            end
            ShowCustomScrollableMenu(controlToAddContextMenuTo, settingsForLSMContextMenu)
        else
            editCtrl._type = nil
            allowedMailContextMenuOwners[editCtrl] = nil
        end
    end
end

local function addMailFieldsContextMenuHooks()
--d(">>HOOKING....")
    for fieldType, editFieldCtrl in pairs(mailSendEditFields) do
--d(">fieldType: " ..tos(fieldType))
        if editFieldCtrl ~= nil then
            local currentHandler = editFieldCtrl:GetHandler("OnMouseUp")
            if currentHandler == nil then
                --d(">Setting handler at: " .. tos(editFieldCtrl:GetName()))
                editFieldCtrl:SetHandler("OnMouseUp", function(...) return onMouseUpAtMailEditBox(fieldType, false, ...) end)
            else
                --d(">PostHooking existing handler at: " .. tos(editFieldCtrl:GetName()))
                ZO_PostHookHandler(editFieldCtrl, "OnMouseUp", function(...) return onMouseUpAtMailEditBox(fieldType, false, ...) end)
            end
            mailContextMenusAtEditFieldsHooked = true
        else
--d("<editFieldControl is NIL!")
        end
    end
end

local function updateMailContextMenuButtonContextMenus(fieldType)
    if FCOChangeStuff.mailContextMenuButtons[fieldType] ~= nil then
        onMouseUpAtMailEditBox(fieldType, true, mailSendEditFields[fieldType], MOUSE_BUTTON_INDEX_RIGHT, true)
    end
end

local function checkIfEditBoxContextMenusNeedAnUpdate()
--d("[FCOCS]checkIfEditBoxContextMenusNeedAnUpdate")
    if mailContextMenusAtEditFieldsHooked == true then return end
    addMailFieldsContextMenuHooks()
end

--[[
h5. SendMailResult
* MAIL_SEND_RESULT_CANCELED
* MAIL_SEND_RESULT_CANT_SEND_CASH_COD
* MAIL_SEND_RESULT_CANT_SEND_TO_SELF
* MAIL_SEND_RESULT_FAIL_BLANK_MAIL
* MAIL_SEND_RESULT_FAIL_DB_ERROR
* MAIL_SEND_RESULT_FAIL_IGNORED
* MAIL_SEND_RESULT_FAIL_INVALID_NAME
* MAIL_SEND_RESULT_FAIL_IN_PROGRESS
* MAIL_SEND_RESULT_FAIL_MAILBOX_FULL
* MAIL_SEND_RESULT_INVALID_ITEM
* MAIL_SEND_RESULT_MAILBOX_NOT_OPEN
* MAIL_SEND_RESULT_MAIL_DISABLED
* MAIL_SEND_RESULT_NOT_ENOUGH_ITEMS_FOR_COD
* MAIL_SEND_RESULT_NOT_ENOUGH_MONEY
* MAIL_SEND_RESULT_RECIPIENT_NOT_FOUND
* MAIL_SEND_RESULT_SUCCESS
* MAIL_SEND_RESULT_TOO_MANY_ATTACHMENTS
]]
local function onEventMailSendFailed(eventId, sendMailResult)
--d("[FCOCS]Mail send failed-result: " ..tos(sendMailResult))
    throttledUpdate = throttledUpdate or FCOChangeStuff.ThrottledUpdate
    throttledUpdate(uniqueSaveMailValuesUpdaterName, 50, checkAndSaveMailValuesOfEnabledFields, false, sendMailResult)
end

--[[
local function onEventMailSendSuccess(eventId, playerName)
--d("[FCOCS]Mail successfully send to: " ..tos(playerName))
    throttledUpdate = throttledUpdate or FCOChangeStuff.ThrottledUpdate
    throttledUpdate(uniqueSaveMailValuesUpdaterName, 50, checkAndSaveMailValuesOfEnabledFields, true)
end
]]

local function onEventMailCloseMailbox(eventId)
--d("[FCOCS]Mail close")
    --This callback seems to fire twice each time?
    throttledUpdate = throttledUpdate or FCOChangeStuff.ThrottledUpdate
    throttledUpdate(uniqueSaveMailValuesUpdaterName, 50, checkAndSaveMailValuesOfEnabledFields, false)
end


local function onEventMailOpenMailbox(eventId)
--d("[FCOCS]Mail open")
    --Check context menus at edit fields
    checkIfEditBoxContextMenusNeedAnUpdate()
    updateLowercaseTextTables()

    throttledUpdate = throttledUpdate or FCOChangeStuff.ThrottledUpdate
    throttledUpdate(uniqueSaveMailValuesUpdaterName, 50, checkAndLoadMailValuesOfEnabledFields)
end


local function eventCallBackFuncHandler(eventId, ...)
--d("[FCOCS]eventId: " ..tos(eventId))
    --if eventId == EVENT_MAIL_SEND_SUCCESS then
    --        return onEventMailSendSuccess(eventId, ...)
    if eventId == EVENT_MAIL_SEND_FAILED then
        return onEventMailSendFailed(eventId, ...)
    elseif eventId == EVENT_MAIL_CLOSE_MAILBOX then
        return onEventMailCloseMailbox(eventId, ...)
    elseif eventId == EVENT_MAIL_OPEN_MAILBOX then
        return onEventMailOpenMailbox(eventId, ...)
    end
    return
end

local function setMailEventHandlers(eventType, doEnable)
    doEnable = doEnable or false
    if eventType == EVENT_MAIL_SEND_SUCCESS or eventType == EVENT_MAIL_SEND_FAILED or eventType == EVENT_MAIL_CLOSE_MAILBOX then
        EM:UnregisterForEvent(addonName .. "-MAIL_SEND-" .. tos(eventType), eventType)
        if doEnable == true then
            local saveMailFields = FCOChangeStuff.settingsVars.settings.saveMailFields
            for k, v in pairs(saveMailFields) do
                if v == true then
--d(">registering mail_send/close event " ..tos(eventType))
                    EM:RegisterForEvent(addonName .. "-MAIL_SEND-" .. tos(eventType), eventType, function(eventId, ...) eventCallBackFuncHandler(eventId, ...) end)
                    return true
                end
            end
        else
            return true
        end
    elseif eventType == EVENT_MAIL_OPEN_MAILBOX then
        EM:UnregisterForEvent(addonName .. "-MAIL_OPEN-" .. tos(eventType), eventType)
        if doEnable == true then
            local autoLoadOnOpenMailFields = FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailOpen
            for k, v in pairs(autoLoadOnOpenMailFields) do
                if v == true then
--d(">registering onOpen event " ..tos(eventType))
                    EM:RegisterForEvent(addonName .. "-MAIL_OPEN-" .. tos(eventType), eventType, function(eventId, ...) eventCallBackFuncHandler(eventId, ...) end)
                    return true
                end
            end
        else
            return true
        end
    end
    return false
end

local function checkAndEnabledEventHandlersIfNeeded(doEnable)
    doEnable = doEnable or false
--d("[FCOCS]checkAndEnabledEventHandlersIfNeeded-doEnable:" ..tos(doEnable))
    --setMailEventHandlers(EVENT_MAIL_SEND_SUCCESS,   doEnable)
    setMailEventHandlers(EVENT_MAIL_SEND_FAILED,    doEnable)
    setMailEventHandlers(EVENT_MAIL_CLOSE_MAILBOX,  doEnable)

    setMailEventHandlers(EVENT_MAIL_OPEN_MAILBOX,   doEnable)
    --[[
    --ONly fires once!
    SCENE_MANAGER:CallWhen("mailSend", SCENE_SHOWN, function()
        onEventMailOpenMailbox(EVENT_MAIL_OPEN_MAILBOX)
    end)
    ]]
end


--MailBuddy support
local function loadMailBuddyData(fieldType, asFavorite)
    --d("[FCOCS]loadMailBuddyData - type: " ..tos(fieldType) .. ", favorite: " ..tos(asFavorite))
    asFavorite = asFavorite or false
    if not MailBuddy or not MailBuddy_SavedVars then return end
    if fieldType == nil or fieldType == "" then return end

    local mbSettings = MailBuddy.settingsVars.settings
    if mbSettings == nil then return end

    if fieldType == "recipients" then
        local mbRecipients = mbSettings.SetRecipient
        if mbRecipients == nil or #mbRecipients <= 0 then return end
        for _, recipient in ipairs(mbRecipients) do
            if type(recipient) == "string" and recipient ~= "" then
                if addToFavorites(fieldType, recipient) == true then
                    d(addonPrefix .. "\'MailBuddy\' recipient added: " ..tos(recipient))
                end
            end
        end

    elseif fieldType == "subjects" then
        --Add the fixed subjects PTS, RETURN and BOUNCE
        local mbFixedSubjects = {
            "RTS",
            "RETURN",
            "BOUNCE"
        }
        for _, subject in ipairs(mbFixedSubjects) do
            if type(subject) == "string" and subject ~= "" then
                if addToFavorites(fieldType, subject) == true then
                    d(addonPrefix .. "\'MailBuddy\' fixed subject added: " ..tos(subject))
                end
            end
        end
        --Now add the user added subjects
        local mbSubjects = mbSettings.SetSubject
        if mbSubjects == nil or #mbSubjects <= 0 then return end
        for _, subject in ipairs(mbSubjects) do
            if type(subject) == "string" and subject ~= "" then
                if addToFavorites(fieldType, subject) == true then
                    d(addonPrefix .. "\'MailBuddy\' subject added: " ..tos(subject))
                end
            end
        end

    elseif fieldType == "texts" then
        return --not supported
    end
end

local mailsToDelete
local function resetQueuedMailes()
    mailsToDelete = {}
end

local function deleteMailNow(mailEntryData)
    local doChatOutput = true
    if doChatOutput == true then
        d("[FCOCS]Deleting mail from: " .. tos(mailEntryData.senderDisplayName) .. tos(mailEntryData.senderCharacterName ~= nil and ("/" .. mailEntryData.senderCharacterName) or "") .. ", subject: " ..tos(mailEntryData.formattedSubject))
    end
    DeleteMail(mailEntryData.mailId)
end

local function deleteQueuedMails()
    if ZO_IsTableEmpty(mailsToDelete) then return end

    local mailDeleteDelay = FCOChangeStuff.settingsVars.settings.mailDeleteDelay
    local delay = 0
    for _, mailEntryData in ipairs(mailsToDelete) do
        if mailDeleteDelay == 0 then
            deleteMailNow(mailEntryData)
        else
            local mailEntryDataCopy = ZO_ShallowTableCopy(mailEntryData)
            zo_callLater(function()
                deleteMailNow(mailEntryDataCopy)
            end, delay)
            delay = delay + mailDeleteDelay
        end
    end
    resetQueuedMailes()
end

local doDebug = false --todo change for debugging
local function checkDeleteMailWithCriteria(mailEntryData, mailCategory, isUnread, maxAttachments, maxCODAmount)
    if mailEntryData == nil or mailEntryData.mailId == nil or mailCategory == nil or isUnread == nil then return false end
    maxAttachments = maxAttachments or 0
    maxCODAmount = maxCODAmount or 0

    if doDebug then
        d("[FCOCS]Checking mail ID: " .. tos(zo_getSafeId64Key(mailEntryData.mailId))
                .. ", from: " .. tos(mailEntryData.senderDisplayName) .. "/" .. tos(mailEntryData.senderCharacterName ~= nil and mailEntryData.senderCharacterName or "???")
                .. ", category: " ..tos(mailEntryData.category) .. " [" .. tos(mailCategory).."]"
                .. ", unread: " ..tos(mailEntryData.unread) .. " [" .. tos(isUnread).."]"
                .. ", numAttachments: " ..tos(mailEntryData.numAttachments) .. " [" .. tos(maxAttachments).."]"
                .. ", codAmount: " ..tos(mailEntryData.codAmount) .. " [" .. tos(maxCODAmount).."]"
        )
    end

    return (mailEntryData.mailId ~= nil and mailEntryData.category == mailCategory
                and mailEntryData.unread == isUnread
                and mailEntryData.numAttachments <= maxAttachments
                and mailEntryData.codAmount <= maxCODAmount and true
                and mailEntryData.attachedMoney == 0
            ) or false
end

--Delete all empty mails (with no attachments anymore) received form any player
local function deleteEmptyPlayerMails(isUnread)
    resetQueuedMailes()
    if isUnread == nil then return end
    local MailInbox = MAIL_INBOX
    local masterList = (MailInbox ~= nil and MailInbox.masterList) or nil
    if masterList == nil or #masterList <= 0 then return end

    local anyMailDeleteWasQueued = false

    for idx, mailEntryData in ipairs(masterList) do
        --Only player send mails which are read, got no attachments (anymore), and no COD
        if checkDeleteMailWithCriteria(mailEntryData, MAIL_CATEGORY_PLAYER_MAIL, isUnread, 0, 0) == true then
            mailsToDelete[#mailsToDelete + 1] = mailEntryData
            anyMailDeleteWasQueued = true
        end
    end

    if anyMailDeleteWasQueued then
        deleteQueuedMails()
    end
end

local function isAnyMailInInbox()
    local masterList = MAIL_INBOX and MAIL_INBOX.masterList or nil
    return masterList ~= nil and #masterList > 0
end

local function getMailReceivedMassChangeContextMenu()
    local contextMenuCallbackFunc = function()
        ClearCustomScrollableMenu()
        local settings = FCOChangeStuff.settingsVars.settings
        if not settings.mailContextMenus then return false end

        AddCustomScrollableMenuHeader("Mass-Change", function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })
        AddCustomScrollableMenuEntry("Delete read player mails, w/o attachments",               function() deleteEmptyPlayerMails(false) end,   LSM_ENTRY_TYPE_NORMAL, nil, { enabled = function() return isAnyMailInInbox() end })
        AddCustomScrollableMenuEntry("Delete |cFF0000un|rread player mails, w/o attachments",   function() deleteEmptyPlayerMails(true) end,    LSM_ENTRY_TYPE_NORMAL, nil, { enabled = function() return isAnyMailInInbox() end })

        ShowCustomScrollableMenu(FCOChangeStuff.mailContextMenuButtons["Inbox_MassChange"], LSM_contextMenuSettingsDefaultOptions)
    end
    return contextMenuCallbackFunc()
end

local function getMailSettingsContextMenu()
    local contextMenuCallbackFunc = function()
        ClearCustomScrollableMenu()
        local settings = FCOChangeStuff.settingsVars.settings
        if not settings.mailContextMenus then return false end

        AddCustomScrollableMenuEntry("Settings", function() end, LSM_ENTRY_TYPE_HEADER, nil, { doNotFilter = true })

        local overrideSubmenu = {
            {
                label    = "Overwrite \'to\' field, if not empty",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.overwriteMailFields["recipients"] = state
                end,
                checked  = function() return settings.overwriteMailFields["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Overwrite \'subject\' field, if not empty",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.overwriteMailFields["subjects"] = state
                end,
                checked  = function() return settings.overwriteMailFields["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Overwrite \'text\' field, if not empty",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.overwriteMailFields["texts"] = state
                end,
                checked  = function() return settings.overwriteMailFields["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
        }
        AddCustomScrollableSubMenuEntry("Override fields", overrideSubmenu)

        local saveSubmenu = {
            {
                label    = "Save last \'to\' field, as mail sends/fails/closes",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.saveMailFields["recipients"] = state
                    checkAndEnabledEventHandlersIfNeeded(true)
                end,
                checked  = function() return settings.saveMailFields["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Save last \'subject\' field, as mail sends/fails/closes",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.saveMailFields["subjects"] = state
                    checkAndEnabledEventHandlersIfNeeded(true)
                end,
                checked  = function() return settings.saveMailFields["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Save last \'text\' field, as mail sends/fails/closes",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.saveMailFields["texts"] = state
                    checkAndEnabledEventHandlersIfNeeded(true)
                end,
                checked  = function() return settings.saveMailFields["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
        }
        AddCustomScrollableSubMenuEntry("Save settings", saveSubmenu)

        local autoLoadSubmenu = {
            {
                label    = "Enabled: Auto load last \'to\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFields["recipients"] = state
                end,
                checked  = function() return settings.autoLoadMailFields["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Enabled: Auto load last \'subject\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFields["subjects"] = state
                end,
                checked  = function() return settings.autoLoadMailFields["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Enabled: Auto load last \'text\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFields["texts"] = state
                end,
                checked  = function() return settings.autoLoadMailFields["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
        }
        AddCustomScrollableSubMenuEntry("Auto load settings", autoLoadSubmenu)

        local autoLoadAtSubmenu = {
            {
                label    = "Auto load last \'to\', as mail opens",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailOpen["recipients"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailOpen["recipients"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Auto load last \'to\', after mail was send (next mail)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailWasSend["recipients"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailWasSend["recipients"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Auto load last \'subject\', as mail opens",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailOpen["subjects"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailOpen["subjects"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Auto load last \'subject\', after mail was send (next mail)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailWasSend["subjects"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailWasSend["subjects"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Auto load last \'text\', as mail opens",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailOpen["texts"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailOpen["texts"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Auto load last \'text\', after mail was send (next mail)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.autoLoadMailFieldsAt.mailWasSend["texts"] = state
                end,
                checked  = function() return settings.autoLoadMailFieldsAt.mailWasSend["texts"] end,
                disabled = function() return not FCOChangeStuff.settingsVars.settings.autoLoadMailFields["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
        }
        AddCustomScrollableSubMenuEntry("Auto load as...", autoLoadAtSubmenu)

        local otherSettingsSubmenu = {
            {
                entryType = LSM_ENTRY_TYPE_HEADER,
                label = "Menus",
            },
            {
                label    = "Open submenus to the left",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.mailContextMenuSubmenusForceOpenToTheLeft = state
                end,
                checked  = function() return settings.mailContextMenuSubmenusForceOpenToTheLeft end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                entryType = LSM_ENTRY_TYPE_HEADER,
                label = "Favorites",
            },
            {
                label    = "Enabled: Favorites \'to\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.mailFavorites["recipients"] = state
                end,
                checked  = function() return settings.mailFavorites["recipients"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Enabled: Favorites \'subject\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.mailFavorites["subjects"] = state
                end,
                checked  = function() return settings.mailFavorites["subjects"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Enabled: Favorites \'text\' field",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.mailFavorites["texts"] = state
                end,
                checked  = function() return settings.mailFavorites["texts"] end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                entryType    = LSM_ENTRY_TYPE_DIVIDER,
            },
            {
                label    = "Split favorites by alphabet (create submenus)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.splitMailFavoritesIntoAlphabet = state
                end,
                checked  = function() return settings.splitMailFavoritesIntoAlphabet end,
                disabled = function() return not isAnyFavoriteSettingEnabled() end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                label    = "Show favorites context menu at editbox (recipient/subject/text)",
                callback = function(comboBox, itemName, item, state)
--d("[FCOCS]CheckBox settings at mail \'mailFavoritesContextMenusAtEditFields\': " ..tos(state))
                    FCOChangeStuff.settingsVars.settings.mailFavoritesContextMenusAtEditFields = state
                    checkIfEditBoxContextMenusNeedAnUpdate()
                end,
                checked  = function() return settings.mailFavoritesContextMenusAtEditFields end,
                disabled = function() return not isAnyFavoriteSettingEnabled() end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                entryType = LSM_ENTRY_TYPE_HEADER,
                label = "Last used",
            },
            {
                label    = "Show last used context menu at editbox (recipient/subject/text)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.mailLastUsedContextMenusAtEditFields = state
                    checkIfEditBoxContextMenusNeedAnUpdate()
                end,
                checked  = function() return settings.mailLastUsedContextMenusAtEditFields end,
                disabled = function() return not isAnyFavoriteSettingEnabled() end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },
            {
                entryType = LSM_ENTRY_TYPE_HEADER,
                label = "Profiles",
            },
            {
                label    = "Use mail profiles context menus at editbox (recipient)",
                callback = function(comboBox, itemName, item, state)
                    FCOChangeStuff.settingsVars.settings.enableMailProfiles = state
                    checkIfEditBoxContextMenusNeedAnUpdate()
                end,
                checked  = function() return settings.enableMailProfiles end,
                disabled = function() return false end,
                entryType = LSM_ENTRY_TYPE_CHECKBOX,
            },

        }
        AddCustomScrollableSubMenuEntry("Other settings", otherSettingsSubmenu)


        --Import MailBuddy SavedVariables?
        if MailBuddy ~= nil and MailBuddy_SavedVars ~= nil then
            local mailBuddySubmenu = {
                {
                    label    = "Import 'MailBuddy' recipients as favorites",
                    callback = function(comboBox, itemName, item, state)
                        loadMailBuddyData("recipients", true)
                    end,
                },
                {
                    label    = "Import 'MailBuddy' subjects as favorites",
                    callback = function(comboBox, itemName, item, state)
                        loadMailBuddyData("subjects", true)
                    end,
                },
                --[[
                --Not supported
                {
                    label    = "Import 'MailBuddy' texts as favorites",
                    callback = function(comboBox, itemName, item, state)
                        loadMailBuddyData("texts", true)
                    end,
                },
                ]]
            }
            AddCustomScrollableMenuDivider()
            AddCustomScrollableSubMenuEntry("\'MailBuddy\' data import", mailBuddySubmenu)
        end


        ShowCustomScrollableMenu(FCOChangeStuff.mailContextMenuButtons["settings"], LSM_contextMenuSettingsDefaultOptions)
    end
    return contextMenuCallbackFunc()
end

local function addMailContextmenuButtons()
    addButton = addButton or FCOChangeStuff.AddButton
    local MailInbox = ZO_MailInbox
    local MailSend = ZO_MailSend
    local MailSendTo = MailSend:GetNamedChild("ToLabel")
    local MailSendSubject = MailSend:GetNamedChild("SubjectLabel")
    local MailSendBody = MailSend:GetNamedChild("Body")

    --Add 1 button with mail mass-change (Mail received panel)
    local buttonDataMailReceivedMasssChange =
    {
        buttonName      = "FCOCS_MailRecivedMassChangeContextMenu",
        parentControl   = MailInbox,
        tooltip         = addonVars.addonNameMenuDisplay .." Mail received mass-change",
        callback        = function()
            return getMailReceivedMassChangeContextMenu()
        end,
        width           = 32,
        height          = 32,
        normal          = "/esoui/art/chatwindow/chat_options_up.dds",
        pressed         = "/esoui/art/chatwindow/chat_options_down.dds",
        highlight       = "/esoui/art/chatwindow/chat_options_over.dds",
        disabled        = "/esoui/art/chatwindow/chat_options_disabled.dds",
    }
    local button = addButton(TOPLEFT, MailInbox, TOPLEFT, -35, -10, buttonDataMailReceivedMasssChange)
    button.type = "Inbox_MassChange"
    FCOChangeStuff.mailContextMenuButtons["Inbox_MassChange"] = button


    --Add 1 button with mail settings (Mail Send panel)
    local buttonDataMailSendSettings =
    {
        buttonName      = "FCOCS_MailSendSettingsContextMenu",
        parentControl   = MailSend,
        tooltip         = addonVars.addonNameMenuDisplay .." Mail settings",
        callback        = function()
            return getMailSettingsContextMenu()
        end,
        width           = 32,
        height          = 32,
        normal          = "/esoui/art/chatwindow/chat_options_up.dds",
        pressed         = "/esoui/art/chatwindow/chat_options_down.dds",
        highlight       = "/esoui/art/chatwindow/chat_options_over.dds",
        disabled        = "/esoui/art/chatwindow/chat_options_disabled.dds",
    }
    local button                     = addButton(TOPLEFT, MailSend, TOPLEFT, -35, -10, buttonDataMailSendSettings)
    button.type = "settings"
    FCOChangeStuff.mailContextMenuButtons["settings"] = button


    --Add 3 buttons at the mail subject, recipient and text (topleft of them) headlines for the context menus
    local buttonDataMailRecipients =
    {
        buttonName      = "FCOCS_MailRecipientsContextMenu",
        parentControl   = MailSendTo,
        tooltip         = "Mail recipients",
        callback        = function()
            updateMailContextMenuButtonContextMenus("recipients")
        end,
        width           = 20,
        height          = 20,
        normal          = "/esoui/art/buttons/dropbox_arrow_normal.dds",
        pressed         = "/esoui/art/buttons/dropbox_arrow_mousedown.dds",
        highlight       = "/esoui/art/buttons/dropbox_arrow_mouseover.dds",
        disabled        = "/esoui/art/buttons/dropbox_arrow_disabled.dds",
    }
    button = addButton(RIGHT, MailSendTo, LEFT, -10, 0, buttonDataMailRecipients)
    button._type = "recipients"
    FCOChangeStuff.mailContextMenuButtons["recipients"] = button
    allowedMailContextMenuOwners[button] = true

    local buttonDataMailSubjects =
    {
        buttonName      = "FCOCS_MailSubjectsContextMenu",
        parentControl   = MailSendSubject,
        tooltip         = "Mail subjects",
        callback        = function()
            updateMailContextMenuButtonContextMenus("subjects")
        end,
        width           = 20,
        height          = 20,
        normal          = "/esoui/art/buttons/dropbox_arrow_normal.dds",
        pressed         = "/esoui/art/buttons/dropbox_arrow_mousedown.dds",
        highlight       = "/esoui/art/buttons/dropbox_arrow_mouseover.dds",
        disabled        = "/esoui/art/buttons/dropbox_arrow_disabled.dds",
    }
    button = addButton(RIGHT, MailSendSubject, LEFT, -10, 0, buttonDataMailSubjects)
    button._type = "subjects"
    FCOChangeStuff.mailContextMenuButtons["subjects"] = button
    allowedMailContextMenuOwners[button] = true

    local buttonDataMailTexts =
    {
        buttonName      = "FCOCS_MailTextsContextMenu",
        parentControl   = MailSendBody,
        tooltip         = "Mail texts",
        callback        = function()
            updateMailContextMenuButtonContextMenus("texts")
        end,
        width           = 20,
        height          = 20,
        normal          = "/esoui/art/buttons/dropbox_arrow_normal.dds",
        pressed         = "/esoui/art/buttons/dropbox_arrow_mousedown.dds",
        highlight       = "/esoui/art/buttons/dropbox_arrow_mouseover.dds",
        disabled        = "/esoui/art/buttons/dropbox_arrow_disabled.dds",
    }
    button = addButton(TOPRIGHT, MailSendBody, TOPLEFT, -10, 0, buttonDataMailTexts)
    button._type = "texts"
    FCOChangeStuff.mailContextMenuButtons["texts"] = button
    allowedMailContextMenuOwners[button] = true

    mailContextMenutButtonsAdded = true

    --add LibScrollableMenu context menu to the mail subject, recipient and text buttons
    updateMailContextMenuButtonContextMenus()
end


--[[
local function OnZOMenuHide_RemoveFCOCSSubmenuOnMouseUpHandler()
--d("[FCOCS]OnZOMenuHide_RemoveFCOCSSubmenuOnMouseUpHandler")
    SetMenuHiddenCallback(nil)

    local owner = ZO_Menu.owner
    local items = ZO_Menu.items
    if owner == nil or not allowedMailContextMenuOwners[owner] or items == nil or #items <= 0 then return end
    for idx, menuLine in ipairs(items) do
        local item = menuLine.item
        item.isAlphabeticallySplitHeadline = nil
        if item:IsHandlerSet("OnMouseUp", "FCOCS_ContextMenu_SubmenuLines_OnMouseUpHandler") == true then
--d(">removing OnMouseUp handler from submenuEntry at line: " ..tos(idx))
            item:SetHandler("OnMouseUp", nil, "FCOCS_ContextMenu_SubmenuLines_OnMouseUpHandler")
        end
    end
end
]]


--======== Mail send panel ============================================================
function FCOChangeStuff.MailContextMenuSetup()
    local settings = FCOChangeStuff.settingsVars.settings

    --Context menu
    local useMailContextMenus = settings.mailContextMenus
    if useMailContextMenus == true then
        if not mailContextMenutButtonsAdded then
            addMailContextmenuButtons()
        end
        updateHiddenStateOfContextMenuButtons(false)
        checkAndEnabledEventHandlersIfNeeded(true)
    else
        --Hide the buttons
        if mailContextMenutButtonsAdded == true then
            updateHiddenStateOfContextMenuButtons(true)
        end
        checkAndEnabledEventHandlersIfNeeded(false)
    end

    --Mail was successfully send - Before fields get cleared: Saved last used
    --and add data to "last 10"
    if not isOnMailSendSuccessHooked then
        ZO_PreHook(MAIL_SEND, "OnMailSendSuccess", function()
            if not FCOChangeStuff.settingsVars.settings.mailContextMenus then return false end
            --d("[FCOCS]PreHook: MAIL_SEND:OnMailSendSuccess")
            checkAndSaveMailValuesOfEnabledFields(true)
            return false --clear the fields via ZOs vanilla code
        end)
        isOnMailSendSuccessHooked = true
    end

    --Mail was successfully send - After fields got cleared: Load last used
    if not isOnMailSendSuccessPostHooked then
        SecurePostHook(MAIL_SEND, "OnMailSendSuccess", function()
            --d("[FCOCS]PostHook: MAIL_SEND:OnMailSendSuccess")
            if not FCOChangeStuff.settingsVars.settings.mailContextMenus then return false end
            afterMailWasSend(false, true)
        end)
        isOnMailSendSuccessPostHooked = true
    end


    --Enable the left click on ZO_MenuItemN if there is a submenu of the "Favorites"
    --but do not enable left click if the submenu's entry is the alphabetcially split header e.g. A-E, F-J, ...
    -->Select the current favorite
    --[[
    if not isShowMenuHooked then
        SecurePostHook("ShowMenu", function(owner, initialRefCount, menuType)
            if not mailContextMenutButtonsAdded or not FCOChangeStuff.settingsVars.settings.mailContextMenus then return false end
            --Only needed for debugging
            --FCOCS._menuOwner = owner
            --FCOCS._menuItems = ZO_ShallowTableCopy(ZO_Menu.items)
            local items = ZO_Menu.items

            local wasOnMouseUpHandlerSet = false

            if owner == nil or not allowedMailContextMenuOwners[owner] or items == nil or #items <= 0 then return end
            local ownerType = owner._type
            local ownerRelatingMailEditBox = getEditBoxByFieldType(ownerType)
            if not ownerRelatingMailEditBox or not ownerRelatingMailEditBox.SetText then return end

            local locSettings = FCOChangeStuff.settingsVars.settings
            local splitMailFavoritesIntoAlphabet = locSettings.splitMailFavoritesIntoAlphabet
            if splitMailFavoritesIntoAlphabet == true then return end

            --d(">Allowed mail context menu opened")
            for idx, menuLine in ipairs(items) do
                local item = menuLine.item
                if not item.isAlphabeticallySplitHeadline then
                    if item.enabled == true and item.nameLabel ~= nil then
                        --d(">line " .. tos(idx) .. " is enabled!")
                        local checkBox = item.checkbox
                        --checkbox = "maybe" submenu "arrow" showing to the right
                        if checkBox ~= nil and checkBox:IsHidden() == false then
                            local menuItemName = item:GetName() -- ZO_CustomSubMenuItem1
                            if menuItemName ~= "" and string.find(menuItemName, "ZO_CustomSubMenuItem", 1, true) ~= nil then
                                --d(">found submenuEntry at line: " ..tos(idx))
                                item:SetHandler("OnMouseUp", function(itemCtrl, button, upInside, shift, ctrl, alt, cmd)
                                    if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                                        local currentLabelText = item.nameLabel:GetText()
                                        local cleanLabelText = cleanSubMenuLabelText(currentLabelText)
                                        --d(">>clicked label: " ..tos(currentLabelText) .. ", clean: " ..tos(cleanLabelText))
                                        ZO_Menu_SetLastCommandWasFromMenu(true)
                                        setMailValue(ownerType, cleanLabelText, nil)
                                        ClearMenu()
                                    end
                                end, "FCOCS_ContextMenu_SubmenuLines_OnMouseUpHandler")
                                wasOnMouseUpHandlerSet = true
                            end
                        end
                    end
                else
                    --d("<alphabetically split favorites enabled")
                end
            end

            if wasOnMouseUpHandlerSet == true then
                --Should be executed via ZO_Menu_OnHide(control)
                SetMenuHiddenCallback(OnZOMenuHide_RemoveFCOCSSubmenuOnMouseUpHandler)
            end
        end)
        isShowMenuHooked = true
    end
    ]]

    --Context menus at the edit fields of recipient/subject/text
    checkIfEditBoxContextMenusNeedAnUpdate()

    --Prepare the lower case string searches
    updateLowercaseTextTables()
end
local FCOCS_MailContextMenuSetup = FCOChangeStuff.MailContextMenuSetup



--======== Mail receive panel ============================================================
------------------------------------------------------------------------------------------------------------------------
local returnMailDialogsHooked = false

function FCOChangeStuff.AnyOtherMailReturnBotActive()
    --Check for Postmaster and possible other return bots being active!
    if Postmaster then
        if Postmaster.settings.bounce == true then return true end
    end
    return false
end
local anyOtherMailReturnBotActive = FCOChangeStuff.AnyOtherMailReturnBotActive

local function showKeyboardDialogHooked(name, data, textParams, isGamepad)
    if anyOtherMailReturnBotActive() then return end
    if name == "MAIL_RETURN_ATTACHMENTS" and FCOChangeStuff.settingsVars.settings.mailAutoReturnToSenderBot then
        ReturnMail(MAIL_INBOX.mailId)
        return true
    end
end

local function showGamepadDialogHook(name, data, textParams)
    if anyOtherMailReturnBotActive() then return end
    if name == "MAIL_RETURN_ATTACHMENTS" and FCOChangeStuff.settingsVars.settings.returnDialogSuppress then
        MAIL_MANAGER_GAMEPAD.inbox:ReturnToSender()
        return true
    end
end


local function isMailInboxShown()
    if IsInGamepadPreferredMode() then
        return SM:IsShowing("mailManagerGamepad") and MAIL_MANAGER_GAMEPAD.activeFragment == GAMEPAD_MAIL_INBOX_FRAGMENT
    else
        return SM:IsShowing("mailInbox")
    end
end



local mailInboxUpdateLocked = false
local lastSentMailId
local autoReturnBotIsActive = false
local queuedRTSMailIds = {}
FCOChangeStuff.queuedRTSMailIds = queuedRTSMailIds
local returnNextMailToSender

local function disableAutoReturnBot(doSilent)
    doSilent = doSilent or false

    doSilent = true --disabled chat output for now
    if not doSilent then
        d("[FCOCS]<<< Auto return bot disabled again <<<")
    end
    autoReturnBotIsActive = false
    EM:UnregisterForEvent(addonName .. "_EVENT_MAIL_REMOVED", EVENT_MAIL_REMOVED)
    return false
end


local function onEventMailRemoved(eventId, mailId)
--d("[FCOCS]onEventMailRemoved")
    if not autoReturnBotIsActive then
        return disableAutoReturnBot()
    end
    local mailIdStr = zo_getSafeId64Key(mailId)
--d(">mailId: " .. tos(mailIdStr))
    local mailIdDataInQueue = queuedRTSMailIds[mailIdStr] --lastSendMailId
    if mailIdDataInQueue == nil then return disableAutoReturnBot() end

--d("<removed mail from autoReturnQueue: " .. tos(mailIdStr))

    --Remove the last returned mail from the queue now
    queuedRTSMailIds[mailIdStr] = nil

    --Go on with the next mail in the auto-return queue
    returnNextMailToSender(false)
end

--Parts of the code her was spyed and taken from the addon PostMaster.
--All credits to the authors Garkin, silvereyes, PacificOshie
function returnNextMailToSender(firstMail)
    autoReturnBotIsActive = true
    if anyOtherMailReturnBotActive() then return disableAutoReturnBot(true) end
    if ZO_IsTableEmpty(queuedRTSMailIds) or not isMailInboxShown() then
--d("<ABORT: No entries queued for auto return or mail inbox not opened")
        return disableAutoReturnBot()
    end
    firstMail = firstMail or false

    --[[
    if firstMail then
d("[FCOCS]>>> Auto return bot enabled >>>")
    end
    ]]

    local mailId64Str, mailData = next(queuedRTSMailIds)
    if mailData ~= nil and mailData.mailId ~= nil then
        local mailId = mailData.mailId
        if mailId64Str ~= nil and mailId64Str ~= "" then
            local senderDisplayName = mailData.senderDisplayName
            if lastSentMailId == mailId then
                --We tried to send that already, so abort here now
--d("[FCOCS]ABORT - Error at Auto return bot: Mail was tried to return to sender already, ID: " ..tos(mailId64Str) .. ", receiver: " ..tos(senderDisplayName))
                return disableAutoReturnBot()
            end
--d(">returnMailToSender - sender: " ..tos(senderDisplayName) .. ", mailId/lastSendId: " ..tos(mailId64Str) .. " / " ..tos(zo_getSafeId64Key(lastSentMailId)))
            if senderDisplayName == nil or senderDisplayName == "" then
--d("<ABORT: Sender displayName is nil or empty")
                return disableAutoReturnBot()
            end

            EM:RegisterForEvent(addonName .. "_EVENT_MAIL_REMOVED", EVENT_MAIL_REMOVED, onEventMailRemoved)

            -- Get the latest data, in case it has changed
            ZO_MailInboxShared_PopulateMailData(mailData, mailId)
            -- Read the mail before returning it, so the "unread mail" count will decrement.
            RequestReadMail(mailId)

            --Delay the returning of the mail a bit so that the data etc. updates properly
            zo_callLater(function()
                lastSentMailId = mailId
d("[FCOCS]Returning mail to sender: " ..tos(senderDisplayName) .. " (MailId: " ..tos(mailId64Str) ..")")
                ReturnMail(mailId) --> Will call onEventMailRemoved if it worked!
            end, 250)

            return true
        else
--d("<ABORT: mailData or mailId is nil!!")
            return disableAutoReturnBot()
        end
    else
--d("<ABORT: no more entries or mailData missing!!")
        --No more entries or data missing -> Disable the auto return bot now
        return disableAutoReturnBot()
    end
end

function FCOChangeStuff.MailReturnBotSetup()
    local settings = FCOChangeStuff.settingsVars.settings
    local mailAutoReturnToSenderBot = settings.mailAutoReturnToSenderBot
    if mailAutoReturnToSenderBot == true then
        if not returnMailDialogsHooked then
            --Hook the keyboard and gamepad return mail dialogs
            ZO_PreHook("ZO_Dialogs_ShowDialog",         showKeyboardDialogHooked)
            ZO_PreHook("ZO_Dialogs_ShowGamepadDialog",  showGamepadDialogHook)
            returnMailDialogsHooked = true
        end


        --Auto return mails if the come in with these subjects
        local returnToSenderSubjects = { ["re"] = true, ["rts"] = true, ["return"] = true, ["bounce"] = true, ["rsvp"] = true }
        mailInboxUpdateLocked = false

        --Mail inbox got opened
        local function onEventMailInboxUpdate(eventId)
            if mailInboxUpdateLocked or autoReturnBotIsActive then return end
            if anyOtherMailReturnBotActive() then return disableAutoReturnBot(true) end

            mailInboxUpdateLocked = true

            local data, mailDataIndex
            if IsInGamepadPreferredMode() then
                if not MAIL_MANAGER_GAMEPAD.inbox.mailList then
                    mailInboxUpdateLocked = false
                    return
                end
                data = MAIL_MANAGER_GAMEPAD.inbox.mailList.dataList
                mailDataIndex = "dataSource"
            else
                data = MAIL_INBOX.masterList
            end
            if data == nil then
                mailInboxUpdateLocked = false
                return
            end

            for _, receivedMailData in pairs(data) do
                local mailData = mailDataIndex and receivedMailData[mailDataIndex] or receivedMailData
                if mailData and mailData.mailId and not mailData.fromCS
                        and not mailData.fromSystem and mailData.codAmount == 0
                        and (mailData.numAttachments > 0 or mailData.attachedMoney > 0)
                        and not mailData.returned
                        and (mailData.subject ~= "" and returnToSenderSubjects[zo_strlower(mailData.subject)])
                then
                    local mailId64Str = zo_getSafeId64Key(mailData.mailId)
                    --d(">found mail in inbox: " ..tos(mailId64Str) .. ", subject: " ..tos(mailData.subject) .. ", sender: " ..tos(mailData.senderDisplayName))
                    queuedRTSMailIds[mailId64Str] = mailData
                end
            end

            mailInboxUpdateLocked = false

            --Start the Auto Return Bot now
            local wasStarted = returnNextMailToSender(true)
        end
        EM:RegisterForEvent(addonName .. "_EVENT_MAIL_INBOX_UPDATE", EVENT_MAIL_INBOX_UPDATE, onEventMailInboxUpdate)
    else
        autoReturnBotIsActive = false
        queuedRTSMailIds = {}
        mailInboxUpdateLocked = true
        EM:UnregisterForEvent(addonName .. "_EVENT_MAIL_INBOX_UPDATE", EVENT_MAIL_INBOX_UPDATE)
        EM:UnregisterForEvent(addonName .. "_EVENT_MAIL_REMOVED", EVENT_MAIL_REMOVED)
    end
end
local FCOCS_MailReturnBotSetup = FCOChangeStuff.MailReturnBotSetup







------------------------------------------------------------------------------------------------------------------------
function FCOChangeStuff.mailStuff(whatType)

    local typesToPrepare = {
        ["ContextMenu"] = false,
        ["RTSBot"] = false,
    }
    if whatType == nil then
        for k, v in pairs(typesToPrepare) do
            typesToPrepare[k] = true
        end
    else
        typesToPrepare[whatType] = true
    end


    --Context menu
    if typesToPrepare["ContextMenu"] == true then
        FCOCS_MailContextMenuSetup()
    end

    --Return To Sender automatic bot
    if typesToPrepare["RTSBot"] == true then
        FCOCS_MailReturnBotSetup()
    end
end

local zoDialog1 = ZO_Dialog1
local function onDialogShownHook()
    zo_callLater(function()
        --d("[ZO_Dialog1]On dialog shown hook")
        if not ZO_Dialogs_IsShowingDialog() then return end
        if zoDialog1.name ~= "FCOCS_ADD_MAIL_PROFILE_DIALOG" then return end
        local data = zoDialog1.data
        if not data then return end
        if data.profileIndex and data.editBoxText then
            local editControl = ZO_Dialog1EditBox
            if editControl then
                editControl:SetText(data.editBoxText)
            end
        end
    end, 50)
end
if zoDialog1:GetHandler("OnEffectivelyShown") ~= nil then
    ZO_PostHookHandler(zoDialog1, "OnEffectivelyShown", onDialogShownHook)
else
    zoDialog1:SetHandler("OnEffectivelyShown", onDialogShownHook)
end
