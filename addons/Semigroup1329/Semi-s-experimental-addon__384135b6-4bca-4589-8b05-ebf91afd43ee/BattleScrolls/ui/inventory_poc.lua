---@diagnostic disable: undefined-field, inject-field -- ESO Control/ZO_* stubs do not describe native UI fields completely
if not SemisPlaygroundCheckAccess() then return end

local poc = BattleScrolls.inventoryPoc
local SCENE_NAME = 'battleScrollsInventoryPoc'
local SELECTED_ICON = 'EsoUI/Art/Miscellaneous/Gamepad/gp_checkmark.dds'

---@class InventoryPocUI
local ui = {}
BattleScrolls.inventoryPocUI = ui

-- Posting through the API does not enter the native create-listing dialog,
-- whose close path normally refreshes the sell keybind's occupied-slot count.
-- Refresh only presentation: leave native callbacks and dialogs untouched.
function ui.refreshTradingHouse()
    if GetInteractionType() ~= INTERACTION_TRADINGHOUSE then return end
    if BattleScrolls.inventoryPocTradingHouseUI.isSuspended() then return end
    if IsInGamepadPreferredMode() then
        if GAMEPAD_TRADING_HOUSE_SELL then GAMEPAD_TRADING_HOUSE_SELL:UpdateKeybind() end
    elseif TRADING_HOUSE then
        TRADING_HOUSE:UpdateListingCounts()
    end
end

local screen, menuEntry, menuParent
local LOG_TEMPLATE = 'ZO_GamepadItemSubEntryTemplate'
local utils = BattleScrolls.utils
---@class InventoryPocLogScreen: ZO_Object
---@field logRevision number
---@field buildKey string
---@field contentsPanel InventoryPocContentsPanel
---@field contentsFocused boolean|nil
---@field selectedLogEntry InventoryPocLogEntry|nil
---@field updatingLog boolean|nil
---@field tab 'activity'|'pack'
---@field pack InventoryPocPackView
---@field resetSelection boolean|nil The tab changed: its list starts at the top
---@field traderPaused boolean|nil Guild-store visits open ESO's screen for now
local LogScreen = ZO_Gamepad_ParametricList_Screen:Subclass()
local details = BattleScrolls.inventoryPocDetails

local function resetTooltips()
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
end

---@param entry InventoryPocLogEntry|nil
---@return boolean
local function hasContents(entry)
    return entry ~= nil and entry.contents ~= nil and #entry.contents > 0
end

---@param bag number
---@return string
local function bagName(bag)
    if bag == BAG_WORN then return GetString(SI_ITEM_FORMAT_STR_EQUIPPED) end
    if bag == BAG_COMPANION_WORN then return GetString(SI_ITEM_FORMAT_STR_EQUIPPED_COMPANION) end
    return GetString('SI_BAG', bag == BAG_SUBSCRIBER_BANK and BAG_BANK or bag)
end

---@param issue InventoryPocBuildIssue
---@return string
local function buildIssueText(issue)
    if issue.kind == 'gear' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_BUILD_GEAR), GetString('SI_EQUIPSLOT', issue.slot))
    elseif issue.kind == 'skill' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_BUILD_SKILL), GetString('SI_HOTBARCATEGORY', issue.bar), issue.slot)
    elseif issue.kind == 'champion' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_BUILD_CHAMPION), issue.slot)
    elseif issue.kind == 'food' then return GetString(BATTLESCROLLS_IPOC_BUILD_FOOD)
    elseif issue.kind == 'selector' then return GetString(BATTLESCROLLS_IPOC_BUILD_SELECTOR)
    -- ESO's own wording, the text its failure notice shows.
    elseif issue.kind == 'armory' then return GetString('SI_ARMORYBUILDRESTORERESULT', issue.result)
    else return GetString(BATTLESCROLLS_IPOC_BUILD_STOPPED) end
end

---@param issue InventoryPocBuildIssue
---@return string
local function buildIssueDetails(issue)
    local text = buildIssueText(issue)
    if issue.expected == nil then return text end
    local function value(id)
        local name
        if issue.kind == 'skill' or issue.kind == 'food' then name = GetAbilityName(tonumber(id) or 0, '')
        elseif issue.kind == 'champion' then name = GetChampionSkillName(tonumber(id) or 0) end
        return name and name ~= '' and (name .. ' (' .. tostring(id) .. ')') or tostring(id)
    end
    return text .. '\n' .. zo_strformat(GetString(BATTLESCROLLS_IPOC_BUILD_EXPECTED), value(issue.expected), value(issue.actual))
end

---@param entry InventoryPocLogEntry
local function showLogTooltip(entry)
    local lines = { utils.formatDate(entry.timestamp) .. ' ' .. utils.formatTime(entry.timestamp), entry.character }
    local function add(id, ...)
        details.add(lines, id, ...)
    end
    if entry.reason and details.REASONS[entry.reason] then
        add(BATTLESCROLLS_IPOC_DETAIL_REASON, GetString(details.REASONS[entry.reason]))
    end
    if entry.setupName then lines[#lines + 1] = entry.setupName end
    if entry.buildIssue then lines[#lines + 1] = buildIssueDetails(entry.buildIssue) end
    if entry.marketIssue then
        if entry.guildId then lines[#lines + 1] = GetGuildName(entry.guildId) end
        local result = entry.marketIssue.result
        if result then lines[#lines + 1] = GetString('SI_TRADINGHOUSERESULT', result) end
        lines[#lines + 1] = entry.marketIssue.diagnostics
    end
    if entry.itemLink ~= '' then
        local link = entry.itemLink
        add(BATTLESCROLLS_IPOC_DETAIL_QUANTITY, entry.quantity)
        add(BATTLESCROLLS_IPOC_DETAIL_FROM, bagName(entry.fromBag))
        if entry.toBag then add(BATTLESCROLLS_IPOC_DETAIL_TO, bagName(entry.toBag)) end
        details.identity(lines, link, entry.itemId)
        local prices = entry.details
        if prices then
            add(BATTLESCROLLS_IPOC_DETAIL_STACK, prices.stack)
            add(BATTLESCROLLS_IPOC_DETAIL_SLOT, prices.slot, prices.uniqueId)
            details.prices(lines, link, prices)
        end
        if entry.discount and entry.discount < 1 then
            add(BATTLESCROLLS_IPOC_DETAIL_DISCOUNT, zo_round((1 - entry.discount) * 100))
        end
        -- Native item preview works from the saved link after the item is gone.
        GAMEPAD_TOOLTIPS:LayoutItemWithStackCountSimple(GAMEPAD_RIGHT_TOOLTIP, link, entry.quantity)
    end
    -- The game's LEFT tooltip occupies quadrant 2, immediately right of the list.
    GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, poc.formatLog(entry), table.concat(lines, '\n'))
end

local function buildKey()
    local state = BattleScrolls.inventoryPocBuilds.state()
    return state and ((state.choice or '') .. ':' .. state.status) or ''
end

---@param control Control
---@param scene ZO_Scene
---@return InventoryPocLogScreen
function LogScreen.new(control, scene)
    local object = ZO_Object.New(LogScreen)
    ZO_Gamepad_ParametricList_Screen.Initialize(object, control, ZO_GAMEPAD_HEADER_TABBAR_CREATE, true, scene)
    object:SetListsUseTriggerKeybinds(true)
    object.contentsPanel = BattleScrolls.inventoryPocContents.new(control:GetNamedChild('Contents'))
    object.tab = 'activity'
    object.pack = BattleScrolls.inventoryPocPack.new(object.headerContainer, object.header, function()
        object:refreshHeader()
        object:Update()
    end)
    return object
end

function LogScreen:refreshHeader()
    self.pack:headerData(self.headerData)
    ZO_GamepadGenericHeader_RefreshData(self.header, self.headerData)
end

---@param tab 'activity'|'pack'
function LogScreen:setTab(tab)
    if self.tab == tab then return end
    self.tab, self.resetSelection = tab, true
    self:setContentsFocused(false)
    if tab == 'pack' then self.pack:start() else self.pack:stop() end
    self:refreshHeader()
    self:Update()
end

---Log rows are sentences with item links: the Journal's mixed-case item
---template with date headers, not the uppercase menu template.
---@param list ZO_ParametricScrollList
function LogScreen:SetupList(list)
    ZO_Gamepad_ParametricList_Screen.SetupList(self, list)
    list:AddDataTemplate(LOG_TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader(LOG_TEMPLATE, ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, nil, 'ZO_GamepadMenuEntryHeaderTemplate')
end

---@param focused boolean
function LogScreen:setContentsFocused(focused)
    if focused == (self.contentsFocused == true) then return end
    self.contentsFocused = focused
    if focused then
        self:DeactivateCurrentList()
        self:OnTargetChanged(self:GetMainList(), self:GetMainList():GetTargetData())
        self.contentsPanel:setActive(true)
    else
        self.contentsPanel:setActive(false)
        self:ActivateCurrentList()
        self:OnTargetChanged(self:GetMainList(), self:GetMainList():GetTargetData())
    end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
end

function LogScreen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local data = self:GetMainList():GetTargetData()
                return GetString(data and hasContents(data.logEntry) and BATTLESCROLLS_IPOC_VIEW_CONTENTS or SI_GAMEPAD_SELECT_OPTION)
            end,
            keybind = 'UI_SHORTCUT_PRIMARY',
            visible = function()
                local data = self:GetMainList():GetTargetData()
                return not self.contentsFocused and data and (data.buildChoice ~= nil or hasContents(data.logEntry))
            end,
            callback = function()
                local data = self:GetMainList():GetTargetData()
                if data and data.buildChoice then
                    BattleScrolls.inventoryPocBuilds.choose(data.buildChoice)
                    self:Update()
                elseif data and hasContents(data.logEntry) then
                    self:setContentsFocused(true)
                end
            end,
        },
        {
            -- After an automated guild-store visit the next ones open ESO's screen for a while.
            name = GetString(BATTLESCROLLS_IPOC_RESUME_TRADER),
            keybind = 'UI_SHORTCUT_SECONDARY',
            visible = function()
                return not self.contentsFocused and BattleScrolls.inventoryPocServiceUI.pauseRemaining() > 0
            end,
            callback = function()
                BattleScrolls.inventoryPocServiceUI.resumeGuildStore()
                self.traderPaused = false
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
            end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function()
        if self.contentsFocused then self:setContentsFocused(false)
        else SCENE_MANAGER:HideCurrentScene() end
    end)
end

function LogScreen:OnSelectionChanged()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
end

function LogScreen:OnTargetChanged(_list, selectedData)
    if self.updatingLog then return end
    resetTooltips()
    local entry = selectedData and selectedData.logEntry
    if entry ~= self.selectedLogEntry then
        self.selectedLogEntry = entry
        self:setContentsFocused(false)
    end
    if hasContents(entry) and self.contentsFocused then
        self.contentsPanel:show(entry)
        return
    end
    self.contentsPanel:hide()
    if not selectedData then return end
    if self.tab == 'pack' then self.pack:showTooltip(selectedData)
    elseif selectedData.logEntry then showLogTooltip(selectedData.logEntry)
    elseif selectedData.buildChoice then
        local state = BattleScrolls.inventoryPocBuilds.state()
        if state and state.choice == selectedData.buildChoice and state.issue then
            GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP,
                GetString(state.status == 'wardrobe' and BATTLESCROLLS_IPOC_WAIT_WARDROBE or BATTLESCROLLS_IPOC_RETRY_BUILD),
                buildIssueDetails(state.issue))
        end
    end
end

---@param list ZO_ParametricScrollList
---@param selected table|nil The entry selected before the refresh
---@return number|nil selectedIndex
function LogScreen:populateActivity(list, selected)
    local selectedIndex
    local row = 0
    local builds = BattleScrolls.inventoryPocBuilds
    local state = builds.state()
    local statusLabels = { bank = BATTLESCROLLS_IPOC_VISIT_BANK, armory = BATTLESCROLLS_IPOC_VISIT_ARMORY,
        wardrobe = BATTLESCROLLS_IPOC_WAIT_WARDROBE, done = BATTLESCROLLS_IPOC_READY,
        paused = BATTLESCROLLS_IPOC_RETRY_BUILD, missing = BATTLESCROLLS_IPOC_MISSING_BUILD }
    if state then
        for index, profile in ipairs(builds.profiles) do
            local isSelected = state.choice == profile.id
            local data = ZO_GamepadEntryData:New(GetString(profile.label), isSelected and SELECTED_ICON or nil)
            data.buildChoice = profile.id
            data:AddSubLabel(profile.armoryName .. ' · ' .. profile.pageName)
            if isSelected then
                data:AddSubLabel(state.status == 'wardrobe' and state.issue and buildIssueText(state.issue)
                    or GetString(statusLabels[state.status]))
            end
            if index == 1 then
                data:SetHeader(GetString(BATTLESCROLLS_TAB_BUILD))
                list:AddEntryWithHeader('ZO_GamepadMenuEntryTemplate', data)
            else
                list:AddEntry('ZO_GamepadMenuEntryTemplate', data)
            end
            row = row + 1
        end
    end
    local log = poc.saved and poc.saved.log or {}
    local currentHeader
    for index = #log, 1, -1 do
        local entry = log[index]
        local data = ZO_GamepadEntryData:New(poc.formatLog(entry))
        data.logEntry = entry
        data:AddSubLabel(utils.formatTime(entry.timestamp) .. ' · ' .. entry.character)
        data:SetNew(entry.unread == true)
        local header = BattleScrolls.journal.utils.getTimeGroupHeader(entry.timestamp)
        if header ~= currentHeader then
            currentHeader = header
            data:SetHeader(header)
            list:AddEntryWithHeader(LOG_TEMPLATE, data)
        else
            list:AddEntry(LOG_TEMPLATE, data)
        end
        row = row + 1
        if selected and selected.logEntry == entry then selectedIndex = row end
    end
    if selected and selected.buildChoice and state then
        for index, profile in ipairs(builds.profiles) do
            if profile.id == selected.buildChoice then selectedIndex = index; break end
        end
    end
    return selectedIndex
end

function LogScreen:PerformUpdate()
    self.updatingLog = true
    local list = self:GetMainList()
    local selected = not self.resetSelection and list:GetTargetData() or nil
    list:Clear()
    local selectedIndex
    if self.tab == 'pack' then
        list:SetNoItemText(GetString(BATTLESCROLLS_IPOC_PACK_READING))
        selectedIndex = self.pack:populate(list, selected)
    else
        list:SetNoItemText(GetString(BATTLESCROLLS_IPOC_EMPTY))
        selectedIndex = self:populateActivity(list, selected)
    end
    list:Commit()
    if self.resetSelection then selectedIndex = selectedIndex or 1 end
    self.resetSelection = nil
    -- An empty list has no row to select: ESO's list raises there, before it switches its animation back on.
    if selectedIndex and not list:IsEmpty() then list:SetSelectedIndexWithoutAnimation(selectedIndex) end
    self.updatingLog = false
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    self:OnTargetChanged(list, list:GetTargetData())
    self.logRevision, self.buildKey = poc.revision, buildKey()
    self.dirty = false
end

function LogScreen:OnShowing()
    if poc.saved then poc.saved.unread = false end
    ui.refreshNewness()
    self.dirty = true
    if self.tab == 'pack' then self.pack:start() end
    self:refreshHeader()
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    ZO_GamepadGenericHeader_Activate(self.header)
    self.traderPaused = BattleScrolls.inventoryPocServiceUI.pauseRemaining() > 0
    EVENT_MANAGER:RegisterForUpdate(SCENE_NAME, 250, function()
        -- The pause runs out while the screen is open: its keybind leaves with it.
        local paused = BattleScrolls.inventoryPocServiceUI.pauseRemaining() > 0
        if paused ~= self.traderPaused then
            self.traderPaused = paused
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
        if self.tab == 'pack' then self.pack:update()
        elseif self.logRevision ~= poc.revision or self.buildKey ~= buildKey() then self:Update() end
    end)
end

function LogScreen:OnHiding()
    EVENT_MANAGER:UnregisterForUpdate(SCENE_NAME)
    -- Problems shown during this visit lose their marker on the next opening.
    for _, entry in ipairs(poc.saved and poc.saved.log or {}) do entry.unread = nil end
    self.contentsFocused, self.selectedLogEntry = false, nil
    self.contentsPanel:hide()
    self.pack:stop()
    ZO_GamepadGenericHeader_Deactivate(self.header)
    resetTooltips()
    ZO_Gamepad_ParametricList_Screen.OnHiding(self)
end

local function createScreen()
    local control = BattleScrollsInventoryPocLog
    local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(GAMEPAD_GENERIC_FOOTER_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(ZO_FadeSceneFragment:New(control))
    screen = LogScreen.new(control, scene)
    screen.headerData = { tabBarEntries = {
        { text = GetString(BATTLESCROLLS_IPOC_TAB_ACTIVITY), callback = function() screen:setTab('activity') end },
        { text = GetString(BATTLESCROLLS_IPOC_TAB_PACK), callback = function() screen:setTab('pack') end },
    } }
    -- Building the tab bar selects its first tab; that is already the screen's state.
    local BLOCK_TAB_CALLBACKS = true
    ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData, BLOCK_TAB_CALLBACKS)
    -- The base screen activates the list during SCENE_SHOWING. Activating it
    -- here attaches its temporary fragment and input to the currently open UI.
end

function ui.refreshNewness()
    if MAIN_MENU_GAMEPAD then MAIN_MENU_GAMEPAD:MarkNewnessDirty() end
end

---@param enabled boolean
function ui.setEnabled(enabled)
    BattleScrolls.inventoryPocWorkUI.setEnabled(enabled)
    if enabled then BattleScrolls.inventoryPocUseUI.initialize() end
    BattleScrolls.inventoryPocHUD.setEnabled(enabled)
    if enabled and not menuEntry then
        if not screen then createScreen() end
        local function isNew()
            return poc.saved and poc.saved.unread == true
        end
        local title = GetString(BATTLESCROLLS_IPOC_TITLE)
        local icon = 'BattleScrolls/art/your_pack_menu_bgra.dds'
        menuEntry = ZO_GamepadEntryData:New(title, icon, nil, nil, isNew)
        menuEntry:SetIconTintOnSelection(true)
        menuEntry:SetIconDisabledTintOnSelection(true)
        menuEntry.data = { name = title, icon = icon, scene = SCENE_NAME, isNewCallback = isNew }
        menuEntry.id = 997
        menuParent = ZO_MENU_ENTRIES
        for _, entry in ipairs(ZO_MENU_ENTRIES) do
            if entry.id == ZO_MENU_MAIN_ENTRIES.JOURNAL and entry.subMenu then menuParent = entry.subMenu; break end
        end
        -- The journal and inventory helper initialize independently. Insert
        -- before an existing journal entry; if it loads later, it appends below.
        local position = #menuParent + 1
        for index, entry in ipairs(menuParent) do
            if entry.data and entry.data.scene == 'battleScrollsJournalGamepad' then position = index; break end
        end
        table.insert(menuParent, position, menuEntry)
    elseif not enabled and menuEntry then
        for index, entry in ipairs(menuParent) do
            if entry == menuEntry then table.remove(menuParent, index); break end
        end
        menuEntry = nil
        if SCENE_MANAGER:IsShowing(SCENE_NAME) then SCENE_MANAGER:Hide(SCENE_NAME) end
    end
    if MAIN_MENU_GAMEPAD then MAIN_MENU_GAMEPAD:RefreshLists(); MAIN_MENU_GAMEPAD:UpdateEntryEnabledStates() end
end

function ui.show()
    if poc.enabled then SCENE_MANAGER:Show(SCENE_NAME) end
end
