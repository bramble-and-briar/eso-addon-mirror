DragonWall = DragonWall or {}
local HUB = DragonWall

HUB.name = "DragonWall"
HUB.version = "0.2.1"
HUB.savedVariableVersion = 1
HUB.ECHO_LIMIT = 10
HUB.SCENE_NAME = "dragonWallGamepad"
HUB.MENU_ENTRY_ID = 998
HUB.ICON = "EsoUI/Art/TreeIcons/Gamepad/gp_tutorial_idexIcon_combat.dds"

HUB.PAGE_SHOUTS = 1
HUB.PAGE_LORE = 2
HUB.PAGE_DIAGNOSTICS = 3

local DEFAULTS = {
    activeEchoes = {},
    echoOrder = {},
    echoSelection = {},
    developerDiagnostics = true,
}

local TYPE_FOR_PAGE = {
    [HUB.PAGE_SHOUTS] = "game",
    [HUB.PAGE_LORE] = "lore",
    [HUB.PAGE_DIAGNOSTICS] = "diagnostic",
}

local TITLE_FOR_PAGE = {
    [HUB.PAGE_SHOUTS] = "SHOUTS",
    [HUB.PAGE_LORE] = "LORE",
    [HUB.PAGE_DIAGNOSTICS] = "DIAGNOSTICS",
}

local function SetLabel(parent, childName, text)
    if not parent then return end
    local child = parent:GetNamedChild(childName)
    if child then child:SetText(text or "") end
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, nil end
    return pcall(fn, ...)
end

function HUB:GetReverbEngine()
    return rawget(_G, "DragonWallReverb")
end

function HUB:EnsureState()
    if not self.sv then return false end
    self.sv.activeEchoes = self.sv.activeEchoes or {}
    self.sv.echoOrder = self.sv.echoOrder or {}
    self.sv.echoSelection = self.sv.echoSelection or {}
    return true
end

function HUB:GetActiveModules(presentationType)
    if not self:EnsureState() then return {} end
    if not presentationType then
        local modules = {}
        for _, category in ipairs({"game", "lore", "diagnostic"}) do
            for _, module in ipairs(self:GetActiveModules(category)) do
                modules[#modules + 1] = module
            end
        end
        return modules
    end
    local lib = self:GetReverbEngine()
    if not lib or type(lib.GetModules) ~= "function" then return {} end

    local modules = lib:GetModules() or {}
    local byId = {}
    for _, module in ipairs(modules) do
        if module and module.id then byId[module.id] = module end
    end

    -- Seed each registered Echo once. Explicit false survives reloads.
    local activeCount = 0
    for _, module in ipairs(modules) do
        if self.sv.activeEchoes[module.id] and module.presentationType == presentationType then
            activeCount = activeCount + 1
        end
    end
    for _, module in ipairs(modules) do
        if activeCount >= self.ECHO_LIMIT then break end
        if module.presentationType == presentationType and module.defaultActive == true
            and self.sv.activeEchoes[module.id] == nil then
            self.sv.activeEchoes[module.id] = true
            activeCount = activeCount + 1
        end
    end

    local result, seen = {}, {}
    for _, id in ipairs(self.sv.echoOrder) do
        if #result >= self.ECHO_LIMIT then break end
        local module = byId[id]
        if self.sv.activeEchoes[id] and module and not seen[id]
            and (not presentationType or module.presentationType == presentationType) then
            result[#result + 1] = module
            seen[id] = true
        end
    end
    for _, module in ipairs(modules) do
        if #result >= self.ECHO_LIMIT then break end
        if self.sv.activeEchoes[module.id] and not seen[module.id]
            and (not presentationType or module.presentationType == presentationType) then
            result[#result + 1] = module
            seen[module.id] = true
        end
    end
    return result
end

function HUB:SetModuleActive(moduleId, enabled)
    if not self:EnsureState() then return false, "saved variables unavailable" end
    if type(moduleId) ~= "string" or moduleId == "" then return false, "invalid module id" end

    local lib = self:GetReverbEngine()
    local module = lib and type(lib.GetModule) == "function" and lib:GetModule(moduleId) or nil
    if enabled then
        if not module then return false, "Echo is not registered" end
        local presentationType = module and module.presentationType or nil
        local count = #self:GetActiveModules(presentationType)
        if not self.sv.activeEchoes[moduleId] and count >= self.ECHO_LIMIT then
            return false, "maximum of 10 active Echoes in this Dragon Wall category"
        end
        self.sv.activeEchoes[moduleId] = true
        local found = false
        for _, id in ipairs(self.sv.echoOrder) do
            if id == moduleId then found = true break end
        end
        if not found then table.insert(self.sv.echoOrder, moduleId) end
    else
        self.sv.activeEchoes[moduleId] = false
    end

    if DRAGON_WALL_GAMEPAD and DRAGON_WALL_GAMEPAD.RefreshList then
        DRAGON_WALL_GAMEPAD:RefreshCurrentModule()
    end
    return true
end

function HUB:RegisterReverbHost()
    local lib = self:GetReverbEngine()
    if not lib or type(lib.RegisterHost) ~= "function" then return false end

    local ok = lib:RegisterHost({
        id = "DragonWall",
        apiVersion = 1,
        maxActiveModules = self.ECHO_LIMIT,
        GetActiveModuleIds = function()
            local ids = {}
            for _, module in ipairs(HUB:GetActiveModules()) do ids[#ids + 1] = module.id end
            return ids
        end,
        SetModuleActive = function(_, moduleId, enabled)
            return HUB:SetModuleActive(moduleId, enabled)
        end,
        OnModulesChanged = function()
            if DRAGON_WALL_GAMEPAD then
                DRAGON_WALL_GAMEPAD:RefreshCurrentModule()
            end
            if HUB.settingsPanel and HUB.settingsPanel.Refresh then
                pcall(function() HUB.settingsPanel:Refresh() end)
            end
        end,
        OnModuleDataChanged = function(_, moduleId)
            if DRAGON_WALL_GAMEPAD and DRAGON_WALL_GAMEPAD.RefreshCurrentModule then
                DRAGON_WALL_GAMEPAD:RefreshCurrentModule(moduleId)
            end
        end,
    })
    return ok == true
end

-- ==========================================================
-- GAMEPAD HUB UI
-- ==========================================================
DragonWall_Gamepad = ZO_Gamepad_ParametricList_Screen:Subclass()

function DragonWall_Gamepad:New(control)
    local object = ZO_Object.New(self)
    object:Initialize(control)
    return object
end

function DragonWall_Gamepad:ApplyContentFrameAnchors()
    if not self.contentFrame or not GuiRoot then return end
    local width, height = GuiRoot:GetWidth() or 0, GuiRoot:GetHeight() or 0
    if width <= 0 or height <= 0 then return end

    local left, right
    local q234 = ZO_SharedGamepadNavQuadrant_2_3_4_Background
    if q234 and q234.GetLeft and q234.GetRight then
        local l, r = q234:GetLeft(), q234:GetRight()
        if l and r and r > l then left, right = l + 20, r - 20 end
    end
    if not left or not right then
        local panelWidth = tonumber(ZO_GAMEPAD_PANEL_WIDTH) or (width / 4)
        local safeInsetX = tonumber(ZO_GAMEPAD_SAFE_ZONE_INSET_X) or 0
        left = safeInsetX + panelWidth + 20
        right = width - safeInsetX - 20
    end

    self.contentFrame:ClearAnchors()
    self.contentFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, 135)
    self.contentFrame:SetAnchor(BOTTOMRIGHT, GuiRoot, TOPLEFT, right, height - 110)
end

function DragonWall_Gamepad:Initialize(control)
    self.control = control
    self.contentFrame = control:GetNamedChild("ContentFrame")
    self.presentationPage = self.contentFrame and self.contentFrame:GetNamedChild("PresentationPage")
    self.echoPageIndexes = {}

    self:ApplyContentFrameAnchors()

    DRAGON_WALL_GAMEPAD_FRAGMENT = ZO_FadeSceneFragment:New(control)
    DRAGON_WALL_GAMEPAD_SCENE = ZO_Scene:New(HUB.SCENE_NAME, SCENE_MANAGER)
    DRAGON_WALL_GAMEPAD_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    DRAGON_WALL_GAMEPAD_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    DRAGON_WALL_GAMEPAD_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    if GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT then
        DRAGON_WALL_GAMEPAD_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_4_BACKGROUND_FRAGMENT)
    elseif GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT then
        DRAGON_WALL_GAMEPAD_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT)
    end
    DRAGON_WALL_GAMEPAD_SCENE:AddFragment(GAMEPAD_GENERIC_FOOTER_FRAGMENT)
    DRAGON_WALL_GAMEPAD_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    DRAGON_WALL_GAMEPAD_SCENE:AddFragment(DRAGON_WALL_GAMEPAD_FRAGMENT)

    ZO_Gamepad_ParametricList_Screen.Initialize(
        self,
        control,
        ZO_GAMEPAD_HEADER_TABBAR_CREATE,
        true,
        DRAGON_WALL_GAMEPAD_SCENE
    )
end

function DragonWall_Gamepad:OnDeferredInitialize()
    self.headerData = {
        titleText = "DRAGON WALL",
        subtitleText = "Games • Lore • Diagnostics",
        tabBarEntries = nil,
    }
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData, true)

    self.mainList = self:GetMainList()
    self:RefreshList()
end

function DragonWall_Gamepad:SetupList(list)
    list:AddDataTemplate(
        "ZO_GamepadItemSubEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction
    )
    list:SetNoItemText("No Dragon Wall pages available")
end

function DragonWall_Gamepad:OnTargetChanged(_, targetData)
    if targetData and targetData.dragonWallPage then
        self:ShowPage(targetData.dragonWallPage)
    end
end

function DragonWall_Gamepad:OnShowing()
    self:ApplyContentFrameAnchors()
    self:ShowPage(self.currentPage)
end

function DragonWall_Gamepad:RefreshList()
    if not self.mainList then return end
    self.mainList:Clear()
    local pages = {
        { name = "Shouts", page = HUB.PAGE_SHOUTS },
        { name = "Lore", page = HUB.PAGE_LORE },
        { name = "Diagnostics", page = HUB.PAGE_DIAGNOSTICS },
    }
    for _, page in ipairs(pages) do
        local entry = ZO_GamepadEntryData:New(page.name)
        entry.dragonWallPage = page.page
        self.mainList:AddEntry("ZO_GamepadItemSubEntryTemplate", entry)
    end
    self.mainList:Commit()
end

function DragonWall_Gamepad:GetModulesForPage(page)
    return HUB:GetActiveModules(TYPE_FOR_PAGE[page])
end

function DragonWall_Gamepad:GetCurrentModuleIndex(page)
    return tonumber(self.echoPageIndexes[page]) or 1
end

function DragonWall_Gamepad:SetCurrentModuleIndex(page, index)
    self.echoPageIndexes[page] = index
end

function DragonWall_Gamepad:GetCurrentEcho()
    local modules = self:GetModulesForPage(self.currentPage)
    if #modules == 0 then return nil end
    local index = self:GetCurrentModuleIndex(self.currentPage)
    if index > #modules then index = 1 elseif index < 1 then index = #modules end
    self:SetCurrentModuleIndex(self.currentPage, index)
    return modules[index]
end

function DragonWall_Gamepad:ChangeEcho(delta)
    local modules = self:GetModulesForPage(self.currentPage)
    if #modules <= 1 then return end
    local index = self:GetCurrentModuleIndex(self.currentPage)
    index = ((index - 1 + (tonumber(delta) or 0)) % #modules) + 1
    self:SetCurrentModuleIndex(self.currentPage, index)
    self:ShowPage(self.currentPage)
end

function DragonWall_Gamepad:GetCurrentModuleEntryCount()
    local module = self:GetCurrentEcho()
    if not module then return 0 end
    if type(module.GetEntryCount) == "function" then
        local ok, count = pcall(module.GetEntryCount, module)
        if ok then return math.max(0, tonumber(count) or 0) end
    end
    return 1
end

function DragonWall_Gamepad:ChangeEchoEntry(delta)
    local module = self:GetCurrentEcho()
    if not module or self:GetCurrentModuleEntryCount() <= 1 then return end
    local lib = HUB:GetReverbEngine()
    if lib and type(lib.ChangeModuleEntry) == "function" then
        lib:ChangeModuleEntry(module.id, tonumber(delta) or 0)
    elseif type(module.ChangeEntry) == "function" then
        pcall(module.ChangeEntry, module, tonumber(delta) or 0)
    end
end

function DragonWall_Gamepad:GetEchoAction(slot)
    local module = self:GetCurrentEcho()
    local lib = HUB:GetReverbEngine()
    if not module or not lib or type(lib.GetModuleActions) ~= "function" then return nil end
    local actions = lib:GetModuleActions(module.id) or {}
    return actions[slot]
end

function DragonWall_Gamepad:IsEchoActionVisible(slot)
    local action = self:GetEchoAction(slot)
    if not action then return false end
    if type(action.visible) == "function" then
        local module = self:GetCurrentEcho()
        local ok, visible = pcall(action.visible, module)
        return ok and visible ~= false
    end
    return true
end

function DragonWall_Gamepad:IsEchoActionEnabled(slot)
    local action = self:GetEchoAction(slot)
    if not action then return false end
    if type(action.enabled) == "function" then
        local module = self:GetCurrentEcho()
        local ok, enabled = pcall(action.enabled, module)
        return ok and enabled ~= false
    end
    return true
end

function DragonWall_Gamepad:InvokeEchoAction(slot)
    local module = self:GetCurrentEcho()
    local lib = HUB:GetReverbEngine()
    if not module or not lib or type(lib.InvokeModuleAction) ~= "function" then return end
    local ok, err = lib:InvokeModuleAction(module.id, slot)
    if ok == false and d then d("[Dragon Wall] " .. tostring(err)) end
    self:ShowPage(self.currentPage)
end

function DragonWall_Gamepad:GetDiagnosticText(module)
    local lib = HUB:GetReverbEngine()
    if not lib then
        return "REVERB ENGINE: NOT DETECTED", "Dragon Wall cannot present Echoes until the bundled engine loads."
    end
    if not module then
        return string.format("REVERB ENGINE: detected\nRegistered Echoes: %d", lib.GetModuleCount and lib:GetModuleCount() or 0),
            "No active Echo in this category."
    end

    local actions = lib.GetModuleActions and lib:GetModuleActions(module.id) or {}
    local actionNames = {}
    for _, slot in ipairs({"primary", "secondary", "tertiary", "utility"}) do
        local action = actions[slot]
        actionNames[#actionNames + 1] = string.format("%s: %s", slot, action and (action.name or "available") or "none")
    end

    local left = table.concat({
        "Echo ID: " .. tostring(module.id),
        "Name: " .. tostring(module.name),
        "Type: " .. tostring(module.presentationType),
        "API: " .. tostring(module.apiVersion),
        "Entries: " .. tostring(self:GetCurrentModuleEntryCount()),
    }, "\n")
    local right = table.concat(actionNames, "\n")
    return left, right
end

function DragonWall_Gamepad:SetDiagnosticControlsVisible(visible)
    if not self.presentationPage then return end
    for _, childName in ipairs({"DiagLeftHeader", "DiagLeftBody", "DiagRightHeader", "DiagRightBody"}) do
        local child = self.presentationPage:GetNamedChild(childName)
        if child then child:SetHidden(not visible) end
    end
    local body = self.presentationPage:GetNamedChild("Body")
    if body then body:SetHidden(visible) end
end

function DragonWall_Gamepad:ShowPage(page)
    if not self.presentationPage then return end
    self.currentPage = page or HUB.PAGE_SHOUTS
    local title = TITLE_FOR_PAGE[self.currentPage] or "DRAGON WALL"
    local modules = self:GetModulesForPage(self.currentPage)
    local index = self:GetCurrentModuleIndex(self.currentPage)

    SetLabel(self.presentationPage, "Title", title)

    if #modules == 0 then
        self:SetCurrentModuleIndex(self.currentPage, 1)
        self:SetDiagnosticControlsVisible(false)
        SetLabel(self.presentationPage, "Subtitle", "No active Echoes")
        SetLabel(self.presentationPage, "ModuleTitle", "DRAGON WALL HUB")
        SetLabel(self.presentationPage, "ModuleSubtitle", "Ready for connected Echoes")
        SetLabel(self.presentationPage, "Body",
            "Install a compatible addon or show an installed Echo in Dragon Wall settings.")
        SetLabel(self.presentationPage, "Indicator", "0 / 10 active Echoes in this category")
    else
        if index > #modules then index = 1 elseif index < 1 then index = #modules end
        self:SetCurrentModuleIndex(self.currentPage, index)
        local module = modules[index]
        local data = {}
        if type(module.GetPresentationData) == "function" then
            local ok, result = pcall(module.GetPresentationData, module)
            if ok and type(result) == "table" then data = result end
        end

        local body = type(data.body) == "string" and data.body or table.concat(data.lines or {}, "\n")
        local moduleTitle = data.collectionTitle or data.title or module.name or module.id or "Echo"
        local moduleSubtitle = data.subtitle or module.description or ""
        if data.senderName then
            moduleSubtitle = data.senderName .. (data.subject and data.subject ~= "" and (" — " .. data.subject) or "")
        elseif data.author then
            moduleSubtitle = (data.title or moduleTitle) .. " — " .. data.author
        end
        if data.entryIndex and data.entryCount then
            moduleSubtitle = moduleSubtitle .. string.format(" • %d / %d", data.entryIndex, data.entryCount)
        end

        SetLabel(self.presentationPage, "Subtitle", string.format("Echo %d of %d", index, #modules))
        SetLabel(self.presentationPage, "ModuleTitle", moduleTitle)
        SetLabel(self.presentationPage, "ModuleSubtitle", moduleSubtitle)

        if self.currentPage == HUB.PAGE_DIAGNOSTICS and HUB.sv.developerDiagnostics == true then
            self:SetDiagnosticControlsVisible(true)
            local left, right = self:GetDiagnosticText(module)
            SetLabel(self.presentationPage, "DiagLeftHeader", "ECHO / API")
            SetLabel(self.presentationPage, "DiagLeftBody", left)
            SetLabel(self.presentationPage, "DiagRightHeader", "ACTIONS / KEYBINDS")
            SetLabel(self.presentationPage, "DiagRightBody", right)
        else
            self:SetDiagnosticControlsVisible(false)
            SetLabel(self.presentationPage, "Body", body)
        end

        local controls = {}
        if #modules > 1 then controls[#controls + 1] = "L1 / R1 Echoes" end
        if self:GetCurrentModuleEntryCount() > 1 then controls[#controls + 1] = "L2 / R2 entries" end
        if #controls == 0 then controls[1] = "Connected through Reverb Engine" end
        SetLabel(self.presentationPage, "Indicator", table.concat(controls, " • "))
    end

    if self.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end
end

function DragonWall_Gamepad:RefreshCurrentModule(moduleId)
    if SCENE_MANAGER:GetCurrentScene() ~= DRAGON_WALL_GAMEPAD_SCENE then return end
    local current = self:GetCurrentEcho()
    if not moduleId or (current and current.id == moduleId) then
        self:ShowPage(self.currentPage)
    end
end

function DragonWall_Gamepad:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = "Previous Echo",
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function() return #self:GetModulesForPage(self.currentPage) > 1 end,
            callback = function() self:ChangeEcho(-1) end,
        },
        {
            name = "Next Echo",
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function() return #self:GetModulesForPage(self.currentPage) > 1 end,
            callback = function() self:ChangeEcho(1) end,
        },
        {
            name = "Previous Entry",
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            visible = function() return self:GetCurrentModuleEntryCount() > 1 end,
            callback = function() self:ChangeEchoEntry(-1) end,
        },
        {
            name = "Next Entry",
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            visible = function() return self:GetCurrentModuleEntryCount() > 1 end,
            callback = function() self:ChangeEchoEntry(1) end,
        },
        {
            name = function()
                local a = self:GetEchoAction("primary")
                return a and a.name or "Action"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function() return self:IsEchoActionVisible("primary") end,
            enabled = function() return self:IsEchoActionEnabled("primary") end,
            callback = function() self:InvokeEchoAction("primary") end,
        },
        {
            name = function()
                local a = self:GetEchoAction("secondary")
                return a and a.name or "Secondary"
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function() return self:IsEchoActionVisible("secondary") end,
            enabled = function() return self:IsEchoActionEnabled("secondary") end,
            callback = function() self:InvokeEchoAction("secondary") end,
        },
        {
            name = function()
                local a = self:GetEchoAction("tertiary")
                return a and a.name or "Tertiary"
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function() return self:IsEchoActionVisible("tertiary") end,
            enabled = function() return self:IsEchoActionEnabled("tertiary") end,
            callback = function() self:InvokeEchoAction("tertiary") end,
        },
        {
            name = function()
                local a = self:GetEchoAction("utility")
                return a and a.name or "Utility"
            end,
            keybind = "UI_SHORTCUT_LEFT_STICK",
            visible = function() return self:IsEchoActionVisible("utility") end,
            enabled = function() return self:IsEchoActionEnabled("utility") end,
            callback = function() self:InvokeEchoAction("utility") end,
        },
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function() SCENE_MANAGER:HideCurrentScene() end,
        },
    }
end

local function AddToJournalMenu()
    if HUB.menuAdded then return true end
    if not DRAGON_WALL_GAMEPAD or not MAIN_MENU_GAMEPAD or not ZO_MENU_ENTRIES or not ZO_MENU_MAIN_ENTRIES then return false end
    local journalEntry
    for _, entry in ipairs(ZO_MENU_ENTRIES) do
        if entry.id == ZO_MENU_MAIN_ENTRIES.JOURNAL then journalEntry = entry break end
    end
    if not journalEntry or not journalEntry.subMenu then return false end

    local menuData = { name = "Dragon Wall", icon = HUB.ICON, scene = HUB.SCENE_NAME }
    local entry = ZO_GamepadEntryData:New(menuData.name, menuData.icon)
    entry:SetIconTintOnSelection(true)
    if entry.SetIconDisabledTintOnSelection then entry:SetIconDisabledTintOnSelection(true) end
    entry.data = menuData
    entry.id = HUB.MENU_ENTRY_ID

    table.insert(journalEntry.subMenu, entry)

    if MAIN_MENU_GAMEPAD then
        MAIN_MENU_GAMEPAD:RefreshLists()
        MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates()
    end
    HUB.menuAdded = true
    return true
end

function HUB:InitSettingsMenu()
    if not LibHarvensAddonSettings then return end
    local HAS = LibHarvensAddonSettings
    local settings = HAS:AddAddon("Dragon Wall", {allowDefaults=true, allowRefresh=true})
    if not settings then return end
    self.settingsPanel = settings

    local function GetModulesForType(presentationType)
        local lib = HUB:GetReverbEngine()
        if not lib or type(lib.GetModulesByType) ~= "function" then return {} end
        local ok, modules = pcall(function() return lib:GetModulesByType(presentationType) end)
        return ok and type(modules) == "table" and modules or {}
    end

    local function GetSelectedModuleId(presentationType)
        local selected = HUB.sv.echoSelection[presentationType]
        local modules = GetModulesForType(presentationType)
        if selected then
            for _, module in ipairs(modules) do if module.id == selected then return selected end end
        end
        if modules[1] and modules[1].id then
            HUB.sv.echoSelection[presentationType] = modules[1].id
            return modules[1].id
        end
        return nil
    end

    local function GetItems(presentationType)
        local items = {}
        for _, module in ipairs(GetModulesForType(presentationType)) do
            items[#items + 1] = {name = module.name or module.id, data = module.id}
        end
        if #items == 0 then items[1] = {name = "No compatible Echoes detected", data = false} end
        return items
    end

    local function AddManager(label, presentationType, defaultEnabled)
        settings:AddSetting({type=HAS.ST_SECTION, label=label})
        settings:AddSetting({
            type=HAS.ST_DROPDOWN,
            label="Detected Echo",
            items=function() return GetItems(presentationType) end,
            getFunction=function()
                local id = GetSelectedModuleId(presentationType)
                for _, module in ipairs(GetModulesForType(presentationType)) do
                    if module.id == id then return module.name or module.id end
                end
                return "No compatible Echoes detected"
            end,
            setFunction=function(_, itemName, itemData)
                local candidate = type(itemData) == "table" and (itemData.data or itemData.id) or itemData
                if type(candidate) ~= "string" then
                    for _, module in ipairs(GetModulesForType(presentationType)) do
                        if module.name == itemName or module.id == itemName then candidate = module.id break end
                    end
                end
                if type(candidate) == "string" then HUB.sv.echoSelection[presentationType] = candidate end
            end,
        })
        settings:AddSetting({
            type=HAS.ST_CHECKBOX,
            label="Show Selected Echo",
            getFunction=function()
                local id = GetSelectedModuleId(presentationType)
                return id and HUB.sv.activeEchoes[id] == true or false
            end,
            setFunction=function(value)
                local id = GetSelectedModuleId(presentationType)
                if id then HUB:SetModuleActive(id, value == true) end
            end,
            default=defaultEnabled == true,
        })
    end

    AddManager("Shouts", "game", true)
    AddManager("Lore", "lore", false)
    AddManager("Diagnostics", "diagnostic", true)

    settings:AddSetting({type=HAS.ST_SECTION, label="Developer"})
    settings:AddSetting({
        type=HAS.ST_CHECKBOX,
        label="Show Reverb Diagnostics",
        getFunction=function() return HUB.sv.developerDiagnostics == true end,
        setFunction=function(value) HUB.sv.developerDiagnostics = value == true end,
        default=true,
    })
    settings:AddSetting({
        type=HAS.ST_LABEL,
        label="Dragon Wall " .. self.version .. " (account-wide)",
        tooltip="The Hub, bundled Reverb Engine and built-in diagnostic Echo are installed and structurally independent from STARS.",
    })
    settings:AddSetting({
        type = HAS.ST_SECTION,
        subMenu = false,
        label = "|cFFD700Built on tea, toast and ADHD - tested live on PS5.|r\n" ..
                "|cB427D3Su|c546D6Aga|c889764Co|cDA34CDma|r",
    })
    settings:AddSetting({
        type = HAS.ST_LABEL,
        label = "Contact",
        tooltip = "Dragon Wall support\n\nPlayStation User / PSN: SugaComa\nEmail: eso.addons@rik-sprint.co.uk or use www.rik-sprint.co.uk/contact",
    })
end

function HUB:Initialize()
    self.sv = ZO_SavedVars:NewAccountWide("EchoVerseHub_SV", self.savedVariableVersion, nil, DEFAULTS)
    self:EnsureState()
    self:RegisterReverbHost()
    self:GetActiveModules("game")
    self:GetActiveModules("lore")
    self:GetActiveModules("diagnostic")
    self:InitSettingsMenu()

    local control = DragonWallGamepad
    if control then
        DRAGON_WALL_GAMEPAD = DragonWall_Gamepad:New(control)
    elseif d then
        d("[Dragon Wall] Hub root control was not created.")
    end

    if not AddToJournalMenu() then
        EVENT_MANAGER:RegisterForEvent("DragonWall_Menu", EVENT_PLAYER_ACTIVATED, function()
            if AddToJournalMenu() then
                EVENT_MANAGER:UnregisterForEvent("DragonWall_Menu", EVENT_PLAYER_ACTIVATED)
            end
        end)
    end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= HUB.name then return end
    EVENT_MANAGER:UnregisterForEvent(HUB.name, EVENT_ADD_ON_LOADED)
    HUB:Initialize()
end

EVENT_MANAGER:RegisterForEvent(HUB.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
