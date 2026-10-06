local NC = NecroCat or {}
NecroCat = NC
NC.SettingsUI = NC.SettingsUI or {}
local SettingsUI = NC.SettingsUI

local wm = WINDOW_MANAGER

-- Реестр наших 14 вкладок (полностью через локализацию)
local TABS = {
    { id = 1,  strId = SI_NC_TAB_1 },
    { id = 2,  strId = SI_NC_TAB_2 },
    { id = 3,  strId = SI_NC_TAB_3 },
    { id = 4,  strId = SI_NC_TAB_4 },
    { id = 5,  strId = SI_NC_TAB_5 },
    { id = 6,  strId = SI_NC_TAB_6 },
    { id = 7,  strId = SI_NC_TAB_7 },
    { id = 8,  strId = SI_NC_TAB_8 },
    { id = 9,  strId = SI_NC_TAB_9 },
    { id = 10, strId = SI_NC_TAB_10 },
    { id = 11, strId = SI_NC_TAB_11 },
    { id = 12, strId = SI_NC_TAB_12 },
    { id = 13, strId = SI_NC_TAB_13 },
    { id = 14, strId = SI_NC_TAB_14 },
    { id = 15, strId = SI_NC_TAB_15 },
}

local function GetTabName(tabData)
    if not tabData or not tabData.strId then return "" end
    return GetString(tabData.strId)
end

SettingsUI.currentTabId = 1
SettingsUI.tabButtons = {}

local createdControls = {}
local cbIndex = 0
local headerIndex = 0
local sliderIndex = 0
local btnIndex = 0
local dropdownIndex = 0
local colorIndex = 0

local function ClearContent()
    for _, ctrl in ipairs(createdControls) do
        if ctrl then ctrl:SetHidden(true) end
    end
    createdControls = {}
    cbIndex = 0
    headerIndex = 0
    sliderIndex = 0
    btnIndex = 0
    dropdownIndex = 0
    colorIndex = 0
end

-- 1. Рендер заголовка подраздела
local function CreateHeader(parent, text, offsetY)
    headerIndex = headerIndex + 1
    local name = "NecroCat_Hdr_" .. headerIndex
    local header = _G[name] or wm:CreateControl(name, parent, CT_LABEL)
    header:ClearAnchors()
    header:SetFont("ZoFontWinH3")
    header:SetColor(1.0, 0.85, 0.3, 1.0)
    header:SetText(text)
    header:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    header:SetHidden(false)
    table.insert(createdControls, header)
    return offsetY + 32
end

-- 2. Рендер чекбокса (Галочки)
local function CreateCheckbox(parent, text, getFunc, setFunc, offsetY)
    cbIndex = cbIndex + 1
    local btnName = "NecroCat_CB_" .. cbIndex
    local btn = _G[btnName] or CreateControlFromVirtual(btnName, parent, "ZO_CheckButton")
    btn:ClearAnchors()
    btn:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    btn:SetDimensions(26, 26)
    btn:SetHidden(false)

    ZO_CheckButton_SetLabelText(btn, text)
    ZO_CheckButton_SetCheckState(btn, getFunc and getFunc() or false)

    ZO_CheckButton_SetToggleFunction(btn, function(control, isChecked)
        if setFunc then setFunc(isChecked) end
    end)

    table.insert(createdControls, btn)
    return offsetY + 34
end

-- 3. Рендер слайдера (Ползунка с защитой от фантомных срабатываний и точным округлением)
local function CreateSlider(parent, text, minVal, maxVal, stepVal, getFunc, setFunc, offsetY, decimals)
    sliderIndex = sliderIndex + 1
    local tabId = SettingsUI.currentTabId or 0
    local name = string.format("NecroCat_Slider_T%d_%d", tabId, sliderIndex)

    local isDecimal = (decimals and decimals > 0) or (stepVal and stepVal < 1)
    local numDecimals = decimals or (isDecimal and 1 or 0)
    local mult = 10 ^ numDecimals
    local fmt = isDecimal and string.format("%%.%df", numDecimals) or "%d"

    local function RoundVal(v)
        if isDecimal then
            return math.floor(v * mult + 0.5) / mult
        end
        return math.floor(v + 0.5)
    end

    local function FormatVal(v)
        if isDecimal then return string.format(fmt, v) end
        return tostring(math.floor(v + 0.5))
    end

    local row = _G[name] or wm:CreateControl(name, parent, CT_CONTROL)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    row:SetDimensions(560, 48)
    row:SetHidden(false)
    table.insert(createdControls, row)

    local title = _G[name .. "_Title"] or wm:CreateControl(name .. "_Title", row, CT_LABEL)
    title:ClearAnchors()
    title:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    title:SetFont("ZoFontGame")
    title:SetColor(1, 1, 1, 1)
    title:SetText(text)
    title:SetHidden(false)

    local valLabel = _G[name .. "_Val"] or wm:CreateControl(name .. "_Val", row, CT_LABEL)
    valLabel:ClearAnchors()
    valLabel:SetAnchor(TOPRIGHT, row, TOPRIGHT, -10, 0)
    valLabel:SetFont("ZoFontGameBold")
    valLabel:SetColor(0.0, 0.85, 1.0, 1.0)
    valLabel:SetHidden(false)

    local slider = _G[name .. "_Slider"] or CreateControlFromVirtual(name .. "_Slider", row, "ZO_Slider")
    slider:ClearAnchors()
    slider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    slider:SetDimensions(540, 16)
    slider:SetHidden(false)

    -- ЖЕЛЕЗНЫЙ ЩИТ: наглухо глушим любые события перед сменой границ и значений!
    slider:SetHandler("OnValueChanged", nil)

    slider:SetMinMax(minVal or 0, maxVal or 100)
    slider:SetValueStep(stepVal or 1)

    local currentVal = getFunc and getFunc() or minVal or 0
    slider:SetValue(currentVal)
    valLabel:SetText(FormatVal(RoundVal(currentVal)))

    -- Включаем обработчик ТОЛЬКО когда значение уже выставлено
    slider:SetHandler("OnValueChanged", function(self, value)
        local rounded = RoundVal(value)
        valLabel:SetText(FormatVal(rounded))
        if setFunc then
            setFunc(rounded)
        end
    end)

    return offsetY + 54
end

-- 4. Рендер кнопки
local function CreateButton(parent, text, func, offsetY, width)
    btnIndex = btnIndex + 1
    local name = "NecroCat_Btn_" .. btnIndex
    local btn = _G[name] or CreateControlFromVirtual(name, parent, "ZO_DefaultButton")
    btn:ClearAnchors()
    btn:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    btn:SetDimensions(width or 320, 28)
    btn:SetText(text)
    btn:SetHidden(false)
    btn:SetHandler("OnClicked", function()
        if func then func() end
    end)
    table.insert(createdControls, btn)
    return offsetY + 38
end

-- 5. Рендер выпадающего списка (Dropdown / ComboBox)
local function CreateDropdown(parent, text, choices, choicesValues, getFunc, setFunc, offsetY)
    dropdownIndex = dropdownIndex + 1
    local name = "NecroCat_DD_" .. dropdownIndex

    local row = _G[name] or wm:CreateControl(name, parent, CT_CONTROL)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    row:SetDimensions(560, 32)
    row:SetHidden(false)
    table.insert(createdControls, row)

    local label = _G[name .. "_Label"] or wm:CreateControl(name .. "_Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    label:SetFont("ZoFontGame")
    label:SetColor(1, 1, 1, 1)
    label:SetText(text)
    label:SetHidden(false)

    local comboCtrl = _G[name .. "_Combo"] or CreateControlFromVirtual(name .. "_Combo", row, "ZO_ComboBox")
    comboCtrl:ClearAnchors()
    comboCtrl:SetAnchor(RIGHT, row, RIGHT, -10, 0)
    comboCtrl:SetDimensions(240, 28)
    comboCtrl:SetHidden(false)

    local comboBox = ZO_ComboBox_ObjectFromContainer(comboCtrl)
    comboBox:ClearItems()
    comboBox:SetSortsItems(false)
    comboBox:SetFont("ZoFontGame")

    local currentVal = getFunc and getFunc()
    local selectedName = ""

    local function OnSelected(_, choiceText, choice)
        if setFunc then setFunc(choice.val) end
    end

    if choices then
        for i, choiceName in ipairs(choices) do
            local choiceVal = (choicesValues and choicesValues[i] ~= nil) and choicesValues[i] or choiceName
            local item = comboBox:CreateItemEntry(choiceName, OnSelected)
            item.val = choiceVal
            comboBox:AddItem(item)

            if choiceVal == currentVal or (currentVal == nil and i == 1) then
                selectedName = choiceName
            end
        end
    end

    if selectedName ~= "" then
        comboBox:SetSelectedItemText(selectedName)
    elseif choices and #choices > 0 then
        comboBox:SetSelectedItemText(choices[1])
    end

    return offsetY + 38
end

-- 6. Рендер палитры выбора цвета (Colorpicker)
local function CreateColorpicker(parent, text, getFunc, setFunc, offsetY)
    colorIndex = colorIndex + 1
    local tabId = SettingsUI.currentTabId or 0
    local name = string.format("NecroCat_Color_T%d_%d", tabId, colorIndex)

    local row = _G[name] or wm:CreateControl(name, parent, CT_CONTROL)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 10, offsetY)
    row:SetDimensions(560, 32)
    row:SetHidden(false)
    table.insert(createdControls, row)

    local label = _G[name .. "_Label"] or wm:CreateControl(name .. "_Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    label:SetFont("ZoFontGame")
    label:SetColor(1, 1, 1, 1)
    label:SetText(text)
    label:SetHidden(false)

    local swatch = _G[name .. "_Swatch"] or wm:CreateControl(name .. "_Swatch", row, CT_BUTTON)
    swatch:ClearAnchors()
    swatch:SetAnchor(RIGHT, row, RIGHT, -10, 0)
    swatch:SetDimensions(54, 24)
    swatch:SetHidden(false)

    local bg = _G[name .. "_SwatchBG"] or wm:CreateControl(name .. "_SwatchBG", swatch, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetEdgeTexture("", 8, 1, 1)
    bg:SetEdgeColor(0.8, 0.8, 0.8, 0.8)

    local r, g, b, a = 1, 1, 1, 1
    if getFunc then r, g, b, a = getFunc() end
    bg:SetCenterColor(r, g, b, a or 1)

    swatch:SetHandler("OnClicked", function()
        local curR, curG, curB, curA = 1, 1, 1, 1
        if getFunc then curR, curG, curB, curA = getFunc() end

        COLOR_PICKER:Show(function(newR, newG, newB, newA)
            bg:SetCenterColor(newR, newG, newB, newA or 1)
            if setFunc then
                setFunc(newR, newG, newB, newA or 1)
            end
        end, curR, curG, curB, curA or 1, text)

        if COLOR_PICKER and COLOR_PICKER.control then
            COLOR_PICKER.control:SetDrawTier(DT_HIGH)
            COLOR_PICKER.control:BringWindowToTop()
        end
    end)

    return offsetY + 36
end

-- Вспомогательная функция для получения списка гильдий
local function GetGuildChoices()
    local choices = { "(Default)" }
    local values  = { 0 }
    for i = 1, GetNumGuilds() do
        local gid = GetGuildId(i)
        table.insert(choices, GetGuildName(gid))
        table.insert(values, gid)
    end
    return choices, values
end

-- Предварительное объявление функции отрисовки содержимого
local RenderTabContent

-- Функция переключения активной вкладки
local function SelectTab(tabId)
    SettingsUI.currentTabId = tabId

    for id, btn in pairs(SettingsUI.tabButtons) do
        local isSelected = (id == tabId)
        btn.bg:SetHidden(not isSelected)
        if isSelected then
            btn:SetNormalFontColor(0.0, 0.85, 1.0, 1.0)
        else
            btn:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
        end
    end

    if SettingsUI.RightHeader then
        local tabData = TABS[tabId]
        SettingsUI.RightHeader:SetText(GetTabName(tabData))
    end

    RenderTabContent(tabId)
end

-- Отрисовка содержимого конкретной вкладки
RenderTabContent = function(tabId)
    ClearContent()
    local scrollChild = SettingsUI.ScrollChild
    if not scrollChild then return end

    local currentY = 10

    if tabId == 1 then
        -- =====================================================
        -- РАЗДЕЛ 1: ГРУППА И FOLLOWME
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GROUP_ROLES), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SWAP_NAMES),
            function() return NC.savedVars and NC.savedVars.swapGroupNames end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.swapGroupNames = v 
                    if GROUP_LIST then GROUP_LIST:RefreshData() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_ROLES),
            function() return NC.savedVars and NC.savedVars.disableEnforceRole end,
            function(v) if NC.savedVars then NC.savedVars.disableEnforceRole = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GROUP_AUTO), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TREAT_FRIENDS),
            function() return NC.savedVars and NC.savedVars.treatFriendsAsFavorites end,
            function(v) if NC.savedVars then NC.savedVars.treatFriendsAsFavorites = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AUTO_ACCEPT_BTN),
            function() return NC.savedVars and NC.savedVars.showAutoAcceptButton end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showAutoAcceptButton = v 
                    if NC.AutoAcceptDungeonCheck then NC.AutoAcceptDungeonCheck:SetHidden(not v) end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_KICK_RANDOM_BTN),
            function() return NC.savedVars and NC.savedVars.showKickRandomsButton ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showKickRandomsButton = v 
                    if NC.KickRandomsBtn then NC.KickRandomsBtn:SetHidden(not v) end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AUTO_RAID),
            function() return NC.savedVars and NC.savedVars.autoConvertToRaid end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.autoConvertToRaid = v 
                    if v and NC.CheckAutoConvertToRaid then NC.CheckAutoConvertToRaid() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SUPPRESS_JUMP),
            function() return NC.savedVars and NC.savedVars.suppressJumpToLeader end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.suppressJumpToLeader = v 
                    if NC.UpdateJumpToLeaderSuppression then NC.UpdateJumpToLeaderSuppression() end
                end
            end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_FOLLOWME), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOLLOW_AUTO),
            function() return NC.savedVars and NC.savedVars.followAutoAccept end,
            function(v) if NC.savedVars then NC.savedVars.followAutoAccept = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOLLOW_OWN),
            function() return NC.savedVars and NC.savedVars.followShowOwn end,
            function(v) if NC.savedVars then NC.savedVars.followShowOwn = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOLLOW_BTN),
            function() return NC.savedVars and NC.savedVars.followShowButton end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.followShowButton = v 
                    if NecroCat.Follow and NecroCat.Follow.ChatButton then 
                        NecroCat.Follow.ChatButton:SetHidden(not v) 
                    end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_FOLLOW_BTNX), 0, 500, 1,
            function() return (NC.savedVars and NC.savedVars.followButtonX) or 177 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.followButtonX = v 
                    if NecroCat.Follow and NecroCat.Follow.UpdateButtonPosition then 
                        NecroCat.Follow.UpdateButtonPosition() 
                    end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_FOLLOW_RESET),
            function() 
                if NecroCat.Follow and NecroCat.Follow.ResetButtonPosition then 
                    NecroCat.Follow.ResetButtonPosition() 
                    RenderTabContent(1)
                end
            end,
            currentY
        )

    elseif tabId == 2 then
        -- =====================================================
        -- РАЗДЕЛ 2: ГИЛЬДИИ
        -- =====================================================
        local gChoices, gValues = GetGuildChoices()

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GUILD_ORDER), currentY)

        for slot = 1, 5 do
            local slotLabel = zo_strformat(GetString(SI_NC_GUILD_SLOT), slot)
            currentY = CreateDropdown(scrollChild, slotLabel, gChoices, gValues,
                function() return (NC.savedVars and NC.savedVars.customGuildOrder and NC.savedVars.customGuildOrder[slot]) or 0 end,
                function(v)
                    if NC.savedVars then
                        NC.savedVars.customGuildOrder = NC.savedVars.customGuildOrder or {}
                        NC.savedVars.customGuildOrder[slot] = v
                        if GUILD_SHARED_INFO and GUILD_SHARED_INFO.UpdateGuildSelector then GUILD_SHARED_INFO:UpdateGuildSelector() end
                        if NC.UpdateGuildBankButtons then NC.UpdateGuildBankButtons() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_GUILD_RESET),
            function()
                if NC.savedVars then
                    NC.savedVars.customGuildOrder = {}
                    if GUILD_SHARED_INFO and GUILD_SHARED_INFO.UpdateGuildSelector then GUILD_SHARED_INFO:UpdateGuildSelector() end
                    if NC.UpdateGuildBankButtons then NC.UpdateGuildBankButtons() end
                    RenderTabContent(2)
                end
            end,
            currentY + 4
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GUILD_BANK), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BANK_ENABLE),
            function() return NC.savedVars and NC.savedVars.guildBankEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.guildBankEnabled = v 
                    if NC.BankFrame then NC.BankFrame:SetHidden(not v) end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BANK_DEFAULT), gChoices, gValues,
            function() return (NC.savedVars and NC.savedVars.guildBankDefaultGuildId) or 0 end,
            function(v) if NC.savedVars then NC.savedVars.guildBankDefaultGuildId = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GUILDHALL), currentY + 6)

        local visChoices = { GetString(SI_NC_LAM_GUILD_MODE_1), GetString(SI_NC_LAM_GUILD_MODE_2), GetString(SI_NC_LAM_GUILD_MODE_3) }
        local visValues  = { 1, 2, 3 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GUILD_HOME_VIS), visChoices, visValues,
            function() return (NC.savedVars and NC.savedVars.guildHomeVisibility) or 1 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.guildHomeVisibility = v 
                    if NC.UpdateGuildHomeVisibility then NC.UpdateGuildHomeVisibility() end
                end
            end,
            currentY
        )

    elseif tabId == 3 then
        -- =====================================================
        -- РАЗДЕЛ 3: ВЗАИМОДЕЙСТВИЕ (F)
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_INTERACTION_HDR), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_REMOVE_GROUP),
            function() return NC.savedVars and NC.savedVars.hideRemoveFromGroup end,
            function(v) if NC.savedVars then NC.savedVars.hideRemoveFromGroup = v end end,
            currentY
        )
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_REPORT),
            function() return NC.savedVars and NC.savedVars.hideReport end,
            function(v) if NC.savedVars then NC.savedVars.hideReport = v end end,
            currentY
        )
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_TRIBUTE),
            function() return NC.savedVars and NC.savedVars.hideTributeInvite end,
            function(v) if NC.savedVars then NC.savedVars.hideTributeInvite = v end end,
            currentY
        )
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_ADD_FRIEND),
            function() return NC.savedVars and NC.savedVars.hideAddFriend end,
            function(v) if NC.savedVars then NC.savedVars.hideAddFriend = v end end,
            currentY
        )
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_DUEL),
            function() return NC.savedVars and NC.savedVars.hideDuel end,
            function(v) if NC.savedVars then NC.savedVars.hideDuel = v end end,
            currentY
        )
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_TRADE),
            function() return NC.savedVars and NC.savedVars.hideTrade end,
            function(v) if NC.savedVars then NC.savedVars.hideTrade = v end end,
            currentY
        )

    elseif tabId == 4 then
        -- =====================================================
        -- РАЗДЕЛ 4: ЧАТ И ИКОНКИ
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_ICONS), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUSTOM_ICONS),
            function() return NC.savedVars and NC.savedVars.customColorIcons end,
            function(v) if NC.savedVars then NC.savedVars.customColorIcons = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BG_ICON),
            function() return NC.savedVars and NC.savedVars.showBgZoneIcon end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showBgZoneIcon = v 
                    if FRIENDS_LIST then FRIENDS_LIST:RefreshData() end
                    if GUILD_ROSTER_KEYBOARD then GUILD_ROSTER_KEYBOARD:RefreshData() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SHOW_CASTLE),
            function() return NC.savedVars and NC.savedVars.showIcon end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showIcon = v 
                    if NC.CastleIcon then NC.CastleIcon:SetHidden(not v) end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CASTLE_X), 0, 800, 1,
            function() return (NC.savedVars and NC.savedVars.vrxCoord) or 136 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.vrxCoord = v 
                    if NC.CastleIcon and ZO_ChatWindow then 
                        NC.CastleIcon:ClearAnchors()
                        NC.CastleIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -v, 10)
                    end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SHOW_NOTE),
            function() return NC.savedVars and NC.savedVars.showNoteIcon end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showNoteIcon = v 
                    if NC.NoteIcon then NC.NoteIcon:SetHidden(not v) end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_NOTE_X), 0, 800, 1,
            function() return (NC.savedVars and NC.savedVars.noteXCoord) or 170 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.noteXCoord = v 
                    if NC.NoteIcon and ZO_ChatWindow then 
                        NC.NoteIcon:ClearAnchors()
                        NC.NoteIcon:SetAnchor(TOPRIGHT, ZO_ChatWindow, TOPRIGHT, -v, 10)
                    end
                end
            end,
            currentY
        )

    elseif tabId == 5 then
        -- =====================================================
        -- РАЗДЕЛ 5: УВЕДОМЛЕНИЯ И УДОБСТВА
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_MOVEMENT), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPRINT_TOGGLE),
            function() return NC.savedVars and NC.savedVars.mountSprintToggle end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.mountSprintToggle = v 
                    if NC.UpdateMountSprintToggle then NC.UpdateMountSprintToggle(IsMounted()) end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDOMETER_ENABLE),
            function() return NC.savedVars and NC.savedVars.speedometerEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedometerEnabled = v 
                    if NC.UpdateSpeedometerUI then NC.UpdateSpeedometerUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDOMETER_MOUNTED),
            function() return NC.savedVars and NC.savedVars.speedometerOnlyMounted end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedometerOnlyMounted = v 
                    if NC.UpdateSpeedometer then NC.UpdateSpeedometer() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDOMETER_UNLOCK),
            function() return NC.savedVars and NC.savedVars.speedometerUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedometerUnlocked = v 
                    if NC.UpdateSpeedometerUI then NC.UpdateSpeedometerUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_SPEEDOMETER_RESET),
            function()
                if NC.savedVars and NC.SpeedometerFrame then
                    NC.SpeedometerFrame:ClearAnchors()
                    NC.SpeedometerFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.speedometerLeft = NC.SpeedometerFrame:GetLeft()
                    NC.savedVars.speedometerTop  = NC.SpeedometerFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_WHISPERS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_WHISPER_ALERT_ENABLE),
            function() return NC.savedVars and NC.savedVars.whisperAlert end,
            function(v) if NC.savedVars then NC.savedVars.whisperAlert = v end end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_WHISPER_DURATION), 1, 60, 0.5,
            function() return (NC.savedVars and NC.savedVars.whisperDuration) or 3.5 end,
            function(v) if NC.savedVars then NC.savedVars.whisperDuration = v end end,
            currentY,
            1
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_WHISPER_LOCK),
            function() return NC.savedVars and NC.savedVars.whisperLocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.whisperLocked = v 
                    if NC.UpdateWhisperUI then NC.UpdateWhisperUI() end
                end
            end,
            currentY
        )
        
        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_WHISPER_RESET),
            function()
                if NC.savedVars and NC.WhisperFrame then
                    NC.WhisperFrame:ClearAnchors()
                    NC.WhisperFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.whisperLeft = NC.WhisperFrame:GetLeft()
                    NC.savedVars.whisperTop  = NC.WhisperFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_FRIENDS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FRIEND_UNLOCK),
            function() return NC.savedVars and not NC.savedVars.friendNotificationLocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.friendNotificationLocked = not v 
                    if NC.UpdateFriendUI then NC.UpdateFriendUI() end
                end
            end,
            currentY
        )
        
        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_FRIEND_RESET),
            function()
                if NC.savedVars and NC.FriendNotificationFrame then
                    NC.FriendNotificationFrame:ClearAnchors()
                    NC.FriendNotificationFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.friendNotificationLeft = NC.FriendNotificationFrame:GetLeft()
                    NC.savedVars.friendNotificationTop  = NC.FriendNotificationFrame:GetTop()
                end
            end,
            currentY + 2
        )
        
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_FAST_TRAVEL), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FAST_TRAVEL),
            function() return NC.savedVars and NC.savedVars.fastTravelConfirm end,
            function(v) if NC.savedVars then NC.savedVars.fastTravelConfirm = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_DISMISS_PETS),
            function() return NC.savedVars and NC.savedVars.dismissPetsInTrials end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.dismissPetsInTrials = v 
                    if v and NC.CheckTrialPets then NC.CheckTrialPets() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AUTO_PVP_QUEUE),
            function() return NC.savedVars and NC.savedVars.autoAcceptPvPQueue end,
            function(v) if NC.savedVars then NC.savedVars.autoAcceptPvPQueue = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_PVP_VET), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_VET_ENABLE),
            function() return NC.savedVars and NC.savedVars.veterancyEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.veterancyEnabled = v 
                    if NC.UpdateVeterancyUI then NC.UpdateVeterancyUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_VET_SUBTEXT),
            function() return NC.savedVars and NC.savedVars.veterancyShowSubText ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.veterancyShowSubText = v 
                    if NC.UpdateVeterancyUI then NC.UpdateVeterancyUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_VET_SIZE), 24, 128, 2,
            function() return (NC.savedVars and NC.savedVars.veterancySize) or 40 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.veterancySize = v 
                    if NC.UpdateVeterancyUI then NC.UpdateVeterancyUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_VET_UNLOCK),
            function() return NC.savedVars and NC.savedVars.veterancyUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.veterancyUnlocked = v 
                    if NC.UpdateVeterancyUI then NC.UpdateVeterancyUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_VET_RESET),
            function()
                if NC.savedVars and NC.VeterancyFrame then
                    NC.VeterancyFrame:ClearAnchors()
                    NC.VeterancyFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.veterancyLeft = NC.VeterancyFrame:GetLeft()
                    NC.savedVars.veterancyTop  = NC.VeterancyFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_RECIPES), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_RECIPE_BTN),
            function() return NC.savedVars and NC.savedVars.showRecipeButton end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showRecipeButton = v 
                    if NC.UpdateRecipeButtonVisibility then NC.UpdateRecipeButtonVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_RECIPE_MOTIFS),
            function() return NC.savedVars and NC.savedVars.includeMotifs end,
            function(v) if NC.savedVars then NC.savedVars.includeMotifs = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_RECIPE_STYLES),
            function() return NC.savedVars and NC.savedVars.includeStylePages end,
            function(v) if NC.savedVars then NC.savedVars.includeStylePages = v end end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_RECIPE_RESET),
            function()
                if NC.savedVars and NC.RecipeFrame then
                    NC.RecipeFrame:ClearAnchors()
                    NC.RecipeFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.recipeButtonLeft = NC.RecipeFrame:GetLeft()
                    NC.savedVars.recipeButtonTop  = NC.RecipeFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_UNBOX_ENABLE),
            function() return NC.savedVars and NC.savedVars.autoUnboxEnabled ~= false end,
            function(v) if NC.savedVars then NC.savedVars.autoUnboxEnabled = v end end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_UNBOX_DELAY), 1.0, 3.0, 0.1,
            function() return (NC.savedVars and NC.savedVars.unboxDelay) or 1.8 end,
            function(v) if NC.savedVars then NC.savedVars.unboxDelay = v end end,
            currentY,
            1
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_GEAR_STATUS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GEAR_STATUS),
            function() return NC.savedVars and NC.savedVars.showGearStatus end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showGearStatus = v 
                    if NC.UpdateAllCharacterGear then NC.UpdateAllCharacterGear() end
                end
            end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_CONFIRM), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CONFIRM_CRAFT),
            function() return NC.savedVars and NC.savedVars.autoConfirmCrafting end,
            function(v) if NC.savedVars then NC.savedVars.autoConfirmCrafting = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CONFIRM_DESTROY),
            function() return NC.savedVars and NC.savedVars.autoConfirmDestroy end,
            function(v) if NC.savedVars then NC.savedVars.autoConfirmDestroy = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_AGGRO), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AGGRO_ENABLE),
            function() return NC.savedVars and NC.savedVars.aggroMarkerEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.aggroMarkerEnabled = v 
                    if NC.UpdateAggroMarker then NC.UpdateAggroMarker() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_AGGRO_SIZE), 16, 96, 2,
            function() return (NC.savedVars and NC.savedVars.aggroMarkerSize) or 48 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.aggroMarkerSize = v 
                    if NC.UpdateAggroMarker then NC.UpdateAggroMarker() end
                end
            end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_STICKERBOOK), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AUTOBIND_ENABLE),
            function() return NC.savedVars and NC.savedVars.autoBindSetItems end,
            function(v) if NC.savedVars then NC.savedVars.autoBindSetItems = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_AUTOBIND_TOAST),
            function() return NC.savedVars and NC.savedVars.showAutoBindToast end,
            function(v) if NC.savedVars then NC.savedVars.showAutoBindToast = v end end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_TOAST_TEST),
            function() if NC.TestSetToast then NC.TestSetToast() end end,
            currentY + 2
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_TOAST_RESET),
            function()
                if NC.savedVars and NC.SetToastFrame then
                    NC.SetToastFrame:ClearAnchors()
                    NC.SetToastFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.setToastLeft = NC.SetToastFrame:GetLeft()
                    NC.savedVars.setToastTop  = NC.SetToastFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_CHESTS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CHEST_ENABLE),
            function() return NC.savedVars and NC.savedVars.showChestCounter end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.showChestCounter = v 
                    if NC.UpdateChestCounterVisibility then NC.UpdateChestCounterVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CHEST_SIZE), 20, 72, 2,
            function() return (NC.savedVars and NC.savedVars.chestSize) or 36 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.chestSize = v 
                    if NC.UpdateChestCounterSize then NC.UpdateChestCounterSize() end
                    if NC.ChestCounterFrame then
                        NC.ChestCounterFrame:SetHidden(false)
                        NC.ChestCounterFrame:BringWindowToTop()
                    end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CHEST_RESET),
            function()
                if NC.savedVars and NC.ChestCounterFrame then
                    NC.ChestCounterFrame:ClearAnchors()
                    NC.ChestCounterFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.chestLeft = NC.ChestCounterFrame:GetLeft()
                    NC.savedVars.chestTop  = NC.ChestCounterFrame:GetTop()
                end
            end,
            currentY + 2
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_PLANAR_KEY), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_ENABLE),
            function() return NC.savedVars and NC.savedVars.planarKeyWidgetEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetEnabled = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_UNLOCK),
            function() return NC.savedVars and NC.savedVars.planarKeyWidgetUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetUnlocked = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_SIZE), 24, 96, 2,
            function() return (NC.savedVars and NC.savedVars.planarKeyWidgetSize) or 56 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetSize = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_FONT_SIZE), 12, 48, 1,
            function() return (NC.savedVars and NC.savedVars.planarKeyWidgetFontSize) or 26 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetFontSize = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_OFFSET_X), -60, 60, 1,
            function() return (NC.savedVars and NC.savedVars.planarKeyWidgetOffsetX) or 0 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetOffsetX = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_OFFSET_Y), -60, 60, 1,
            function() return (NC.savedVars and NC.savedVars.planarKeyWidgetOffsetY) or 0 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.planarKeyWidgetOffsetY = v 
                    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_PLANAR_KEY_RESET),
            function()
                if NC.savedVars and NC.PlanarKeyWidgetFrame then
                    NC.PlanarKeyWidgetFrame:ClearAnchors()
                    NC.PlanarKeyWidgetFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.planarKeyWidgetLeft = NC.PlanarKeyWidgetFrame:GetLeft()
                    NC.savedVars.planarKeyWidgetTop  = NC.PlanarKeyWidgetFrame:GetTop()
                end
            end,
            currentY + 2
        )
        
        -- -----------------------------------------------------
        -- ФИЛЬТР ИСТОРИИ ДОБЫЧИ (ЛУТА)
        -- -----------------------------------------------------
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_LOOT_FILTER), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_ENABLE),
            function() return NC.savedVars and NC.savedVars.lootFilterEnabled end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterEnabled = v end end,
            currentY
        )

        local qualChoices = {
            GetString(SI_NC_LAM_LOOT_QUAL_ALL),
            GetString(SI_NC_LAM_LOOT_QUAL_GREEN),
            GetString(SI_NC_LAM_LOOT_QUAL_BLUE),
            GetString(SI_NC_LAM_LOOT_QUAL_PURPLE),
            GetString(SI_NC_LAM_LOOT_QUAL_GOLD),
        }
        local qualValues = { 0, 2, 3, 4, 5 }

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_LOOT_MIN_QUAL), qualChoices, qualValues,
            function() return (NC.savedVars and NC.savedVars.lootFilterMinQuality) or 0 end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterMinQuality = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_HIDE_TRASH),
            function() return NC.savedVars and NC.savedVars.lootFilterHideTrash end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterHideTrash = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_HIDE_MATERIALS),
            function() return NC.savedVars and NC.savedVars.lootFilterHideMaterials end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterHideMaterials = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_HIDE_TRAITS),
            function() return NC.savedVars and NC.savedVars.lootFilterHideTraits end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterHideTraits = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_ALWAYS_RARE),
            function() return NC.savedVars and NC.savedVars.lootFilterAlwaysRare end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterAlwaysRare = v end end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOOT_ALWAYS_RECIPES),
            function() return NC.savedVars and NC.savedVars.lootFilterAlwaysRecipes end,
            function(v) if NC.savedVars then NC.savedVars.lootFilterAlwaysRecipes = v end end,
            currentY
        )
        
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_CURRENCIES), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CURRENCY_ENABLE),
            function() return NC.savedVars and NC.savedVars.currencyTrackerEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyTrackerEnabled = v 
                    if NC.UpdateCurrencyTrackerUI then NC.UpdateCurrencyTrackerUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CURRENCY_UNLOCK),
            function() return NC.savedVars and NC.savedVars.currencyTrackerUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyTrackerUnlocked = v 
                    if NC.UpdateCurrencyTrackerUI then NC.UpdateCurrencyTrackerUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CURRENCY_CONTEXT),
            function() return NC.savedVars and NC.savedVars.currencyTrackerContextOnly end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyTrackerContextOnly = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_GOLD),
            function() return NC.savedVars and NC.savedVars.currencyShowGold ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowGold = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_BARS),
            function() return NC.savedVars and NC.savedVars.currencyShowBars ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowBars = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_AP),
            function() return NC.savedVars and NC.savedVars.currencyShowAP ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowAP = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_TELVAR),
            function() return NC.savedVars and NC.savedVars.currencyShowTelVar ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowTelVar = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )
        
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_PLANAR_KEYS),
            function() return NC.savedVars and NC.savedVars.currencyShowPlanarKeys ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowPlanarKeys = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )
        
        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_ARCHIVE),
            function() return NC.savedVars and NC.savedVars.currencyShowArchive ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowArchive = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CUR_XP),
            function() return NC.savedVars and NC.savedVars.currencyShowXP ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.currencyShowXP = v 
                    if NC.UpdateCurrencyTracker then NC.UpdateCurrencyTracker() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CUR_RESET),
            function()
                if NC.savedVars and NC.CurrencyTrackerFrame then
                    NC.CurrencyTrackerFrame:ClearAnchors()
                    NC.CurrencyTrackerFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.currencyTrackerLeft = NC.CurrencyTrackerFrame:GetLeft()
                    NC.savedVars.currencyTrackerTop  = NC.CurrencyTrackerFrame:GetTop()
                end
            end,
            currentY + 2
        )

    elseif tabId == 6 then
        -- =====================================================
        -- РАЗДЕЛ 6: АВТО-ЗАРЯДКА И ПОЧИНКА
        -- =====================================================
        local prioChoices = { GetString(SI_NC_LAM_PRIORITY_1), GetString(SI_NC_LAM_PRIORITY_2), GetString(SI_NC_LAM_PRIORITY_3), GetString(SI_NC_LAM_PRIORITY_4) }
        local prioValues  = { 1, 2, 3, 4 }

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_RECHARGE), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_RECHARGE_ENABLE),
            function() return NC.savedVars and NC.savedVars.autoRechargeEnabled end,
            function(v) if NC.savedVars then NC.savedVars.autoRechargeEnabled = v end end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_RECHARGE_THRESHOLD), 1, 100, 1,
            function() return (NC.savedVars and NC.savedVars.autoRechargeThreshold) or 20 end,
            function(v) if NC.savedVars then NC.savedVars.autoRechargeThreshold = v end end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_RECHARGE_PRIORITY), prioChoices, prioValues,
            function() return (NC.savedVars and NC.savedVars.autoRechargePriority) or 2 end,
            function(v) if NC.savedVars then NC.savedVars.autoRechargePriority = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_REPAIR), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_REPAIR_ENABLE),
            function() return NC.savedVars and NC.savedVars.autoRepairKitsEnabled end,
            function(v) if NC.savedVars then NC.savedVars.autoRepairKitsEnabled = v end end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_REPAIR_THRESHOLD), 1, 100, 1,
            function() return (NC.savedVars and NC.savedVars.autoRepairKitsThreshold) or 20 end,
            function(v) if NC.savedVars then NC.savedVars.autoRepairKitsThreshold = v end end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_REPAIR_PRIORITY), prioChoices, prioValues,
            function() return (NC.savedVars and NC.savedVars.autoRepairKitsPriority) or 2 end,
            function(v) if NC.savedVars then NC.savedVars.autoRepairKitsPriority = v end end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_VENDOR), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_VENDOR_REPAIR),
            function() return NC.savedVars and NC.savedVars.autoVendorRepairEnabled end,
            function(v) if NC.savedVars then NC.savedVars.autoVendorRepairEnabled = v end end,
            currentY
        )

    elseif tabId == 7 then
        -- =====================================================
        -- РАЗДЕЛ 7: БАФФЫ И ДЕБАФФЫ
        -- =====================================================
        local orientChoices = { GetString(SI_NC_LAM_ORIENT_VERT), GetString(SI_NC_LAM_ORIENT_HORIZ) }
        local orientValues  = { 1, 2 }
        local growthChoices = { GetString(SI_NC_LAM_GROWTH_AUTO), GetString(SI_NC_LAM_GROWTH_DIRECT), GetString(SI_NC_LAM_GROWTH_REVERSE) }
        local growthValues  = { 1, 2, 3 }

        -- 1. Долгие баффы
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_LONG_BUFFS), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LONG_BUFFS_ENABLE),
            function() return NC.savedVars and NC.savedVars.longBuffsEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsEnabled = v 
                    if NC.UpdateLongBuffsUI then NC.UpdateLongBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LONG_BUFFS_UNLOCK),
            function() return NC.savedVars and NC.savedVars.longBuffsUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsUnlocked = v 
                    if NC.UpdateLongBuffsUI then NC.UpdateLongBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_ORIENTATION), orientChoices, orientValues,
            function() return (NC.savedVars and NC.savedVars.longBuffsOrientation) or 1 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsOrientation = v 
                    if NC.UpdateLongBuffsUI then NC.UpdateLongBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_GROWTH), growthChoices, growthValues,
            function() return (NC.savedVars and NC.savedVars.longBuffsGrowth) or 1 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsGrowth = v 
                    if NC.UpdateLongBuffs then NC.UpdateLongBuffs() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BUFFS_SIZE), 20, 64, 2,
            function() return (NC.savedVars and NC.savedVars.longBuffsSize) or 36 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsSize = v 
                    if NC.UpdateLongBuffsUI then NC.UpdateLongBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BUFFS_PERMANENT),
            function() return NC.savedVars and NC.savedVars.longBuffsShowPermanent end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.longBuffsShowPermanent = v 
                    if NC.UpdateLongBuffs then NC.UpdateLongBuffs() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_BUFFS_RESET),
            function()
                if NC.savedVars and NC.LongBuffsFrame then
                    NC.LongBuffsFrame:ClearAnchors()
                    NC.LongBuffsFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.longBuffsLeft = NC.LongBuffsFrame:GetLeft()
                    NC.savedVars.longBuffsTop  = NC.LongBuffsFrame:GetTop()
                end
            end,
            currentY + 2
        )

        -- 2. Короткие баффы
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SHORT_BUFFS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SHORT_BUFFS_ENABLE),
            function() return NC.savedVars and NC.savedVars.shortBuffsEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.shortBuffsEnabled = v 
                    if NC.UpdateShortBuffsUI then NC.UpdateShortBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LONG_BUFFS_UNLOCK),
            function() return NC.savedVars and NC.savedVars.shortBuffsUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.shortBuffsUnlocked = v 
                    if NC.UpdateShortBuffsUI then NC.UpdateShortBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_ORIENTATION), orientChoices, orientValues,
            function() return (NC.savedVars and NC.savedVars.shortBuffsOrientation) or 2 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.shortBuffsOrientation = v 
                    if NC.UpdateShortBuffsUI then NC.UpdateShortBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_GROWTH), growthChoices, growthValues,
            function() return (NC.savedVars and NC.savedVars.shortBuffsGrowth) or 1 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.shortBuffsGrowth = v 
                    if NC.UpdateShortBuffs then NC.UpdateShortBuffs() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BUFFS_SIZE), 20, 64, 2,
            function() return (NC.savedVars and NC.savedVars.shortBuffsSize) or 36 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.shortBuffsSize = v 
                    if NC.UpdateShortBuffsUI then NC.UpdateShortBuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_BUFFS_RESET),
            function()
                if NC.savedVars and NC.ShortBuffsFrame then
                    NC.ShortBuffsFrame:ClearAnchors()
                    NC.ShortBuffsFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.shortBuffsLeft = NC.ShortBuffsFrame:GetLeft()
                    NC.savedVars.shortBuffsTop  = NC.ShortBuffsFrame:GetTop()
                end
            end,
            currentY + 2
        )

        -- 3. Дебаффы на игроке
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_PLAYER_DEBUFFS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_PLAYER_DEBUFFS_ENABLE),
            function() return NC.savedVars and NC.savedVars.playerDebuffsEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.playerDebuffsEnabled = v 
                    if NC.UpdatePlayerDebuffsUI then NC.UpdatePlayerDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LONG_BUFFS_UNLOCK),
            function() return NC.savedVars and NC.savedVars.playerDebuffsUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.playerDebuffsUnlocked = v 
                    if NC.UpdatePlayerDebuffsUI then NC.UpdatePlayerDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_ORIENTATION), orientChoices, orientValues,
            function() return (NC.savedVars and NC.savedVars.playerDebuffsOrientation) or 2 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.playerDebuffsOrientation = v 
                    if NC.UpdatePlayerDebuffsUI then NC.UpdatePlayerDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_GROWTH), growthChoices, growthValues,
            function() return (NC.savedVars and NC.savedVars.playerDebuffsGrowth) or 1 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.playerDebuffsGrowth = v 
                    if NC.UpdatePlayerDebuffs then NC.UpdatePlayerDebuffs() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BUFFS_SIZE), 20, 64, 2,
            function() return (NC.savedVars and NC.savedVars.playerDebuffsSize) or 36 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.playerDebuffsSize = v 
                    if NC.UpdatePlayerDebuffsUI then NC.UpdatePlayerDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_BUFFS_RESET),
            function()
                if NC.savedVars and NC.PlayerDebuffsFrame then
                    NC.PlayerDebuffsFrame:ClearAnchors()
                    NC.PlayerDebuffsFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.playerDebuffsLeft = NC.PlayerDebuffsFrame:GetLeft()
                    NC.savedVars.playerDebuffsTop  = NC.PlayerDebuffsFrame:GetTop()
                end
            end,
            currentY + 2
        )

        -- 4. Дебаффы на цели
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_TARGET_DEBUFFS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_DEBUFFS_ENABLE),
            function() return NC.savedVars and NC.savedVars.targetDebuffsEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.targetDebuffsEnabled = v 
                    if NC.UpdateTargetDebuffsUI then NC.UpdateTargetDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LONG_BUFFS_UNLOCK),
            function() return NC.savedVars and NC.savedVars.targetDebuffsUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.targetDebuffsUnlocked = v 
                    if NC.UpdateTargetDebuffsUI then NC.UpdateTargetDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_DEBUFFS_ONLY_PLAYER),
            function() return NC.savedVars and NC.savedVars.targetDebuffsOnlyPlayer end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.targetDebuffsOnlyPlayer = v 
                    if NC.UpdateTargetDebuffs then NC.UpdateTargetDebuffs() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BUFFS_ORIENTATION), orientChoices, orientValues,
            function() return (NC.savedVars and NC.savedVars.targetDebuffsOrientation) or 2 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.targetDebuffsOrientation = v 
                    if NC.UpdateTargetDebuffsUI then NC.UpdateTargetDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BUFFS_SIZE), 20, 64, 2,
            function() return (NC.savedVars and NC.savedVars.targetDebuffsSize) or 36 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.targetDebuffsSize = v 
                    if NC.UpdateTargetDebuffsUI then NC.UpdateTargetDebuffsUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_BUFFS_RESET),
            function()
                if NC.savedVars and NC.TargetDebuffsFrame then
                    NC.TargetDebuffsFrame:ClearAnchors()
                    NC.TargetDebuffsFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.targetDebuffsLeft = NC.TargetDebuffsFrame:GetLeft()
                    NC.savedVars.targetDebuffsTop  = NC.TargetDebuffsFrame:GetTop()
                end
            end,
            currentY + 2
        )

        -- 5. Напоминания (Еда, Торт, Опыт)
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_FOOD_REMINDER), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOOD_REMINDER_ENABLE),
            function() return NC.savedVars and NC.savedVars.foodReminderEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderEnabled = v 
                    if NC.UpdateFoodReminderUI then NC.UpdateFoodReminderUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_REMINDER_SHOW_FOOD),
            function() return NC.savedVars and NC.savedVars.foodReminderShowFood ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderShowFood = v 
                    if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_REMINDER_SHOW_TORTE),
            function() return NC.savedVars and NC.savedVars.foodReminderShowTorte ~= false end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderShowTorte = v 
                    if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_REMINDER_SHOW_XP),
            function() return NC.savedVars and NC.savedVars.foodReminderShowXP == true end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderShowXP = v 
                    if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOOD_REMINDER_UNLOCK),
            function() return NC.savedVars and NC.savedVars.foodReminderUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderUnlocked = v 
                    if NC.UpdateFoodReminderUI then NC.UpdateFoodReminderUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_FOOD_REMINDER_PREVIEW),
            function() return NC.savedVars and NC.savedVars.foodReminderPreview end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderPreview = v 
                    if NC.UpdateFoodReminder then NC.UpdateFoodReminder() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_FOOD_REMINDER_SIZE), 24, 80, 2,
            function() return (NC.savedVars and NC.savedVars.foodReminderSize) or 48 end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.foodReminderSize = v 
                    if NC.UpdateFoodReminderUI then NC.UpdateFoodReminderUI() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_FOOD_REMINDER_RESET),
            function()
                if NC.savedVars and NC.FoodReminderFrame then
                    NC.FoodReminderFrame:ClearAnchors()
                    NC.FoodReminderFrame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
                    NC.savedVars.foodReminderLeft = NC.FoodReminderFrame:GetLeft()
                    NC.savedVars.foodReminderTop  = NC.FoodReminderFrame:GetTop()
                end
            end,
            currentY + 2
        )

    elseif tabId == 8 then
        -- =====================================================
        -- РАЗДЕЛ 8: ДАНЖИ И ТРИАЛЫ
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SPEEDRUN), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDRUN_ENABLE),
            function() return NC.savedVars and NC.savedVars.speedrunHudEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedrunHudEnabled = v 
                    if NC.UpdateSpeedrunHudUI then NC.UpdateSpeedrunHudUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDRUN_UNLOCK),
            function() return NC.savedVars and NC.savedVars.speedrunHudUnlocked end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedrunHudUnlocked = v 
                    if NC.UpdateSpeedrunHudUI then NC.UpdateSpeedrunHudUI() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SPEEDRUN_VET_ONLY),
            function() return NC.savedVars and NC.savedVars.speedrunHudVetOnly end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.speedrunHudVetOnly = v 
                    if NC.UpdateSpeedrunHud then NC.UpdateSpeedrunHud() end
                end
            end,
            currentY
        )

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_LOGS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOG_ENABLE),
            function() return NC.savedVars and NC.savedVars.autoEncounterLog end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.autoEncounterLog = v 
                    if NC.CheckAutoEncounterLog then NC.CheckAutoEncounterLog() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_LOG_VET_ONLY),
            function() return NC.savedVars and NC.savedVars.autoEncounterLogVetOnly end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.autoEncounterLogVetOnly = v 
                    if NC.CheckAutoEncounterLog then NC.CheckAutoEncounterLog() end
                end
            end,
            currentY
        )

elseif tabId == 9 then
        -- =====================================================
        -- РАЗДЕЛ 9: ФРЕЙМЫ ИГРОКА И ОСАДКИ
        -- =====================================================
        local Frames = NecroCat.Frames

        local styleNames, styleIds = {}, {}
        if Frames and Frames.STYLES then
            for id, st in ipairs(Frames.STYLES) do
                table.insert(styleNames, GetString(_G[st.name] or st.name))
                table.insert(styleIds, id)
            end
        end

        local texNames, texIds = {}, {}
        if Frames and Frames.GetBarTextureChoices then
            texNames, texIds = Frames.GetBarTextureChoices()
        end

        local siegeStyleNames, siegeStyleIds = {}, {}
        if Frames and Frames.GetSiegeStyleChoices then
            siegeStyleNames, siegeStyleIds = Frames.GetSiegeStyleChoices()
        end

        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_PLAYER_ENABLE), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_PLAYER_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.playerEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.playerEnabled = v
                    if Frames and Frames.UpdateVisibility then Frames.UpdateVisibility() end
                    if Frames and Frames.UpdateDefaultBarsVisibility then Frames.UpdateDefaultBarsVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_PLAYER_UNLOCK),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.playerLocked == false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.playerLocked = not v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                    if Frames and Frames.UpdateVisibility then Frames.UpdateVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_DEFAULT_BARS),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.hideDefaultBars ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.hideDefaultBars = v
                    if Frames and Frames.UpdateDefaultBarsVisibility then Frames.UpdateDefaultBarsVisibility() end
                end
            end,
            currentY
        )

        local layoutChoices = { GetString(SI_NC_LAM_LAYOUT_PYRAMID), GetString(SI_NC_LAM_LAYOUT_VERTICAL), GetString(SI_NC_LAM_LAYOUT_HORIZONTAL), GetString(SI_NC_LAM_LAYOUT_SEPARATE) }
        local layoutValues  = { 1, 2, 3, 4 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_FRAMES_LAYOUT), layoutChoices, layoutValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.layoutTemplate) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.layoutTemplate = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        local curStyleId = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.frameStyle) or 1
        local curStyle   = Frames and Frames.STYLES and Frames.STYLES[curStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_FRAME_STYLE), styleNames, styleIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.frameStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.frameStyle = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                    RenderTabContent(9) -- Мгновенно обновляем список!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curStyle and curStyle.colorVariants and #curStyle.colorVariants > 1 then
            local colorChoices, colorValues = {}, {}
            for cId, cVar in ipairs(curStyle.colorVariants) do
                table.insert(colorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(colorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_STYLE_COLOR), colorChoices, colorValues,
                function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.styleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.frames then
                        NC.savedVars.frames.styleColor = v
                        if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HEALTH_CENTER_FILL),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.healthCenterFill end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.healthCenterFill = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        -- Текст полос
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_TEXT_MODE), currentY + 6)

        local textChoices = { GetString(SI_NC_LAM_TEXT_MODE_SPLIT), GetString(SI_NC_LAM_TEXT_MODE_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_MODE_CENTER_VAL), GetString(SI_NC_LAM_TEXT_MODE_CENTER_PCT), GetString(SI_NC_LAM_TEXT_MODE_NONE) }
        local textValues  = { 1, 2, 3, 4, 5 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TEXT_MODE), textChoices, textValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.textMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.textMode = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SHOW_SHIELD_NUM),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showShieldText ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showShieldText = v
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SHOW_TRAUMA_NUM),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showTraumaText ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showTraumaText = v
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        -- Размеры и зазоры
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SIZES), currentY + 6)

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_FRAME_SCALE), 70, 150, 5,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.frameScale) or 100 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.frameScale = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLAYER_WIDTH), 140, 360, 10,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.playerWidth) or 200 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.playerWidth = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_PLAYER_HEIGHT), 14, 40, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.playerHeight) or 20 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.playerHeight = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TEXT_SIZE), 10, 30, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.fontSize) or 14 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.fontSize = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SPACING_X), -40, 40, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.spacingOffsetX) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.spacingOffsetX = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SPACING_Y), -40, 40, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.spacingOffsetY) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.spacingOffsetY = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_RESET_POS),
            function()
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.playerLeft = 450
                    NC.savedVars.frames.playerTop  = 650
                    NC.savedVars.frames.magLeft    = 347
                    NC.savedVars.frames.magTop     = 674
                    NC.savedVars.frames.stamLeft   = 553
                    NC.savedVars.frames.stamTop    = 674
                    NC.savedVars.frames.siegeLeft  = 450
                    NC.savedVars.frames.siegeTop   = 580
                    NC.savedVars.frames.spacingOffsetX = 0
                    NC.savedVars.frames.spacingOffsetY = 0
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY + 2
        )

        -- Осадное орудие
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SIEGE), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_SIEGE_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeEnabled = v
                    if Frames and Frames.UpdateSiegeBar then Frames.UpdateSiegeBar() end
                end
            end,
            currentY
        )

        local curSiegeStyleId = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeStyle) or 1
        local curSiegeStyle   = Frames and Frames.SIEGE_STYLES and Frames.SIEGE_STYLES[curSiegeStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_SIEGE_STYLE), siegeStyleNames, siegeStyleIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeStyle = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                    RenderTabContent(9) -- Мгновенно обновляем меню осадки!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета осадки ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curSiegeStyle and curSiegeStyle.colorVariants and #curSiegeStyle.colorVariants > 1 then
            local siegeColorChoices, siegeColorValues = {}, {}
            for cId, cVar in ipairs(curSiegeStyle.colorVariants) do
                table.insert(siegeColorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(siegeColorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_STYLE_COLOR), siegeColorChoices, siegeColorValues,
                function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeStyleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.frames then
                        NC.savedVars.frames.siegeStyleColor = v
                        if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SIEGE_WIDTH), 160, 500, 10,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeWidth) or 300 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeWidth = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SIEGE_HEIGHT), 10, 40, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeHeight) or 20 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeHeight = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SIEGE_TITLE_SIZE), 10, 24, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeTitleFontSize) or 14 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeTitleFontSize = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SIEGE_FONT_SIZE), 10, 24, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeFontSize) or 13 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeFontSize = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_SIEGE_TEXT_OFFSET_Y), -10, 10, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeLabelOffsetY) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeLabelOffsetY = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_SIEGE_TEXT_MODE), textChoices, textValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeTextMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeTextMode = v
                    if Frames and Frames.ApplyLayout then Frames.ApplyLayout() end
                end
            end,
            currentY
        )

        -- Тесты
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_TEST_SIM), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TEST_SIEGE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.testSiege end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.testSiege = v
                    if Frames and Frames.UpdateSiegeBar then Frames.UpdateSiegeBar() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TEST_SHIELD),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.testShield end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.testShield = v
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TEST_TRAUMA),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.testTrauma end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.testTrauma = v
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        -- Текстуры полос
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_BAR_TEXTURES), currentY + 6)

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TEX_HEALTH), texNames, texIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.healthBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.healthBarTexture = v
                    if Frames and Frames.ApplyBarTextures then Frames.ApplyBarTextures() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TEX_MAGICKA), texNames, texIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.magickaBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.magickaBarTexture = v
                    if Frames and Frames.ApplyBarTextures then Frames.ApplyBarTextures() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TEX_STAMINA), texNames, texIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.staminaBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.staminaBarTexture = v
                    if Frames and Frames.ApplyBarTextures then Frames.ApplyBarTextures() end
                end
            end,
            currentY
        )

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TEX_SIEGE), texNames, texIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeBarTexture = v
                    if Frames and Frames.ApplyBarTextures then Frames.ApplyBarTextures() end
                end
            end,
            currentY
        )

        -- Палитра цветов
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_COLORS), currentY + 6)

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.textColor) or { 1, 1, 1, 1 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.textColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_SHIELD_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.shieldTextColor) or { 0.25, 0.85, 1.0, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.shieldTextColor = { r, g, b, a }
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_TRAUMA_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.traumaTextColor) or { 0.85, 0.35, 0.75, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.traumaTextColor = { r, g, b, a }
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_HEALTH),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.healthColor) or { 0.76, 0.12, 0.12, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.healthColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_SHIELD),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.shieldColor) or { 0.25, 0.75, 0.95, 0.55 }
                return c[1], c[2], c[3], c[4] or 0.55
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.shieldColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_TRAUMA),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.traumaColor) or { 0.58, 0.12, 0.48, 0.75 }
                return c[1], c[2], c[3], c[4] or 0.75
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.traumaColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                    if Frames and Frames.UpdatePlayerHealth then Frames.UpdatePlayerHealth() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_MAGICKA),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.magickaColor) or { 0.12, 0.38, 0.78, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.magickaColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_STAMINA),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.staminaColor) or { 0.14, 0.58, 0.22, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.staminaColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_MOUNT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.mountColor) or { 0.08, 0.38, 0.15, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.mountColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_SIEGE),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeColor) or { 0.60, 0.62, 0.68, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COLOR_SIEGE_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.siegeTextColor) or { 1, 1, 1, 1 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.siegeTextColor = { r, g, b, a }
                    if Frames and Frames.ApplyColors then Frames.ApplyColors() end
                end
            end,
            currentY
        )

    elseif tabId == 10 then
        -- =====================================================
        -- РАЗДЕЛ 10: ФРЕЙМ ЦЕЛИ
        -- =====================================================
        local Frames = NecroCat.Frames

        local targetStyleNames, targetStyleIds = {}, {}
        if Frames and Frames.TARGET_STYLES then
            for id = 1, #Frames.TARGET_STYLES do
                local st = Frames.TARGET_STYLES[id]
                if st then
                    table.insert(targetStyleNames, GetString(_G[st.name] or st.name))
                    table.insert(targetStyleIds, id)
                end
            end
        end

        local targetTexNames, targetTexIds = {}, {}
        if Frames and Frames.TARGET_BAR_TEXTURES then
            for id = 1, #Frames.TARGET_BAR_TEXTURES do
                local tex = Frames.TARGET_BAR_TEXTURES[id]
                if tex then
                    table.insert(targetTexNames, GetString(_G[tex.name] or tex.name))
                    table.insert(targetTexIds, id)
                end
            end
        end

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetEnabled = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    if Frames and Frames.UpdateDefaultTargetVisibility then Frames.UpdateDefaultTargetVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_HIDE_DEFAULT),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.hideDefaultTarget ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.hideDefaultTarget = v
                    if Frames and Frames.UpdateDefaultTargetVisibility then Frames.UpdateDefaultTargetVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_UNLOCK),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetLocked == false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetLocked = not v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        local curTargStyleId = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetFrameStyle) or 1
        local curTargStyle   = Frames and Frames.TARGET_STYLES and Frames.TARGET_STYLES[curTargStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_STYLE), targetStyleNames, targetStyleIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetFrameStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetFrameStyle = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    RenderTabContent(10) -- Мгновенно обновляем список!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета цели ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curTargStyle and curTargStyle.colorVariants and #curTargStyle.colorVariants > 1 then
            local colorChoices, colorValues = {}, {}
            for cId, cVar in ipairs(curTargStyle.colorVariants) do
                table.insert(colorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(colorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_STYLE_COLOR), colorChoices, colorValues,
                function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetStyleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.frames then
                        NC.savedVars.frames.targetStyleColor = v
                        if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_TEX_BAR), targetTexNames, targetTexIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetBarTexture = v
                    if Frames and Frames.ApplyTargetBarTexture then Frames.ApplyTargetBarTexture() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HEALTH_CENTER_FILL),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.healthCenterFill end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.healthCenterFill = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        local nameFormatChoices = { GetString(SI_NC_LAM_TARGET_NAME_CHAR), GetString(SI_NC_LAM_TARGET_NAME_ID), GetString(SI_NC_LAM_TARGET_NAME_BOTH) }
        local nameFormatValues  = { 1, 2, 3 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_NAME_FORMAT), nameFormatChoices, nameFormatValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.nameFormat) or 3 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.nameFormat = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_SHOW_CLASS),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showClass ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showClass = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_CLASS_OFFSET_X), -50, 20, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.classOffsetX) or -4 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.classOffsetX = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_CLASS_SIZE), 16, 64, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.classIconSize) or 28 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.classIconSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_SHOW_ALLIANCE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showAlliance ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showAlliance = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_ALLIANCE_OFFSET_X), -20, 50, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.allianceOffsetX) or 4 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.allianceOffsetX = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_ALLIANCE_SIZE), 16, 64, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.allianceIconSize) or 28 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.allianceIconSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        local lvlChoices = { GetString(SI_NC_LAM_TARGET_LEVEL_MODE_PLAYERS), GetString(SI_NC_LAM_TARGET_LEVEL_MODE_ALL), GetString(SI_NC_LAM_TARGET_LEVEL_MODE_NONE) }
        local lvlValues  = { 1, 2, 3 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_LEVEL_MODE), lvlChoices, lvlValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.levelDisplayMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.levelDisplayMode = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        local cpChoices = { GetString(SI_NC_LAM_TARGET_CP_MODE_TIERS), GetString(SI_NC_LAM_TARGET_CP_MODE_WHITE), GetString(SI_NC_LAM_TARGET_CP_MODE_CUSTOM) }
        local cpValues  = { 1, 2, 3 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_TARGET_CP_COLOR_MODE), cpChoices, cpValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.cpColorMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.cpColorMode = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_CP_COLOR_CUSTOM),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.customCpColor) or { 1.0, 0.85, 0.2, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.customCpColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_SHOW_RACE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showRace ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showRace = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_SHOW_RANK),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showRank ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showRank = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_SHOW_SKULL),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.showSkull ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.showSkull = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        -- Добивание
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_TARGET_HDR_EXECUTE), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_EXECUTE_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.executeEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.executeEnabled = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_EXECUTE_THRESHOLD), 15, 50, 5,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.executeThreshold) or 25 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.executeThreshold = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        -- Размеры и шрифты
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SIZES), currentY + 6)

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SCALE), 70, 150, 5,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetScale) or 100 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetScale = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_WIDTH), 160, 360, 10,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetWidth) or 240 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetWidth = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_HEIGHT), 16, 36, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetHeight) or 22 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetHeight = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_FONT_SIZE), 10, 22, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.fontSize) or 14 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.fontSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_TOP_FONT_SIZE), 12, 22, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.topFontSize) or 15 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.topFontSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_TOP_OFFSET_Y), -40, 10, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.topOffsetY) or -4 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.topOffsetY = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SUB_FONT_SIZE), 10, 20, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.subFontSize) or 14 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.subFontSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SKULL_SIZE), 16, 100, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.skullSize) or 40 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.skullSize = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SKULL_Y), -60, 40, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.skullOffsetY) or 4 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.skullOffsetY = v
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_TARGET_RESET_POS),
            function()
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetLeft = 840
                    NC.savedVars.frames.targetTop  = 650
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY + 2
        )

        -- Цвета цели
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_TARGET_HDR_COLORS), currentY + 6)

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_HOSTILE),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.hostileColor) or { 0.76, 0.12, 0.12, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.hostileColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_NEUTRAL),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.neutralColor) or { 0.85, 0.75, 0.15, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.neutralColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_FRIENDLY),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.friendlyColor) or { 0.14, 0.65, 0.22, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.friendlyColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_SHIELD),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetShieldColor) or { 0.25, 0.75, 0.95, 0.55 }
                return c[1], c[2], c[3], c[4] or 0.55
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetShieldColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.targetTextColor) or { 1.0, 1.0, 1.0, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.targetTextColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_RANK),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.rankColor) or { 0.90, 0.77, 0.57, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.rankColor = { r, g, b, a }
                    if Frames and Frames.ApplyTargetColors then Frames.ApplyTargetColors() end
                end
            end,
            currentY
        )

    elseif tabId == 11 then
        -- =====================================================
        -- РАЗДЕЛ 11: ФРЕЙМ БОССА
        -- =====================================================
        local Frames = NecroCat.Frames

        local bossStyleNames, bossStyleIds = {}, {}
        if Frames and Frames.BOSS_STYLES then
            for id = 1, #Frames.BOSS_STYLES do
                local st = Frames.BOSS_STYLES[id]
                if st then
                    table.insert(bossStyleNames, GetString(_G[st.name] or st.name))
                    table.insert(bossStyleIds, id)
                end
            end
        end

        local bossTexNames, bossTexIds = {}, {}
        if Frames and Frames.BOSS_BAR_TEXTURES then
            for id = 1, #Frames.BOSS_BAR_TEXTURES do
                local tex = Frames.BOSS_BAR_TEXTURES[id]
                if tex then
                    table.insert(bossTexNames, GetString(_G[tex.name] or tex.name))
                    table.insert(bossTexIds, id)
                end
            end
        end

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BOSS_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossEnabled = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    if Frames and Frames.UpdateDefaultBossBarsVisibility then Frames.UpdateDefaultBossBarsVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BOSS_UNLOCK),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossLocked == false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossLocked = not v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BOSS_HIDE_DEFAULT),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.hideDefaultBossBar ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.hideDefaultBossBar = v
                    if Frames and Frames.UpdateDefaultBossBarsVisibility then Frames.UpdateDefaultBossBarsVisibility() end
                end
            end,
            currentY
        )

        local posChoices = { GetString(SI_NC_LAM_BOSS_POS_COMPASS), GetString(SI_NC_LAM_BOSS_POS_CUSTOM) }
        local posValues  = { 1, 2 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BOSS_POS_MODE), posChoices, posValues,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossPosMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossPosMode = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        -- Стиль и оформление босса
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_BOSS_HDR_STYLE), currentY + 6)

        local curBossStyleId = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossFrameStyle) or 1
        local curBossStyle   = Frames and Frames.BOSS_STYLES and Frames.BOSS_STYLES[curBossStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BOSS_STYLE), bossStyleNames, bossStyleIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossFrameStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossFrameStyle = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    RenderTabContent(11) -- Мгновенно обновляем меню при смене стиля!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curBossStyle and curBossStyle.colorVariants and #curBossStyle.colorVariants > 1 then
            local colorChoices, colorValues = {}, {}
            for cId, cVar in ipairs(curBossStyle.colorVariants) do
                table.insert(colorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(colorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BOSS_STYLE_COLOR), colorChoices, colorValues,
                function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossStyleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.frames then
                        NC.savedVars.frames.bossStyleColor = v
                        if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_BOSS_TEX_BAR), bossTexNames, bossTexIds,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossBarTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossBarTexture = v
                    if Frames and Frames.ApplyBossBarTexture then Frames.ApplyBossBarTexture() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HEALTH_CENTER_FILL),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossHealthCenterFill end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossHealthCenterFill = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BOSS_SHOW_NAME),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossShowName ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossShowName = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_BOSS_SHOW_SKULL),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossShowSkull ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossShowSkull = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        -- Добивание
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_TARGET_HDR_EXECUTE), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_TARGET_EXECUTE_ENABLE),
            function() return NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossExecuteEnabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossExecuteEnabled = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_EXECUTE_THRESHOLD), 15, 50, 5,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossExecuteThreshold) or 25 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossExecuteThreshold = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        -- Размеры и шрифты
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_HDR_SIZES), currentY + 6)

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BOSS_SCALE), 70, 150, 5,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossScale) or 100 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossScale = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BOSS_WIDTH), 260, 900, 10,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossWidth) or 600 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossWidth = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BOSS_HEIGHT), 18, 46, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossHeight) or 26 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossHeight = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BOSS_FONT_SIZE), 10, 24, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossFontSize) or 15 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossFontSize = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_BOSS_NAME_SIZE), 12, 26, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossNameSize) or 16 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossNameSize = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SKULL_SIZE), 20, 100, 2,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossSkullSize) or 44 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossSkullSize = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_TARGET_SKULL_Y), -60, 25, 1,
            function() return (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossSkullOffsetY) or 4 end,
            function(v)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossSkullOffsetY = v
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_BOSS_RESET_POS),
            function()
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossLeft = 660
                    NC.savedVars.frames.bossTop  = 120
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY + 2
        )

        -- Цвета
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_TARGET_HDR_COLORS), currentY + 6)

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_HOSTILE),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossColor) or { 0.76, 0.12, 0.12, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossColor = { r, g, b, a }
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_SHIELD),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossShieldColor) or { 0.25, 0.75, 0.95, 0.55 }
                return c[1], c[2], c[3], c[4] or 0.55
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossShieldColor = { r, g, b, a }
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_TARGET_COLOR_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.frames and NC.savedVars.frames.bossTextColor) or { 1.0, 1.0, 1.0, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.frames then
                    NC.savedVars.frames.bossTextColor = { r, g, b, a }
                    if Frames and Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
                end
            end,
            currentY
        )

    elseif tabId == 12 then
        -- =====================================================
        -- РАЗДЕЛ 12: ФРЕЙМЫ ГРУППЫ И РЕЙДА
        -- =====================================================
        local GF = NecroCat.GroupFrames

        local groupStyleNames, groupStyleIds = {}, {}
        if GF and GF.STYLES then
            for id, st in ipairs(GF.STYLES) do
                table.insert(groupStyleNames, GetString(_G[st.name] or st.name))
                table.insert(groupStyleIds, id)
            end
        end

        local groupTexNames, groupTexIds = {}, {}
        if GF and GF.GetBarTextureChoices then
            groupTexNames, groupTexIds = GF.GetBarTextureChoices()
        end

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_ENABLE),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.enabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.enabled = v
                    if GF and GF.UpdateVisibility then GF.UpdateVisibility() end
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                    if GF and GF.UpdateDefaultGroupBarsVisibility then GF.UpdateDefaultGroupBarsVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_HIDE_DEFAULT_GROUP),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.hideDefaultGroupBars ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.hideDefaultGroupBars = v
                    if GF and GF.UpdateDefaultGroupBarsVisibility then GF.UpdateDefaultGroupBarsVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_UNLOCK),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.locked == false end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.locked = not v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                    if GF and GF.UpdateVisibility then GF.UpdateVisibility() end
                end
            end,
            currentY
        )

        local testChoices = { GetString(SI_NC_LAM_GROUP_TEST_OFF), GetString(SI_NC_LAM_GROUP_TEST_4), GetString(SI_NC_LAM_GROUP_TEST_12), GetString(SI_NC_LAM_GROUP_TEST_24) }
        local testValues  = { 0, 4, 12, 24 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_TEST), testChoices, testValues,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.testCount) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.testCount = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_COLUMNS), 1, 6, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.numColumns) or 2 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.numColumns = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        local sortChoices = { GetString(SI_NC_LAM_GROUP_SORT_BALANCE), GetString(SI_NC_LAM_GROUP_SORT_ROLES), GetString(SI_NC_LAM_GROUP_SORT_NONE) }
        local sortValues  = { 3, 2, 1 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_SORT), sortChoices, sortValues,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.sortMode) or 3 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.sortMode = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        -- Стиль и фактура
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_GROUP_HDR_STYLE), currentY + 6)

        local curGroupStyleId = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.frameStyle) or 1
        local curGroupStyle   = GF and GF.STYLES and GF.STYLES[curGroupStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_STYLE), groupStyleNames, groupStyleIds,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.frameStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.frameStyle = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                    RenderTabContent(12) -- Мгновенно обновляем меню группы!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета группы ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curGroupStyle and curGroupStyle.colorVariants and #curGroupStyle.colorVariants > 1 then
            local colorChoices, colorValues = {}, {}
            for cId, cVar in ipairs(curGroupStyle.colorVariants) do
                table.insert(colorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(colorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_STYLE_COLOR), colorChoices, colorValues,
                function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.styleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.group then
                        NC.savedVars.group.styleColor = v
                        if GF and GF.ApplySettings then GF.ApplySettings() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_TEXTURE), groupTexNames, groupTexIds,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.barTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.barTexture = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        -- Имена и текст
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_GROUP_HDR_NAMES), currentY + 6)

        local nameModeChoices = { GetString(SI_NC_LAM_NAME_USERID), GetString(SI_NC_LAM_NAME_CHAR), GetString(SI_NC_LAM_NAME_BOTH), GetString(SI_NC_LAM_NAME_ID_CHAR) }
        local nameModeValues  = { 1, 2, 3, 4 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_NAME_MODE), nameModeChoices, nameModeValues,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.nameMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.nameMode = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        local textModeChoices = { GetString(SI_NC_LAM_TEXT_SPLIT), GetString(SI_NC_LAM_TEXT_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_CENTER_VAL), GetString(SI_NC_LAM_TEXT_CENTER_PCT), GetString(SI_NC_LAM_TEXT_NONE) }
        local textModeValues  = { 1, 2, 3, 4, 5 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_TEXT_MODE), textModeChoices, textModeValues,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.textMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.textMode = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_SHOW_SHIELD),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.showShieldText ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.showShieldText = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_LEADER_CROWN_SIZE), 14, 44, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.leaderCrownSize) or 24 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.leaderCrownSize = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_LEADER_CROWN_ALPHA), 10, 100, 5,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.leaderCrownAlpha) or 45 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.leaderCrownAlpha = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_LEADER_CROWN_OFFSET_X), -140, 140, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.leaderCrownOffsetX) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.leaderCrownOffsetX = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        -- Размеры и зазоры
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_GROUP_HDR_SIZES), currentY + 6)

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_SCALE), 70, 150, 5,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.frameScale) or 100 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.frameScale = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_WIDTH), 140, 320, 5,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.frameWidth) or 205 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.frameWidth = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_BAR_HEIGHT), 14, 60, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.barHeight) or 29 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.barHeight = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_CLASS_ICON), 12, 40, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.classIconSize) or 20 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.classIconSize = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_SPACING_X), 0, 40, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.spacingX) or 12 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.spacingX = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_SPACING_Y), 0, 30, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.spacingY) or 0 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.spacingY = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_NAME_FONT), 10, 28, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.nameFontSize) or 15 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.nameFontSize = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_GROUP_HP_FONT), 10, 28, 1,
            function() return (NC.savedVars and NC.savedVars.group and NC.savedVars.group.healthFontSize) or 17 end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.healthFontSize = v
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_GROUP_RESET_POS),
            function()
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.groupLeft = 100
                    NC.savedVars.group.groupTop  = 250
                    if GF and GF.rootFrame then
                        GF.rootFrame:ClearAnchors()
                        GF.rootFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 250)
                    end
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY + 2
        )

        -- Тесты
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_GROUP_HDR_SIMS), currentY + 6)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_TEST_SHIELD),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.testShield end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.testShield = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_TEST_TRAUMA),
            function() return NC.savedVars and NC.savedVars.group and NC.savedVars.group.testTrauma end,
            function(v)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.testTrauma = v
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        -- Цвета
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_GROUP_HDR_COLORS), currentY + 6)

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_TANK),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorTank) or { 0.18, 0.45, 0.88, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorTank = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_HEAL),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorHeal) or { 0.92, 0.76, 0.20, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorHeal = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_DPS),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorDamage) or { 0.76, 0.14, 0.14, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorDamage = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_SHIELD),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.shieldColor) or { 0.25, 0.75, 0.95, 0.65 }
                return c[1], c[2], c[3], c[4] or 0.65
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.shieldColor = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_TRAUMA),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.traumaColor) or { 0.65, 0.12, 0.55, 0.80 }
                return c[1], c[2], c[3], c[4] or 0.80
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.traumaColor = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_RESURRECTING),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorResurrect) or { 0.95, 0.80, 0.15, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorResurrect = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_RESPENDING),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorResPending) or { 0.20, 0.85, 0.75, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorResPending = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_GHOST),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.colorGhost) or { 0.40, 0.70, 0.95, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.colorGhost = { r, g, b, a }
                    if GF and GF.UpdateRoster then GF.UpdateRoster() end
                end
            end,
            currentY
        )

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_GROUP_COLOR_TEXT),
            function()
                local c = (NC.savedVars and NC.savedVars.group and NC.savedVars.group.textColor) or { 1.0, 1.0, 1.0, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.group then
                    NC.savedVars.group.textColor = { r, g, b, a }
                    if GF and GF.ApplySettings then GF.ApplySettings() end
                end
            end,
            currentY
        )

    elseif tabId == 13 then
        -- =====================================================
        -- РАЗДЕЛ 13: СПУТНИКИ (КОМПАНЬОНЫ)
        -- =====================================================
        local CF = NecroCat.Companion

        local compStyleNames, compStyleIds = {}, {}
        if CF and CF.STYLES then
            for id, st in ipairs(CF.STYLES) do
                table.insert(compStyleNames, GetString(_G[st.name] or st.name))
                table.insert(compStyleIds, id)
            end
        end

        local compTexNames, compTexIds = {}, {}
        if CF and CF.GetBarTextureChoices then
            compTexNames, compTexIds = CF.GetBarTextureChoices()
        end

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_COMP_ENABLE),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.enabled ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.enabled = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                    if CF and CF.UpdateVisibility then CF.UpdateVisibility() end
                    if CF and CF.HideDefaultCompanionBar then CF.HideDefaultCompanionBar() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_COMP_UNLOCK),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.locked == false end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.locked = not v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                    if CF and CF.UpdateVisibility then CF.UpdateVisibility() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_COMP_TEST),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.testMode end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.testMode = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                    if CF and CF.UpdateVisibility then CF.UpdateVisibility() end
                end
            end,
            currentY
        )

        local scopeChoices = { GetString(SI_NC_LAM_COMP_SCOPE_MINE), GetString(SI_NC_LAM_COMP_SCOPE_ALL) }
        local scopeValues  = { 1, 2 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_COMP_SCOPE), scopeChoices, scopeValues,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.companionScope) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.companionScope = v
                    if CF and CF.Update then CF.Update() end
                end
            end,
            currentY
        )

        local attachChoices = { GetString(SI_NC_LAM_COMP_ATTACH_MODE_SEPARATE), GetString(SI_NC_LAM_COMP_ATTACH_MODE_GROUP) }
        local attachValues  = { 1, 2 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_COMP_ATTACH_MODE), attachChoices, attachValues,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.attachMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.attachMode = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                    if NecroCat.GroupFrames and NecroCat.GroupFrames.UpdateRoster then
                        NecroCat.GroupFrames.UpdateRoster()
                    end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_COMP_SHOW_RAPPORT),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.showRapport ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.showRapport = v
                    if CF and CF.Update then CF.Update() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_COMP_SHOW_PORTRAIT),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.showPortrait ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.showPortrait = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        local compTextChoices = { GetString(SI_NC_LAM_TEXT_SPLIT), GetString(SI_NC_LAM_TEXT_CENTER_BOTH), GetString(SI_NC_LAM_TEXT_CENTER_VAL), GetString(SI_NC_LAM_TEXT_CENTER_PCT), GetString(SI_NC_LAM_TEXT_NONE) }
        local compTextValues  = { 1, 2, 3, 4, 5 }
        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_TEXT_MODE), compTextChoices, compTextValues,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.textMode) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.textMode = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_GROUP_SHOW_SHIELD),
            function() return NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.showShieldText ~= false end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.showShieldText = v
                    if CF and CF.Update then CF.Update() end
                end
            end,
            currentY
        )

        -- Стиль
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_COMP_HDR_STYLE), currentY + 6)

        local curCompStyleId = (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.frameStyle) or 1
        local curCompStyle   = CF and CF.STYLES and CF.STYLES[curCompStyleId]

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_STYLE), compStyleNames, compStyleIds,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.frameStyle) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.frameStyle = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                    RenderTabContent(13) -- Мгновенно обновляем меню спутника!
                end
            end,
            currentY
        )

        -- Показываем выбор цвета спутника ТОЛЬКО если вариантов расцветки БОЛЬШЕ одного:
        if curCompStyle and curCompStyle.colorVariants and #curCompStyle.colorVariants > 1 then
            local compColorChoices, compColorValues = {}, {}
            for cId, cVar in ipairs(curCompStyle.colorVariants) do
                table.insert(compColorChoices, GetString(_G[cVar.name] or cVar.name))
                table.insert(compColorValues, cId)
            end

            currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_STYLE_COLOR), compColorChoices, compColorValues,
                function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.styleColor) or 1 end,
                function(v)
                    if NC.savedVars and NC.savedVars.companion then
                        NC.savedVars.companion.styleColor = v
                        if CF and CF.ApplySettings then CF.ApplySettings() end
                    end
                end,
                currentY
            )
        end

        currentY = CreateDropdown(scrollChild, GetString(SI_NC_LAM_GROUP_TEXTURE), compTexNames, compTexIds,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.barTexture) or 1 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.barTexture = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        -- Размеры
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_COMP_HDR_SIZES), currentY + 6)

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_COMP_WIDTH), 150, 320, 5,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.frameWidth) or 210 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.frameWidth = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_COMP_BAR_HEIGHT), 14, 50, 1,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.barHeight) or 26 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.barHeight = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_COMP_SPACING_Y), 0, 30, 1,
            function() return (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.spacingY) or 4 end,
            function(v)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.spacingY = v
                    if CF and CF.ApplySettings then CF.ApplySettings() end
                end
            end,
            currentY
        )

        -- Цвет
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_COMP_HDR_COLORS), currentY + 6)

        currentY = CreateColorpicker(scrollChild, GetString(SI_NC_LAM_COMP_COLOR_HEALTH),
            function()
                local c = (NC.savedVars and NC.savedVars.companion and NC.savedVars.companion.healthColor) or { 0.16, 0.62, 0.45, 1.0 }
                return c[1], c[2], c[3], c[4] or 1
            end,
            function(r, g, b, a)
                if NC.savedVars and NC.savedVars.companion then
                    NC.savedVars.companion.healthColor = { r, g, b, a }
                    if CF and CF.Update then CF.Update() end
                end
            end,
            currentY
        )

    elseif tabId == 14 then
        -- =====================================================
        -- РАЗДЕЛ 14: МИНИКАРТА
        -- =====================================================
        local mm = NecroCat.Minimap

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_ENABLE),
            function() return mm and mm.settings and mm.settings.enabled end,
            function(val)
                if mm and mm.settings then
                    mm.settings.enabled = val
                    if val then
                        if mm.StartEngine then mm.StartEngine() end
                    else
                        EVENT_MANAGER:UnregisterForUpdate("NecroCat_Minimap_Update")
                        if NecroCat_Minimap_MainWindow then NecroCat_Minimap_MainWindow:SetHidden(true) end
                    end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_LOCK),
            function() return mm and mm.settings and mm.settings.locked end,
            function(val)
                if mm and mm.settings then mm.settings.locked = val end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_PREVIEW),
            function() return mm and mm.settings and mm.settings.previewInMenu end,
            function(val)
                if mm and mm.settings then
                    mm.settings.previewInMenu = val
                    if NecroCat_Minimap_MainWindow then
                        NecroCat_Minimap_MainWindow:SetHidden(not val)
                    end
                    if val and mm.ApplyLayout and mm.RefreshMap then
                        mm.ApplyLayout()
                        mm.RefreshMap()
                    end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_ROTATE),
            function() return mm and mm.settings and mm.settings.rotate end,
            function(val)
                if mm and mm.settings then
                    mm.settings.rotate = val
                    if mm.RefreshMap then mm.RefreshMap() end
                end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_HIDE_ANNOUNCE),
            function() return mm and mm.settings and mm.settings.hideZoneAnnounce end,
            function(val)
                if mm and mm.settings then mm.settings.hideZoneAnnounce = val end
            end,
            currentY
        )

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_MAP_LOOT_ON_TOP),
            function() return mm and mm.settings and (mm.settings.lootOnTop ~= false) end,
            function(val)
                if mm and mm.settings then
                    mm.settings.lootOnTop = val
                    if mm.ApplyLayout then mm.ApplyLayout() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_MAP_PLAYER_PIN_SIZE), 16, 48, 2,
            function() return (mm and mm.settings and mm.settings.playerPinSize) or 32 end,
            function(val)
                if mm and mm.settings then
                    mm.settings.playerPinSize = val
                    if NecroCat_Minimap_MainWindow_Map_PlayerPin then
                        NecroCat_Minimap_MainWindow_Map_PlayerPin:SetDimensions(val, val)
                    end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_MAP_PIN_SIZE), 14, 36, 2,
            function() return (mm and mm.settings and mm.settings.pinSize) or 20 end,
            function(val)
                if mm and mm.settings then
                    mm.settings.pinSize = val
                    if mm.RefreshMap then mm.RefreshMap() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_MAP_WIDTH), 150, 500, 10,
            function() return (mm and mm.settings and mm.settings.width) or 250 end,
            function(val)
                if mm and mm.settings then
                    mm.settings.width = val
                    if mm.ApplyLayout then mm.ApplyLayout() end
                    if mm.RefreshMap then mm.RefreshMap() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_MAP_HEIGHT), 150, 500, 10,
            function() return (mm and mm.settings and mm.settings.height) or 250 end,
            function(val)
                if mm and mm.settings then
                    mm.settings.height = val
                    if mm.ApplyLayout then mm.ApplyLayout() end
                    if mm.RefreshMap then mm.RefreshMap() end
                end
            end,
            currentY
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_MAP_OPACITY), 20, 100, 5,
            function() return (mm and mm.settings and zo_round((mm.settings.opacity or 1.0) * 100)) or 100 end,
            function(val)
                if mm and mm.settings then
                    mm.settings.opacity = val / 100
                    if NecroCat_Minimap_MainWindow then
                        NecroCat_Minimap_MainWindow:SetAlpha(mm.settings.opacity)
                    end
                end
            end,
            currentY
        )

    elseif tabId == 15 then
        -- =====================================================
        -- РАЗДЕЛ 15: УМНАЯ КАМЕРА (МИР И БОЙ)
        -- =====================================================
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_CAM_HDR_GENERAL), currentY)

        currentY = CreateCheckbox(scrollChild, GetString(SI_NC_LAM_CAM_ENABLE),
            function() return NC.savedVars and NC.savedVars.cameraSwitcherEnabled end,
            function(v) 
                if NC.savedVars then 
                    NC.savedVars.cameraSwitcherEnabled = v 
                    if NC.OnCameraCombatStateChanged then
                        NC.OnCameraCombatStateChanged(IsUnitInCombat("player"))
                    end
                end
            end,
            currentY
        )

        -- -----------------------------------------------------
        -- 1. МИРНЫЙ РЕЖИМ (ВНЕ БОЯ)
        -- -----------------------------------------------------
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_CAM_HDR_OUT_COMBAT), currentY + 6)

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CAM_CAPTURE_OUT),
            function()
                if NC.CaptureCameraPreset then
                    NC.CaptureCameraPreset("cameraOutCombat")
                    RenderTabContent(15) -- обновляем цифры на слайдерах!
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CAM_TEST_OUT),
            function()
                if NC.ApplyCameraPreset then
                    NC.ApplyCameraPreset("cameraOutCombat", true)
                end
            end,
            currentY + 2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_FOV), 35.0, 65.0, 0.5,
            function() return (NC.savedVars and NC.savedVars.cameraOutCombat and NC.savedVars.cameraOutCombat.fov) or 50.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraOutCombat then
                    NC.savedVars.cameraOutCombat.fov = v
                    SetSetting(2, 12, string.format("%.6f", v))
                end
            end,
            currentY,
            1
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_HORIZ_POS), -1.0, 1.0, 0.05,
            function() return (NC.savedVars and NC.savedVars.cameraOutCombat and NC.savedVars.cameraOutCombat.horizPos) or 0.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraOutCombat then
                    NC.savedVars.cameraOutCombat.horizPos = v
                    SetSetting(2, 9, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_HORIZ_OFFSET), -2.0, 2.0, 0.05,
            function() return (NC.savedVars and NC.savedVars.cameraOutCombat and NC.savedVars.cameraOutCombat.horizOffset) or 0.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraOutCombat then
                    NC.savedVars.cameraOutCombat.horizOffset = v
                    SetSetting(2, 10, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_VERT_OFFSET), -1.0, 1.0, 0.02,
            function() return (NC.savedVars and NC.savedVars.cameraOutCombat and NC.savedVars.cameraOutCombat.vertOffset) or 0.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraOutCombat then
                    NC.savedVars.cameraOutCombat.vertOffset = v
                    SetSetting(2, 11, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

        -- -----------------------------------------------------
        -- 2. БОЕВОЙ РЕЖИМ (В БОЮ)
        -- -----------------------------------------------------
        currentY = CreateHeader(scrollChild, GetString(SI_NC_LAM_CAM_HDR_IN_COMBAT), currentY + 6)

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CAM_CAPTURE_IN),
            function()
                if NC.CaptureCameraPreset then
                    NC.CaptureCameraPreset("cameraInCombat")
                    RenderTabContent(15) -- обновляем цифры на слайдерах!
                end
            end,
            currentY
        )

        currentY = CreateButton(scrollChild, GetString(SI_NC_LAM_CAM_TEST_IN),
            function()
                if NC.ApplyCameraPreset then
                    NC.ApplyCameraPreset("cameraInCombat", true)
                end
            end,
            currentY + 2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_FOV), 35.0, 65.0, 0.5,
            function() return (NC.savedVars and NC.savedVars.cameraInCombat and NC.savedVars.cameraInCombat.fov) or 55.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraInCombat then
                    NC.savedVars.cameraInCombat.fov = v
                    SetSetting(2, 12, string.format("%.6f", v))
                end
            end,
            currentY,
            1
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_HORIZ_POS), -1.0, 1.0, 0.05,
            function() return (NC.savedVars and NC.savedVars.cameraInCombat and NC.savedVars.cameraInCombat.horizPos) or 0.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraInCombat then
                    NC.savedVars.cameraInCombat.horizPos = v
                    SetSetting(2, 9, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_HORIZ_OFFSET), -2.0, 2.0, 0.05,
            function() return (NC.savedVars and NC.savedVars.cameraInCombat and NC.savedVars.cameraInCombat.horizOffset) or 0.0 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraInCombat then
                    NC.savedVars.cameraInCombat.horizOffset = v
                    SetSetting(2, 10, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

        currentY = CreateSlider(scrollChild, GetString(SI_NC_LAM_CAM_VERT_OFFSET), -1.0, 1.0, 0.02,
            function() return (NC.savedVars and NC.savedVars.cameraInCombat and NC.savedVars.cameraInCombat.vertOffset) or -0.12 end,
            function(v)
                if NC.savedVars and NC.savedVars.cameraInCombat then
                    NC.savedVars.cameraInCombat.vertOffset = v
                    SetSetting(2, 11, string.format("%.6f", v))
                end
            end,
            currentY,
            2
        )

    else
        local placeholder = _G["NecroCat_PlaceholderLbl"] or wm:CreateControl("NecroCat_PlaceholderLbl", scrollChild, CT_LABEL)
        placeholder:ClearAnchors()
        placeholder:SetFont("ZoFontWinH4")
        placeholder:SetColor(0.65, 0.65, 0.65, 1.0)
        placeholder:SetText(GetString(SI_NC_SETTINGS_COMING_SOON))
        placeholder:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 10, currentY)
        placeholder:SetHidden(false)
        table.insert(createdControls, placeholder)
        currentY = currentY + 40
    end

    scrollChild:SetHeight(currentY + 40)
    if SettingsUI.ScrollContainer and ZO_Scroll_UpdateScrollBar then
        ZO_Scroll_UpdateScrollBar(SettingsUI.ScrollContainer)
    end
end

-- =========================================================
-- НАПРАВЛЯЮЩИЕ ОСИ ЭКРАНА (ЦЕНТРОВКА)
-- =========================================================
local guidesWindow = nil

local function CreateGuidesWindow()
    if guidesWindow then return guidesWindow end

    local win = wm:CreateTopLevelWindow("NecroCat_ScreenGuides")
    win:SetAnchorFill(GuiRoot)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(false) -- Мышь проходит насквозь!
    win:SetMovable(false)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawLevel(5)
    win:SetHidden(true)

    -- Вертикальная линия (ровно по центру экрана)
    local vLine = wm:CreateControl("$(parent)_VLine", win, CT_BACKDROP)
    vLine:SetDimensions(2, GuiRoot:GetHeight())
    vLine:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    vLine:SetCenterColor(0.0, 0.85, 1.0, 0.65)
    vLine:SetEdgeColor(0, 0, 0, 0)

    -- Горизонтальная линия (ровно по центру экрана)
    local hLine = wm:CreateControl("$(parent)_HLine", win, CT_BACKDROP)
    hLine:SetDimensions(GuiRoot:GetWidth(), 2)
    hLine:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    hLine:SetCenterColor(0.0, 0.85, 1.0, 0.65)
    hLine:SetEdgeColor(0, 0, 0, 0)

    -- Маленькая точка-перекрестие в самом центре
    local dot = wm:CreateControl("$(parent)_Dot", win, CT_BACKDROP)
    dot:SetDimensions(8, 8)
    dot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    dot:SetCenterColor(1.0, 0.85, 0.2, 0.9)
    dot:SetEdgeColor(0, 0, 0, 0.5)

    guidesWindow = win
    return win
end

function SettingsUI.ToggleGuides()
    local win = guidesWindow or CreateGuidesWindow()
    local isHidden = win:IsHidden()
    win:SetHidden(not isHidden)

    -- Обновляем подсветку кнопки в шапке (если она создана)
    if SettingsUI.GuidesBtn then
        if not win:IsHidden() then
            SettingsUI.GuidesBtn:SetNormalFontColor(0.0, 0.85, 1.0, 1.0)
            SettingsUI.GuidesBtn:SetText(GetString(SI_NC_GUIDES_ON))
        else
            SettingsUI.GuidesBtn:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
            SettingsUI.GuidesBtn:SetText(GetString(SI_NC_GUIDES_OFF))
        end
    end
end

SLASH_COMMANDS["/ncgrid"]  = function() SettingsUI.ToggleGuides() end
SLASH_COMMANDS["/ncguide"] = function() SettingsUI.ToggleGuides() end

-- =========================================================
-- УМНЫЙ МАСТЕР-ОВЕРЛЕЙ И ГЛОБАЛЬНЫЙ СБРОС ВСЕХ ПОЗИЦИЙ
-- =========================================================
SettingsUI.isMasterOverlayActive = false
SettingsUI.overlaySavedLocks = nil

function SettingsUI.ToggleMasterOverlay()
    local sv = NC.savedVars
    if not sv then return end

    SettingsUI.isMasterOverlayActive = not SettingsUI.isMasterOverlayActive
    local active = SettingsUI.isMasterOverlayActive

    if active then
        -- 1. ДЕЛАЕМ СНИМОК СОСТОЯНИЙ ДО ВКЛЮЧЕНИЯ (УМНАЯ ПАМЯТЬ)
        SettingsUI.overlaySavedLocks = {
            -- Обычные виджеты
            speedometer      = sv.speedometerUnlocked,
            veterancy        = sv.veterancyUnlocked,
            foodPreview      = sv.foodReminderPreview,
            foodUnlocked     = sv.foodReminderUnlocked,
            planarKeys       = sv.planarKeyWidgetUnlocked,
            currency         = sv.currencyTrackerUnlocked,
            longBuffs        = sv.longBuffsUnlocked,
            shortBuffs       = sv.shortBuffsUnlocked,
            playerDebuffs    = sv.playerDebuffsUnlocked,
            targetDebuffs    = sv.targetDebuffsUnlocked,
            speedrunHud      = sv.speedrunHudUnlocked,
            whisperLocked    = sv.whisperLocked,
            friendLocked     = sv.friendNotificationLocked,

            -- Большие боевые фреймы (Frames, Group, Companion)
            playerLocked     = sv.frames and sv.frames.playerLocked,
            targetLocked     = sv.frames and sv.frames.targetLocked,
            bossLocked       = sv.frames and sv.frames.bossLocked,
            testSiege        = sv.frames and sv.frames.testSiege,
            groupLocked      = sv.group and sv.group.locked,
            groupTestCount   = sv.group and sv.group.testCount,
            compLocked       = sv.companion and sv.companion.locked,
            compTestMode     = sv.companion and sv.companion.testMode,
        }

        -- 2. РАЗБЛОКИРУЕМ И ПОКАЗЫВАЕМ ВСЁ ВКЛЮЧЕННОЕ
        if sv.speedometerEnabled then sv.speedometerUnlocked = true end
        if sv.veterancyEnabled then sv.veterancyUnlocked = true end
        if sv.foodReminderEnabled then
            sv.foodReminderPreview = true
            sv.foodReminderUnlocked = true
        end
        if sv.planarKeyWidgetEnabled then sv.planarKeyWidgetUnlocked = true end
        if sv.currencyTrackerEnabled then sv.currencyTrackerUnlocked = true end
        if sv.longBuffsEnabled then sv.longBuffsUnlocked = true end
        if sv.shortBuffsEnabled then sv.shortBuffsUnlocked = true end
        if sv.playerDebuffsEnabled then sv.playerDebuffsUnlocked = true end
        if sv.targetDebuffsEnabled then sv.targetDebuffsUnlocked = true end
        if sv.speedrunHudEnabled then sv.speedrunHudUnlocked = true end
        if sv.whisperAlert then sv.whisperLocked = false end
        sv.friendNotificationLocked = false

        -- Разблокируем большие боевые фреймы (только если они включены!)
        if sv.frames then
            if sv.frames.playerEnabled ~= false then sv.frames.playerLocked = false end
            if sv.frames.targetEnabled ~= false then sv.frames.targetLocked = false end
            if sv.frames.bossEnabled ~= false then sv.frames.bossLocked = false end
            if sv.frames.siegeEnabled ~= false then sv.frames.testSiege = true end
        end

        if sv.group and sv.group.enabled ~= false then
            sv.group.locked = false
            -- Если не в реальной группе — включаем тестовую сетку рейда
            if not IsUnitGrouped("player") and (not sv.group.testCount or sv.group.testCount == 0) then
                sv.group.testCount = 4
            end
        end

        if sv.companion and sv.companion.enabled ~= false then
            sv.companion.locked = false
            sv.companion.testMode = true
        end
    else
        -- 3. ВОЗВРАЩАЕМ ТОЛЬКО ТО, ЧТО БЫЛО ЗАБЛОКИРОВАНО (УМНАЯ ПАМЯТЬ)
        if SettingsUI.overlaySavedLocks then
            local s = SettingsUI.overlaySavedLocks
            sv.speedometerUnlocked      = s.speedometer
            sv.veterancyUnlocked        = s.veterancy
            sv.foodReminderPreview      = s.foodPreview
            sv.foodReminderUnlocked     = s.foodUnlocked
            sv.planarKeyWidgetUnlocked  = s.planarKeys
            sv.currencyTrackerUnlocked  = s.currency
            sv.longBuffsUnlocked        = s.longBuffs
            sv.shortBuffsUnlocked       = s.shortBuffs
            sv.playerDebuffsUnlocked    = s.playerDebuffs
            sv.targetDebuffsUnlocked    = s.targetDebuffs
            sv.speedrunHudUnlocked      = s.speedrunHud
            sv.whisperLocked            = s.whisperLocked
            sv.friendNotificationLocked = s.friendLocked

            if sv.frames then
                sv.frames.playerLocked  = s.playerLocked
                sv.frames.targetLocked  = s.targetLocked
                sv.frames.bossLocked    = s.bossLocked
                sv.frames.testSiege     = s.testSiege
            end

            if sv.group then
                sv.group.locked         = s.groupLocked
                sv.group.testCount      = s.groupTestCount
            end

            if sv.companion then
                sv.companion.locked     = s.compLocked
                sv.companion.testMode   = s.compTestMode
            end

            SettingsUI.overlaySavedLocks = nil
        end
    end

    -- Обновляем обычные виджеты ядра
    if NC.UpdateSpeedometerUI then NC.UpdateSpeedometerUI() end
    if NC.UpdateVeterancyUI then NC.UpdateVeterancyUI() end
    if NC.UpdateFoodReminderUI then NC.UpdateFoodReminderUI() end
    if NC.UpdatePlanarKeyWidgetUI then NC.UpdatePlanarKeyWidgetUI() end
    if NC.UpdateCurrencyTrackerUI then NC.UpdateCurrencyTrackerUI() end
    if NC.UpdateLongBuffsUI then NC.UpdateLongBuffsUI() end
    if NC.UpdateShortBuffsUI then NC.UpdateShortBuffsUI() end
    if NC.UpdatePlayerDebuffsUI then NC.UpdatePlayerDebuffsUI() end
    if NC.UpdateTargetDebuffsUI then NC.UpdateTargetDebuffsUI() end
    if NC.UpdateSpeedrunHudUI then NC.UpdateSpeedrunHudUI() end
    if NC.UpdateWhisperUI then NC.UpdateWhisperUI() end
    if NC.UpdateFriendUI then NC.UpdateFriendUI() end

    -- Показываем одиночные иконки
    if NC.ChestCounterFrame then
        if active then
            if sv.showChestCounter then
                NC.ChestCounterFrame:SetHidden(false)
                NC.ChestCounterFrame:BringWindowToTop()
            end
        else
            NC.ChestCounterFrame:SetHidden(not sv.showChestCounter)
        end
    end

    if NC.RecipeFrame then
        if active then
            if sv.showRecipeButton then
                NC.RecipeFrame:SetHidden(false)
                NC.RecipeFrame:BringWindowToTop()
            end
        else
            NC.RecipeFrame:SetHidden(true)
        end
    end

    if NC.SetToastFrame then
        if active then
            if sv.showAutoBindToast then
                NC.SetToastFrame:SetHidden(false)
                NC.SetToastFrame:BringWindowToTop()
            end
        else
            NC.SetToastFrame:SetHidden(true)
        end
    end

    -- Обновляем большие боевые фреймы (Frames, Group, Companion)
    local Frames = NecroCat.Frames
    if Frames then
        if Frames.ApplyLayout then Frames.ApplyLayout() end
        if Frames.UpdateVisibility then Frames.UpdateVisibility() end
        if Frames.UpdateSiegeBar then Frames.UpdateSiegeBar() end
        if Frames.ApplyTargetLayout then Frames.ApplyTargetLayout() end
        if Frames.ApplyBossLayout then Frames.ApplyBossLayout() end
    end

    local GF = NecroCat.GroupFrames
    if GF then
        if GF.ApplySettings then GF.ApplySettings() end
        if GF.UpdateRoster then GF.UpdateRoster() end
        if GF.UpdateVisibility then GF.UpdateVisibility() end
    end

    local CF = NecroCat.Companion
    if CF then
        if CF.ApplySettings then CF.ApplySettings() end
        if CF.UpdateVisibility then CF.UpdateVisibility() end
        if CF.Update then CF.Update() end
    end

    -- Обновляем текст кнопки в шапке
    if SettingsUI.OverlayBtn then
        if active then
            SettingsUI.OverlayBtn:SetNormalFontColor(0.0, 0.85, 1.0, 1.0)
            SettingsUI.OverlayBtn:SetText(GetString(SI_NC_OVERLAY_ON))
        else
            SettingsUI.OverlayBtn:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
            SettingsUI.OverlayBtn:SetText(GetString(SI_NC_OVERLAY_OFF))
        end
    end

    -- Синхронизируем галочки в меню
    if SettingsUI.currentTabId and RenderTabContent then
        RenderTabContent(SettingsUI.currentTabId)
    end
end

-- Вспомогательная функция центрирования одного фрейма с сохранением
local function CenterFrameAndSave(frame, leftKey, topKey)
    if frame and NC.savedVars then
        frame:ClearAnchors()
        frame:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        NC.savedVars[leftKey] = frame:GetLeft()
        NC.savedVars[topKey]  = frame:GetTop()
    end
end

-- Сброс всех 15 виджетов ровно в центр экрана
function SettingsUI.ResetAllPositionsToCenter()
    CenterFrameAndSave(NC.SpeedometerFrame, "speedometerLeft", "speedometerTop")
    CenterFrameAndSave(NC.VeterancyFrame, "veterancyLeft", "veterancyTop")
    CenterFrameAndSave(NC.RecipeFrame, "recipeButtonLeft", "recipeButtonTop")
    CenterFrameAndSave(NC.SetToastFrame, "setToastLeft", "setToastTop")
    CenterFrameAndSave(NC.ChestCounterFrame, "chestLeft", "chestTop")
    CenterFrameAndSave(NC.PlanarKeyWidgetFrame, "planarKeyWidgetLeft", "planarKeyWidgetTop")
    CenterFrameAndSave(NC.CurrencyTrackerFrame, "currencyTrackerLeft", "currencyTrackerTop")
    CenterFrameAndSave(NC.FoodReminderFrame, "foodReminderLeft", "foodReminderTop")
    CenterFrameAndSave(NC.LongBuffsFrame, "longBuffsLeft", "longBuffsTop")
    CenterFrameAndSave(NC.ShortBuffsFrame, "shortBuffsLeft", "shortBuffsTop")
    CenterFrameAndSave(NC.PlayerDebuffsFrame, "playerDebuffsLeft", "playerDebuffsTop")
    CenterFrameAndSave(NC.TargetDebuffsFrame, "targetDebuffsLeft", "targetDebuffsTop")
    CenterFrameAndSave(NC.SpeedrunFrame, "speedrunHudLeft", "speedrunHudTop")
    CenterFrameAndSave(NC.WhisperFrame, "whisperLeft", "whisperTop")
    CenterFrameAndSave(NC.FriendNotificationFrame, "friendNotificationLeft", "friendNotificationTop")

    d(GetString(SI_NC_RESET_ALL_DONE))
end

-- Диалог подтверждения ESO перед глобальным сбросом
function SettingsUI.ShowResetAllConfirmationDialog()
    ESO_Dialogs["NECROCAT_CONFIRM_RESET_ALL"] = {
        title = { text = GetString(SI_NC_CONFIRM_RESET_ALL_TITLE) },
        mainText = { text = GetString(SI_NC_CONFIRM_RESET_ALL_TEXT) },
        buttons = {
            {
                text = SI_DIALOG_YES,
                callback = function()
                    SettingsUI.ResetAllPositionsToCenter()
                end,
            },
            {
                text = SI_DIALOG_NO,
            },
        },
    }
    ZO_Dialogs_ShowPlatformDialog("NECROCAT_CONFIRM_RESET_ALL")
end

local function CreateSettingsWindow()
    if SettingsUI.Window then return SettingsUI.Window end

    -- 1. Главное окно
    local window = wm:CreateTopLevelWindow("NecroCat_SettingsWindow")
    window:SetDimensions(880, 720)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetClampedToScreen(true)
    window:SetDrawTier(DT_HIGH) -- Выводим окно на передний план перед всеми виджетами!
    window:SetHidden(true)

    -- Авто-включение и выключение курсора мыши + подъем окна на самый верх
    window:SetHandler("OnShow", function(self)
        SCENE_MANAGER:SetInUIMode(true)
        self:BringWindowToTop()
    end)
    window:SetHandler("OnHide", function()
        SCENE_MANAGER:SetInUIMode(false)
    end)

    -- 2. Фон
    wm:CreateControlFromVirtual("$(parent)_BG", window, "ZO_DefaultBackdrop")

    -- 3. Заголовок
    local title = wm:CreateControl("$(parent)_Title", window, CT_LABEL)
    title:SetAnchor(TOPLEFT, window, TOPLEFT, 24, 18)
    title:SetFont("ZoFontWinH1")
    title:SetText("CASTLE OF NECRO CAT")
    title:SetColor(0.0, 0.85, 1.0, 1.0)

    -- 4. Подзаголовок (локализованный)
    local subtitle = wm:CreateControl("$(parent)_SubTitle", window, CT_LABEL)
    subtitle:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
    subtitle:SetFont("ZoFontGameSmall")
    subtitle:SetText(GetString(SI_NC_SETTINGS_SUBTITLE))
    subtitle:SetColor(0.7, 0.7, 0.7, 1.0)

    -- 5. Кнопка крестика
    local closeBtn = wm:CreateControlFromVirtual("$(parent)_Close", window, "ZO_CloseButton")
    closeBtn:SetAnchor(TOPRIGHT, window, TOPRIGHT, -12, 14)
    closeBtn:SetHandler("OnClicked", function()
        window:SetHidden(true)
    end)

    -- Кнопка включения направляющих осей экрана
    local guidesBtn = wm:CreateControlFromVirtual("$(parent)_GuidesBtn", window, "ZO_DefaultButton")
    guidesBtn:SetDimensions(120, 26)
    guidesBtn:SetAnchor(RIGHT, closeBtn, LEFT, -10, 0)
    guidesBtn:SetText(GetString(SI_NC_GUIDES_OFF))
    guidesBtn:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
    guidesBtn:SetHandler("OnClicked", function()
        SettingsUI.ToggleGuides()
    end)
    SettingsUI.GuidesBtn = guidesBtn

    -- Кнопка умного мастер-оверлея (все включенные виджеты)
    local overlayBtn = wm:CreateControlFromVirtual("$(parent)_OverlayBtn", window, "ZO_DefaultButton")
    overlayBtn:SetDimensions(135, 26)
    overlayBtn:SetAnchor(RIGHT, guidesBtn, LEFT, -8, 0)
    overlayBtn:SetText(GetString(SI_NC_OVERLAY_OFF))
    overlayBtn:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
    overlayBtn:SetHandler("OnClicked", function()
        SettingsUI.ToggleMasterOverlay()
    end)
    SettingsUI.OverlayBtn = overlayBtn

    -- Кнопка глобального сброса всех панелей в центр с подтверждением
    local resetAllBtn = wm:CreateControlFromVirtual("$(parent)_ResetAllBtn", window, "ZO_DefaultButton")
    resetAllBtn:SetDimensions(125, 26)
    resetAllBtn:SetAnchor(RIGHT, overlayBtn, LEFT, -8, 0)
    resetAllBtn:SetText("|cFF5555" .. GetString(SI_NC_RESET_ALL_BTN) .. "|r")
    resetAllBtn:SetHandler("OnClicked", function()
        SettingsUI.ShowResetAllConfirmationDialog()
    end)
    SettingsUI.ResetAllBtn = resetAllBtn

    -- 6. Разделитель
    local divider = wm:CreateControl("$(parent)_Divider", window, CT_BACKDROP)
    divider:SetDimensions(2, 615)
    divider:SetAnchor(TOPLEFT, window, TOPLEFT, 242, 80)
    divider:SetCenterColor(0.35, 0.30, 0.18, 0.65)
    divider:SetEdgeColor(0, 0, 0, 0)

    -- 7. Вкладки слева (локализованные)
    local startY = 86
    local btnHeight = 33
    local spacingY = 4

    for index, tabData in ipairs(TABS) do
        local btn = wm:CreateControl("$(parent)_TabBtn" .. tabData.id, window, CT_BUTTON)
        btn:SetDimensions(222, btnHeight)
        btn:SetAnchor(TOPLEFT, window, TOPLEFT, 16, startY + ((index - 1) * (btnHeight + spacingY)))
        btn:SetFont("ZoFontWinH5")
        btn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        btn:SetText("  " .. GetTabName(tabData))

        local btnBg = wm:CreateControl("$(parent)_BG", btn, CT_BACKDROP)
        btnBg:SetAnchorFill()
        btnBg:SetCenterColor(0.0, 0.85, 1.0, 0.12)
        btnBg:SetEdgeColor(0.0, 0.85, 1.0, 0.7)
        btnBg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 8, 8)
        btnBg:SetHidden(true)
        btn.bg = btnBg

        btn:SetHandler("OnMouseEnter", function(self)
            if SettingsUI.currentTabId ~= tabData.id then
                self:SetNormalFontColor(1.0, 1.0, 1.0, 1.0)
            end
        end)
        btn:SetHandler("OnMouseExit", function(self)
            if SettingsUI.currentTabId ~= tabData.id then
                self:SetNormalFontColor(0.75, 0.75, 0.75, 1.0)
            end
        end)
        btn:SetHandler("OnClicked", function()
            SelectTab(tabData.id)
        end)

        SettingsUI.tabButtons[tabData.id] = btn
    end

    -- 8. Заголовок раздела справа
    local rightHeader = wm:CreateControl("$(parent)_RightHeader", window, CT_LABEL)
    rightHeader:SetAnchor(TOPLEFT, window, TOPLEFT, 260, 86)
    rightHeader:SetFont("ZoFontWinH2")
    rightHeader:SetColor(0.0, 0.85, 1.0, 1.0)
    SettingsUI.RightHeader = rightHeader

    -- 9. Скролл-контейнер справа для настроек
    local scrollContainer = CreateControlFromVirtual("$(parent)_Scroll", window, "ZO_ScrollContainer")
    scrollContainer:SetAnchor(TOPLEFT, window, TOPLEFT, 260, 126)
    scrollContainer:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -15, -20)

    local scrollChild = scrollContainer:GetNamedChild("ScrollChild")
    scrollChild:SetWidth(580)
    SettingsUI.ScrollChild = scrollChild
    SettingsUI.ScrollContainer = scrollContainer

    SettingsUI.Window = window

    SelectTab(1)
    return window
end

function SettingsUI.Toggle()
    local win = SettingsUI.Window or CreateSettingsWindow()
    win:SetHidden(not win:IsHidden())
end

SLASH_COMMANDS["/necrocatset"] = function()
    SettingsUI.Toggle()
end

-- Перехват клавиши Esc для мягкого закрытия окна
if ZO_GameMenu_InGame then
    ZO_PreHook(ZO_GameMenu_InGame, "SetHidden", function(self, hidden)
        if not hidden and SettingsUI.Window and not SettingsUI.Window:IsHidden() then
            SettingsUI.Window:SetHidden(true)
            return true -- Глушит меню паузы игры!
        end
    end)
end