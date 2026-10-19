---@diagnostic disable: undefined-field, inject-field -- ESO Control/ZO_* stubs do not describe native UI fields completely
if not SemisPlaygroundCheckAccess() then return end

local poc = BattleScrolls.inventoryPoc
local SCENE_NAME = 'battleScrollsInventoryPoc'
local ICON = 'EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds'
local SELECTED_ICON = 'EsoUI/Art/Miscellaneous/Gamepad/gp_checkmark.dds'

---@class InventoryPocUI
local ui = {}
BattleScrolls.inventoryPocUI = ui

-- Posting through the API does not enter the native create-listing dialog,
-- whose close path normally refreshes the sell keybind's occupied-slot count.
-- Refresh only presentation: leave native callbacks and dialogs untouched.
function ui.refreshTradingHouse()
    if GetInteractionType() ~= INTERACTION_TRADINGHOUSE then return end
    if IsInGamepadPreferredMode() then
        if GAMEPAD_TRADING_HOUSE_SELL then GAMEPAD_TRADING_HOUSE_SELL:UpdateKeybind() end
    elseif TRADING_HOUSE then
        TRADING_HOUSE:UpdateListingCounts()
    end
end

local screen, menuEntry, menuParent
---@class InventoryPocLogScreen: ZO_Object
---@field logRevision number
---@field buildKey string
local LogScreen = ZO_Gamepad_ParametricList_Screen:Subclass()

local REASONS = {
    reserved = BATTLESCROLLS_IPOC_REASON_RESERVED, stolen = BATTLESCROLLS_IPOC_REASON_STOLEN,
    crown = BATTLESCROLLS_IPOC_REASON_CROWN, junk = BATTLESCROLLS_IPOC_REASON_JUNK,
    glyph = BATTLESCROLLS_IPOC_REASON_GLYPH, material = BATTLESCROLLS_IPOC_REASON_MATERIAL,
    gear = BATTLESCROLLS_IPOC_REASON_GEAR, knowledge = BATTLESCROLLS_IPOC_REASON_KNOWLEDGE,
    price = BATTLESCROLLS_IPOC_REASON_PRICE, companion = BATTLESCROLLS_IPOC_REASON_COMPANION,
    container = BATTLESCROLLS_IPOC_REASON_CONTAINER, supplies = BATTLESCROLLS_IPOC_REASON_SUPPLIES,
    unassigned = BATTLESCROLLS_IPOC_REASON_UNASSIGNED, learn = BATTLESCROLLS_IPOC_REASON_LEARN,
    valuablePlan = BATTLESCROLLS_IPOC_REASON_VALUABLE_PLAN, duplicate = BATTLESCROLLS_IPOC_REASON_DUPLICATE,
    sale = BATTLESCROLLS_IPOC_REASON_SALE,
}

local function resetTooltips()
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
end

---@param bag number
---@return string
local function bagName(bag)
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
    local lines = { os.date('%d %b %H:%M:%S', entry.timestamp), entry.character }
    local function add(id, ...)
        lines[#lines + 1] = zo_strformat(GetString(id), ...)
    end
    if entry.reason and REASONS[entry.reason] then
        add(BATTLESCROLLS_IPOC_DETAIL_REASON, GetString(REASONS[entry.reason]))
    end
    if entry.setupName then lines[#lines + 1] = entry.setupName end
    if entry.buildIssue then lines[#lines + 1] = buildIssueDetails(entry.buildIssue) end
    if entry.itemLink ~= '' then
        local link = entry.itemLink
        local itemType, specializedType = GetItemLinkItemType(link)
        add(BATTLESCROLLS_IPOC_DETAIL_QUANTITY, entry.quantity)
        add(BATTLESCROLLS_IPOC_DETAIL_FROM, bagName(entry.fromBag))
        if entry.toBag then add(BATTLESCROLLS_IPOC_DETAIL_TO, bagName(entry.toBag)) end
        add(BATTLESCROLLS_IPOC_DETAIL_ITEM_ID, entry.itemId)
        add(BATTLESCROLLS_IPOC_DETAIL_TYPE, GetString('SI_ITEMTYPE', itemType), itemType,
            GetString('SI_SPECIALIZEDITEMTYPE', specializedType), specializedType)
        local quality = GetItemLinkFunctionalQuality(link)
        add(BATTLESCROLLS_IPOC_DETAIL_QUALITY, GetString('SI_ITEMQUALITY', quality), quality)
        local trait = GetItemLinkTraitInfo(link)
        if trait ~= ITEM_TRAIT_TYPE_NONE then
            add(BATTLESCROLLS_IPOC_DETAIL_TRAIT, GetString('SI_ITEMTRAITTYPE', trait), trait)
        end
        local style = GetItemLinkItemStyle(link)
        if style > 0 then add(BATTLESCROLLS_IPOC_DETAIL_STYLE, GetItemStyleName(style), style) end
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(link, false)
        if hasSet then add(BATTLESCROLLS_IPOC_DETAIL_SET, setName, setId) end
        local details = entry.details
        if details then
            add(BATTLESCROLLS_IPOC_DETAIL_STACK, details.stack)
            add(BATTLESCROLLS_IPOC_DETAIL_SLOT, details.slot, details.uniqueId)
            lines[#lines + 1] = ''
            add(BATTLESCROLLS_IPOC_DETAIL_PRICES)
            add(BATTLESCROLLS_IPOC_DETAIL_VENDOR, details.vendorUnit)
            if details.marketUnit then add(BATTLESCROLLS_IPOC_DETAIL_MARKET, details.marketUnit) end
            -- Older entries also saved style-material quotes for glyphs and
            -- other items that cannot return smithing materials.
            local playerGear = (itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON)
                and GetItemLinkActorCategory(link) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION
            if playerGear then
                for _, material in ipairs({
                    { link = details.styleMaterialLink, price = details.styleMaterialUnit },
                    { link = details.traitMaterialLink, price = details.traitMaterialUnit },
                }) do
                    if material.link ~= '' then
                        if material.price then add(BATTLESCROLLS_IPOC_DETAIL_MATERIAL, material.link, material.price)
                        else add(BATTLESCROLLS_IPOC_DETAIL_UNPRICED, material.link) end
                    end
                end
            end
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
    ZO_Gamepad_ParametricList_Screen.Initialize(object, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, true, scene)
    object:SetListsUseTriggerKeybinds(true)
    return object
end

function LogScreen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_GAMEPAD_SELECT_OPTION), keybind = 'UI_SHORTCUT_PRIMARY',
            visible = function() local data = self:GetMainList():GetTargetData(); return data and data.buildChoice ~= nil end,
            callback = function()
                local data = self:GetMainList():GetTargetData()
                if data and data.buildChoice then
                    BattleScrolls.inventoryPocBuilds.choose(data.buildChoice)
                    self:Update()
                end
            end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end

function LogScreen:OnSelectionChanged()
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
end

function LogScreen:OnTargetChanged(_list, selectedData)
    resetTooltips()
    if not selectedData then return end
    if selectedData.logEntry then showLogTooltip(selectedData.logEntry)
    elseif selectedData.buildChoice then
        local state = BattleScrolls.inventoryPocBuilds.state()
        if state and state.choice == selectedData.buildChoice and state.issue then
            GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP,
                GetString(state.status == 'wardrobe' and BATTLESCROLLS_IPOC_WAIT_WARDROBE or BATTLESCROLLS_IPOC_RETRY_BUILD),
                buildIssueDetails(state.issue))
        end
    end
end

function LogScreen:PerformUpdate()
    local list = self:GetMainList()
    local selected, selectedIndex = list:GetTargetData(), nil
    local row = 0
    list:Clear()
    local builds = BattleScrolls.inventoryPocBuilds
    local state = builds.state()
    local statusLabels = { bank = BATTLESCROLLS_IPOC_VISIT_BANK, armory = BATTLESCROLLS_IPOC_VISIT_ARMORY,
        wardrobe = BATTLESCROLLS_IPOC_WAIT_WARDROBE, done = BATTLESCROLLS_IPOC_READY,
        paused = BATTLESCROLLS_IPOC_RETRY_BUILD, missing = BATTLESCROLLS_IPOC_MISSING_BUILD }
    if state then
        for _, profile in ipairs(builds.profiles) do
            local isSelected = state.choice == profile.id
            local data = ZO_GamepadEntryData:New(GetString(profile.label), isSelected and SELECTED_ICON or nil)
            data.buildChoice = profile.id
            data:AddSubLabel(profile.armoryName .. ' · ' .. profile.pageName)
            if isSelected then
                data:AddSubLabel(state.status == 'wardrobe' and state.issue and buildIssueText(state.issue)
                    or GetString(statusLabels[state.status]))
            end
            list:AddEntry('ZO_GamepadMenuEntryTemplate', data)
            row = row + 1
        end
    end
    local log = poc.saved and poc.saved.log or {}
    for index = #log, 1, -1 do
        local entry = log[index]
        local data = ZO_GamepadEntryData:New(poc.formatLog(entry))
        data.logEntry = entry
        data:AddSubLabel(os.date('%d %b %H:%M', entry.timestamp) .. ' · ' .. entry.character)
        list:AddEntry('ZO_GamepadMenuEntryTemplate', data)
        row = row + 1
        if selected and selected.logEntry == entry then selectedIndex = row end
    end
    if #log == 0 then
        list:AddEntry('ZO_GamepadMenuEntryTemplate', ZO_GamepadEntryData:New(GetString(BATTLESCROLLS_IPOC_EMPTY)))
    end
    list:Commit()
    if selected and selected.buildChoice and state then
        for index, profile in ipairs(builds.profiles) do
            if profile.id == selected.buildChoice then selectedIndex = index; break end
        end
    end
    if selectedIndex then list:SetSelectedIndexWithoutAnimation(selectedIndex) end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    self:OnTargetChanged(list, list:GetTargetData())
    self.logRevision, self.buildKey = poc.revision, buildKey()
    self.dirty = false
end

function LogScreen:OnShowing()
    if poc.saved then poc.saved.unread = false end
    ui.refreshNewness()
    self.dirty = true
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
    EVENT_MANAGER:RegisterForUpdate(SCENE_NAME, 250, function()
        if self.logRevision ~= poc.revision or self.buildKey ~= buildKey() then self:Update() end
    end)
end

function LogScreen:OnHiding()
    EVENT_MANAGER:UnregisterForUpdate(SCENE_NAME)
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
    screen.headerData = { titleText = GetString(BATTLESCROLLS_IPOC_TITLE) }
    ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData)
    -- The base screen activates the list during SCENE_SHOWING. Activating it
    -- here attaches its temporary fragment and input to the currently open UI.
end

function ui.refreshNewness()
    if MAIN_MENU_GAMEPAD then MAIN_MENU_GAMEPAD:MarkNewnessDirty() end
end

---@param enabled boolean
function ui.setEnabled(enabled)
    BattleScrolls.inventoryPocInspect.setEnabled(enabled)
    if enabled and not menuEntry then
        if not screen then createScreen() end
        local function isNew()
            return poc.saved and poc.saved.unread == true
        end
        local title = GetString(BATTLESCROLLS_IPOC_TITLE)
        menuEntry = ZO_GamepadEntryData:New(title, ICON, nil, nil, isNew)
        menuEntry:SetIconTintOnSelection(true)
        menuEntry:SetIconDisabledTintOnSelection(true)
        menuEntry.data = { name = title, icon = ICON, scene = SCENE_NAME, isNewCallback = isNew }
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
