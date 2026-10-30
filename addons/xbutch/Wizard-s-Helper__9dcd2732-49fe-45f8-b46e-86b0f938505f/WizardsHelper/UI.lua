local WH = WizardsHelper
local SCENE_NAME = "WizardsHelperScene"
local PAGE_SIZE = 9

function WH:UpdateKeybinds()
    if self.ui and self.ui.active then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.ui.keybinds) end
end

function WH:CreateUI()
    local window = WizardsHelperGamepad
    local ui = {
        window = window, status = window:GetNamedChild("Status"),
        description = window:GetNamedChild("Description"), path = window:GetNamedChild("Path"),
        level = "sources", sources = {}, offset = 0,
    }
    self.ui = ui
    local list = ZO_GamepadVerticalParametricScrollList:New(window:GetNamedChild("List"))
    ui.list = list
    list:SetUniversalPostPadding(4)
    list:SetSelectedItemOffsets(0, 0)
    list:SetAlignToScreenCenter(false)
    list:SetFixedCenterOffset(225)
    list:AddDataTemplate("WizardsHelperGamepadRow", function(control, data, selected)
        control:GetNamedChild("Text"):SetText(data.text)
        control:GetNamedChild("Highlight"):SetHidden(not selected)
    end)
    list:SetOnTargetDataChangedCallback(function(_, data)
        ui.description:SetText(data and data.description or "Choose another character of the same base class.")
        self:UpdateKeybinds()
    end)
    ui.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            keybind = "UI_SHORTCUT_PRIMARY",
            name = function()
                local data = list:GetTargetData()
                return data and data.actionName or "Select"
            end,
            enabled = function() return not self.job and list:GetTargetData() ~= nil end,
            callback = function()
                local data = list:GetTargetData()
                if not self.job and data and data.activate then data.activate() end
            end,
        },
        {
            keybind = "UI_SHORTCUT_NEGATIVE",
            name = function() return self.job and "Cancel" or ui.level == "sources" and "Close" or "Back" end,
            callback = function() self:Back() end,
        },
        {
            keybind = "UI_SHORTCUT_SECONDARY", name = "Refresh",
            enabled = function() return not self.job end,
            callback = function() self:RefreshSources() end,
        },
        {
            keybind = "UI_SHORTCUT_TERTIARY", name = "Select copy in WW",
            visible = function() return self.lastCopy ~= nil end,
            enabled = function() return not self.job end,
            callback = function() if not self.job then self:OpenLastCopy() end end,
        },
    }
    ui.scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    ui.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    ui.scene:AddFragment(ZO_FadeSceneFragment:New(window))
    ui.scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            ui.active = true
            KEYBIND_STRIP:AddKeybindButtonGroup(ui.keybinds)
            self:RefreshSources()
        elseif newState == SCENE_HIDING then
            ui.active = false
            list:Deactivate()
            KEYBIND_STRIP:RemoveKeybindButtonGroup(ui.keybinds)
        elseif newState == SCENE_HIDDEN then
            self:CancelJob()
        end
    end)
    self:SetStatus("Open Wizard's Helper from the gamepad menu, keybinding, or LibRadialMenu.")
end

function WH:SetBusy(busy)
    local ui = self.ui
    if not ui then return end
    if busy or not ui.active then ui.list:Deactivate() else ui.list:Activate() end
    self:UpdateKeybinds()
end

function WH:RenderList()
    local ui = self.ui
    local list = ui.list
    list:Deactivate()
    list:Clear()
    local items = ui.level == "sources" and ui.sources or ui.level == "pages" and ui.source.pages or ui.page.rows
    local count = #items + (ui.level == "setups" and 1 or 0)
    local function add(text, description, actionName, activate)
        list:AddEntry("WizardsHelperGamepadRow", { text = text, description = description, actionName = actionName, activate = activate })
    end
    if ui.offset > 0 then
        add("< Previous entries", "Show the previous entries.", "Previous", function()
            ui.offset = math.max(0, ui.offset - PAGE_SIZE); self:RenderList()
        end)
    end
    for index = ui.offset + 1, math.min(ui.offset + PAGE_SIZE, count) do
        if ui.level == "sources" then
            local source = items[index]
            add(source.name, "Browse this character's saved WW pages. Source data stays unchanged.", "Select", function() self:SelectSource(source) end)
        elseif ui.level == "pages" then
            local page = items[index]
            add(page.tag .. " / " .. page.name, #page.rows .. " saved setup(s). Choose a setup or copy the entire page.", "Select", function() self:SelectPage(page) end)
        else
            local row = index > 1 and items[index - 1] or nil
            local text = row and (row.index .. ". " .. row.name) or "Copy entire page"
            add(text, "Creates a new page in " .. ui.page.tag .. ". Equipment IDs, skills, CP, food, conditions and custom code stay unchanged.",
                row and "Copy setup" or "Copy page", function() self:CopyPage(ui.page, row, nil) end)
        end
    end
    if ui.offset + PAGE_SIZE < count then
        add("Next entries >", "Show the next entries.", "Next", function() ui.offset = ui.offset + PAGE_SIZE; self:RenderList() end)
    end
    local path = ui.level == "sources" and "Source character" or ui.level == "pages" and (ui.source.name .. " / Pages")
        or (ui.source.name .. " / " .. ui.page.tag .. " / " .. ui.page.name)
    ui.path:SetText(path)
    list:Commit()
    if count > 0 then list:SetSelectedIndexWithoutAnimation(1) end
    if count == 0 then ui.description:SetText("No other same-class characters with saved WW setups on this account/server.") end
    self:SetBusy(self.job ~= nil)
end

function WH:SelectSource(source)
    local ui = self.ui
    ui.source, ui.page, ui.level, ui.offset = source, nil, "pages", 0
    self.sv.sources[tostring(GetCurrentCharacterId())] = source.id
    self:RenderList()
end

function WH:SelectPage(page)
    local ui = self.ui
    ui.page, ui.level, ui.offset = page, "setups", 0
    self:RenderList()
end

function WH:RefreshSources()
    if self.job then return end
    local ui = self.ui
    ui.level, ui.source, ui.page, ui.sources, ui.offset = "sources", nil, nil, {}, 0
    self:RenderList()
    self:ScanSources(function(sources)
        ui.sources = sources
        self:RenderList()
        self:SetStatus(#sources > 0 and "Choose a source character. Every copy creates a new WW page."
            or "Save a WW setup on another character of the same base class, then return and refresh.")
    end)
end

function WH:Back()
    local ui = self.ui
    if self.job then self:CancelJob(); return end
    if ui.level == "setups" then
        ui.page, ui.level, ui.offset = nil, "pages", 0
        self:RenderList()
    elseif ui.level == "pages" then
        ui.source, ui.level, ui.offset = nil, "sources", 0
        self:RenderList()
    else
        SCENE_MANAGER:Hide(SCENE_NAME)
    end
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
    entry:SetIconTintOnSelection(true)
    entry:SetIconDisabledTintOnSelection(true)
    entry.id = self.name
    entry.data = { name = self.title, icon = icon, scene = SCENE_NAME }
    local position = #ZO_MENU_ENTRIES + 1
    for index, existing in ipairs(ZO_MENU_ENTRIES) do
        if ZO_MENU_MAIN_ENTRIES and existing.id == ZO_MENU_MAIN_ENTRIES.OPTIONS then position = index; break end
    end
    table.insert(ZO_MENU_ENTRIES, position, entry)
    MAIN_MENU_GAMEPAD:RefreshMainList()
    return true
end
