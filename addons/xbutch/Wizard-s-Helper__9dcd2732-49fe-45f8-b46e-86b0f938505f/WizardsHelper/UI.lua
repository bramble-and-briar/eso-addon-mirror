local WH = WizardsHelper
local SCENE_NAME = "WizardsHelperScene"
local COPY_DIALOG = "WizardsHelperCrossClassCopy"
local ROW_HEIGHT, ROW_SPACING = 58, 4

function WH:UpdateListLayout(selectedIndex)
    local list = self.ui and self.ui.list
    if not list then return end
    local height, count = list.control:GetHeight(), #list.dataList
    if height > 0 and count > 0 then
        selectedIndex = selectedIndex or list.targetSelectedIndex or list.selectedIndex or 1
        local stride = ROW_HEIGHT + ROW_SPACING
        local selectedTop = (selectedIndex - 1) * stride
        if count * stride - ROW_SPACING > height then
            selectedTop = math.min(selectedTop, math.max(0, (height - ROW_HEIGHT) / 2))
            selectedTop = math.max(selectedTop, height - ((count - selectedIndex) * stride + ROW_HEIGHT))
        end
        selectedTop = math.max(0, math.min(selectedTop, height - ROW_HEIGHT))
        local offset = -height / 2 + selectedTop
        if list.selectedIndex or list.targetSelectedIndex then list:SetFixedCenterOffset(offset)
        else list.fixedCenterOffset = offset; list.validGradientDirty = true end
    end
    list.scrollControl:SetFadeGradient(1, 0, 0, 0)
    list.scrollControl:SetFadeGradient(2, 0, 0, 0)
end

function WH:UpdateKeybinds()
    if self.ui and self.ui.active then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.ui.keybinds) end
end

function WH:CreateUI()
    local window = WizardsHelperGamepad
    local ui = { window = window, status = window:GetNamedChild("Status"), description = window:GetNamedChild("Description"),
        path = window:GetNamedChild("Path"), level = "sources", sources = {}, selections = {} }
    self.ui = ui
    local list = ZO_GamepadVerticalParametricScrollList:New(window:GetNamedChild("List"))
    ui.list = list
    list:SetUniversalPostPadding(ROW_SPACING)
    list:SetSelectedItemOffsets(0, 0)
    list:SetAlignToScreenCenter(false)
    list:SetHandleDynamicViewProperties(false)
    list.control:SetHandler("OnRectChanged", function() self:UpdateListLayout() end)
    list:AddDataTemplate("WizardsHelperGamepadRow", function(control, data, selected)
        local label = control:GetNamedChild("Text")
        label:SetText(data.text)
        label:SetFont(data.header and "ZoFontGamepadBold27" or "ZoFontGamepad27")
        control:GetNamedChild("Highlight"):SetHidden(data.header or not selected)
    end)
    list:SetOnTargetDataChangedCallback(function(_, data, _, _, selectedIndex)
        self:UpdateListLayout(selectedIndex)
        if data and data.key and ui.viewKey then ui.selections[ui.viewKey] = data.key end
        ui.description:SetText(data and data.description or "Choose a character to browse its saved WW builds.")
        self:UpdateKeybinds()
    end)
    ui.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        { keybind = "UI_SHORTCUT_PRIMARY", name = function()
            local data = list:GetTargetData(); return data and data.actionName or "Select"
        end, enabled = function()
            local data = list:GetTargetData(); return not self.job and data ~= nil and data.enabled ~= false and data.canSelect ~= false
        end, callback = function()
            local data = list:GetTargetData()
            if not self.job and data and data.enabled ~= false and data.activate then data.activate() end
        end },
        { keybind = "UI_SHORTCUT_NEGATIVE", name = function()
            return self.job and "Cancel" or ui.level == "sources" and "Close" or "Back"
        end, callback = function() self:Back() end },
        { keybind = "UI_SHORTCUT_SECONDARY", name = "Refresh", enabled = function() return not self.job end,
            callback = function() self:RefreshSources() end },
        { keybind = "UI_SHORTCUT_TERTIARY", name = function()
            return self.lastCopy and self.lastCopy.characterId == tostring(GetCurrentCharacterId()) and "Open copy in WW" or "Copy details"
        end, visible = function() return self.lastCopy ~= nil end, enabled = function() return not self.job end,
            callback = function() if not self.job then self:OpenLastCopy() end end },
    }
    ZO_Dialogs_RegisterCustomDialog(COPY_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC }, title = { text = "Copy between different classes?" },
        mainText = { text = function(dialog)
            local data = dialog.data
            return string.format("%s (%s) -> %s (%s)\n\n%s\n\nEquipment, CP, food and all saved build data will be copied unchanged. WW will report unavailable class skills when equipping the copy.",
                data.request.page.sourceName, data.request.page.className, data.destination.name, data.destination.className, data.request.label)
        end },
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = SI_DIALOG_CONFIRM, callback = function(dialog)
                ui.confirmingCopy = false; self:ExecuteCopy(dialog.data.request, dialog.data.destination)
            end },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL, callback = function() ui.confirmingCopy = false; self:SetStatus("Copy cancelled.") end },
        },
    })
    ui.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    ui.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    ui.scene:AddFragment(ZO_FadeSceneFragment:New(window))
    ui.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            ui.active = true
            KEYBIND_STRIP:AddKeybindButtonGroup(ui.keybinds)
            if ui.request or self.job then self:SetBusy(self.job ~= nil) else self:RefreshSources() end
        elseif newState == SCENE_HIDING then
            ui.active = false; list:Deactivate(); KEYBIND_STRIP:RemoveKeybindButtonGroup(ui.keybinds)
        elseif newState == SCENE_HIDDEN and not ui.confirmingCopy then self:CancelJob() end
    end)
    self:SetStatus("Choose a source character, a saved build, then a destination character.")
    self:UpdateListLayout()
end

function WH:SetBusy(busy)
    local ui = self.ui
    if not ui then return end
    if busy or not ui.active then ui.list:Deactivate() else ui.list:Activate() end
    self:UpdateKeybinds()
end

function WH:RenderList()
    local ui, list = self.ui, self.ui.list
    ui.viewKey = ui.level .. ":" .. (ui.source and ui.source.id or "") .. ":" .. (ui.page and (ui.page.tag .. ui.page.pageId) or "")
    local selectedKey = ui.selections[ui.viewKey]
    list:Deactivate(); list:Clear()
    local function add(text, description, actionName, key, activate, extra)
        local data = extra or {}
        data.text, data.description, data.actionName, data.key, data.activate = text, description, actionName, key, activate
        list:AddEntry("WizardsHelperGamepadRow", data)
    end
    if ui.level == "sources" or ui.level == "destinations" then
        local characters = ui.level == "sources" and ui.sources or ui.destinations or {}
        local lastClass
        for _, character in ipairs(characters) do
            if character.classId ~= lastClass then
                add(character.className:upper(), "", nil, nil, nil, { header = true, canSelect = false, enabled = false })
                lastClass = character.classId
            end
            local choosingDestination = ui.level == "destinations"
            local text = character.name .. (character.isCurrent and " (current)" or "")
            local description = choosingDestination and (character.disabledReason or ("Save " .. ui.request.label .. " to a new WW page on " .. character.name .. "."))
                or ("Class: " .. character.className .. ". Browse saved builds and choose where to copy them.")
            add(text, description, choosingDestination and "Copy here" or "Select", character.id, function()
                if choosingDestination then self:RequestCopy(character) else self:SelectSource(character) end
            end, { characterId = character.id, enabled = not character.disabledReason })
        end
        ui.path:SetText(ui.level == "sources" and ("Source characters (" .. #characters .. ")") or (ui.source.name .. " / Choose destination"))
    elseif ui.level == "pages" then
        for _, page in ipairs(ui.source.pages) do
            add(page.tag .. " / " .. page.name .. " (" .. #page.rows .. ")", #page.rows .. " saved build(s). Empty WW placeholders are hidden.",
                "Select", page.tag .. ":" .. page.pageId, function() self:SelectPage(page) end)
        end
        ui.path:SetText(ui.source.name .. " / Saved pages")
    elseif ui.level == "setups" then
        add("Copy all " .. #ui.page.rows .. " builds on this page", "Choose a destination character. Only saved builds are copied; empty trial slots are skipped.",
            "Choose destination", "all", function() self:ChooseDestination(nil) end)
        for _, row in ipairs(ui.page.rows) do
            add(row.name, "Choose a destination character. Equipment IDs, CP, food, skills and the complete saved setup stay unchanged.",
                "Choose destination", "setup:" .. row.index, function() self:ChooseDestination(row) end)
        end
        ui.path:SetText(ui.source.name .. " / " .. ui.page.tag .. " / " .. ui.page.name)
    end
    list:Commit()
    local first, selected
    for index, data in ipairs(list.dataList) do
        if data.canSelect ~= false then first = first or index; if data.key == selectedKey then selected = index end end
    end
    if first then list:SetSelectedIndexWithoutAnimation(selected or first) end
    self:UpdateListLayout()
    if not first then ui.description:SetText("No saved builds to show. Empty trial placeholders are hidden.") end
    self:SetBusy(self.job ~= nil)
end

function WH:SelectSource(source)
    local ui = self.ui
    ui.source, ui.page, ui.request, ui.level = source, nil, nil, "pages"
    self.sv.sources[tostring(GetCurrentCharacterId())] = source.id
    self:RenderList()
end

function WH:SelectPage(page)
    self.ui.page, self.ui.level = page, "setups"
    self:RenderList()
end

function WH:ChooseDestination(row)
    local ui = self.ui
    ui.request = { page = ui.page, row = row, label = row and row.name or (#ui.page.rows .. " saved builds on " .. ui.page.name) }
    ui.destinations, ui.level = self:GetDestinations(ui.page.sourceId), "destinations"
    self:RenderList()
    self:SetStatus("Choose the character that should receive this copy. Existing builds will not be overwritten.")
end

function WH:RequestCopy(destination)
    local ui = self.ui
    if self.job or not ui.request or destination.disabledReason then return end
    local request = ui.request
    if request.page.classId ~= destination.classId then
        ui.confirmingCopy = true
        ZO_Dialogs_ShowGamepadDialog(COPY_DIALOG, { request = request, destination = destination })
    else self:ExecuteCopy(request, destination) end
end

function WH:ExecuteCopy(request, destination)
    local ui = self.ui
    if ui.request ~= request or ui.level ~= "destinations" or self.job then return end
    self:CopyPage(request.page, request.row, nil, function()
        ui.request, ui.destinations, ui.sourcesDirty, ui.level = nil, nil, true, "setups"
        self:RenderList()
    end, destination.id)
end

function WH:RefreshSources()
    if self.job then return end
    local ui = self.ui
    ui.level, ui.source, ui.page, ui.request, ui.sources = "sources", nil, nil, nil, {}
    self:RenderList()
    self:ScanSources(function(sources)
        ui.sources, ui.sourcesDirty = sources, false
        self:RenderList()
        self:SetStatus(#sources > 0 and "Choose a source, a build and a destination. Copying between classes is supported."
            or "No saved WW builds found on this account/server. Empty trial slots are hidden.")
    end)
end

function WH:Back()
    local ui = self.ui
    if self.job then self:CancelJob(); return end
    if ui.level == "destinations" then ui.request, ui.destinations, ui.level = nil, nil, "setups"
    elseif ui.level == "setups" then ui.page, ui.level = nil, "pages"
    elseif ui.level == "pages" then
        ui.source, ui.level = nil, "sources"
        if ui.sourcesDirty then self:RefreshSources(); return end
    else SCENE_MANAGER:Hide(SCENE_NAME); return end
    self:RenderList()
end

function WH:Toggle()
    if not self.ui then return end
    if self.ui.scene:IsShowing() then SCENE_MANAGER:Hide(SCENE_NAME) else SCENE_MANAGER:Push(SCENE_NAME) end
end

function WH:RegisterGamepadMenu()
    if type(ZO_MENU_ENTRIES) ~= "table" or not MAIN_MENU_GAMEPAD then return false end
    for _, entry in ipairs(ZO_MENU_ENTRIES) do if entry.id == self.name then return true end end
    local icon = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_character.dds"
    local entry = ZO_GamepadEntryData:New(self.title, icon)
    entry:SetIconTintOnSelection(true); entry:SetIconDisabledTintOnSelection(true)
    entry.id, entry.data = self.name, { name = self.title, icon = icon, scene = SCENE_NAME }
    local position = #ZO_MENU_ENTRIES + 1
    for index, existing in ipairs(ZO_MENU_ENTRIES) do
        if ZO_MENU_MAIN_ENTRIES and existing.id == ZO_MENU_MAIN_ENTRIES.OPTIONS then position = index; break end
    end
    table.insert(ZO_MENU_ENTRIES, position, entry)
    MAIN_MENU_GAMEPAD:RefreshMainList()
    return true
end
