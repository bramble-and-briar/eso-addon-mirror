-- Tamriel Collections - Antiquities starter v0.1.0
-- Registers the standalone module in the shared family. Collection features
-- are intentionally left for a later release.
local TC = TamrielCollections
local MODULE_ID = 'antiquities'
local DISPLAY_NAME = 'Antiquities'

local function ShowStarter(screen, data)
    local category = TC:GetArchiveCategory(MODULE_ID)
    screen:ShowUnavailableCategory(data, category)
    if screen.moduleUnavailableTitle then
        screen.moduleUnavailableTitle:SetText(zo_strupper(DISPLAY_NAME))
    end
    if screen.moduleUnavailableBody then
        screen.moduleUnavailableBody:SetText(
            'Starter module installed.\n\nCollection data is not available in this starter version.')
    end
end

local function InstallStarterBack(screen)
    screen._tcStarterBackHooks = screen._tcStarterBackHooks or {}
    if screen._tcStarterBackHooks[MODULE_ID] then return end
    for _, descriptor in ipairs(screen.keybindStripDescriptor or {}) do
        if descriptor.keybind == 'UI_SHORTCUT_NEGATIVE' then
            local original = descriptor.callback
            descriptor.callback = function()
                if screen.mode == 'starter' and screen.activeModuleId == MODULE_ID then
                    screen:ShowCategories()
                elseif original then
                    return original()
                end
            end
            screen._tcStarterBackHooks[MODULE_ID] = true
            return
        end
    end
end

TC:RegisterArchiveModule(MODULE_ID, {
    displayName = DISPLAY_NAME,
    addonName = 'Tamriel Collections - Archive Antiquities',
    assetRoot = 'TamrielCollectionsAntiquities',
    screenControl = 'TCAQuestJournalTL',
    version = 101,
    supportsSearch = false,
    starter = true,
    onCategoryFocus = function(screen, data)
        InstallStarterBack(screen)
        ShowStarter(screen, data)
    end,
    open = function(screen)
        InstallStarterBack(screen)
        screen.activeModuleId = MODULE_ID
        screen.mode = 'starter'
        screen.styleList:Clear()
        screen.styleList:Commit()
        screen:SetCurrentList(screen.styleList)
        ShowStarter(screen)
        screen:RefreshKeybinds()
    end,
})

-- Shared layout: included in every standalone Archive module; initialized once.
do
local TC = TamrielCollections
if not TC.archiveLayout or TC.archiveLayout.version < 1101 then
-- Shared Archives layout derived from the approved Motifs v1.1.1: a separate scene-owned background plane keeps the
-- native masked menus, search controls, emblem and panel rails unobscured.
-- Geometry is measured
-- against GuiRoot because ESO narrows the native scene owner to quadrant 1.
local Pilot = { version = 1101, modules = {} }
TC.archiveLayout = Pilot
local function Current(screen)
    local id
    if screen.mode == 'categories' then
        local data = screen.categoryList and screen.categoryList:GetTargetData()
        id = data and data.categoryKey
    elseif screen.mode == 'styles' or screen.mode == 'details' or screen.mode == 'starter' then
        id = screen.activeModuleId
    end
    return id and Pilot.modules[id]
end
local function IsArchive(screen) return Current(screen) ~= nil end
local function Capture(control)
    local saved = { anchors = {}, width = control:GetWidth(), height = control:GetHeight(), hidden = control:IsHidden(), parent = control:GetParent() }
    for index = 0, control:GetNumAnchors() - 1 do
        local valid, point, relative, relativePoint, x, y, constrains = control:GetAnchor(index)
        if valid then saved.anchors[#saved.anchors + 1] = { point, relative, relativePoint, x, y, constrains } end
    end
    if control.GetAutoRectClipChildren then saved.clip = control:GetAutoRectClipChildren() end
    if control.GetDrawLayer then saved.layer = control:GetDrawLayer() end
    if control.GetDrawLevel then saved.level = control:GetDrawLevel() end
    if control.GetFont then saved.font = control:GetFont() end
    return saved
end
local function RestoreControl(control, saved)
    if saved.parent and control:GetParent() ~= saved.parent then control:SetParent(saved.parent) end
    control:ClearAnchors()
    control:SetDimensions(saved.width, saved.height)
    for _, anchor in ipairs(saved.anchors) do
        control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5], anchor[6])
    end
    control:SetHidden(saved.hidden)
    if saved.clip ~= nil and control.SetAutoRectClipChildren then control:SetAutoRectClipChildren(saved.clip) end
    if saved.layer ~= nil then control:SetDrawLayer(saved.layer) end
    if saved.level ~= nil then control:SetDrawLevel(saved.level) end
    if saved.font then control:SetFont(saved.font) end
end
local moved = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'collectionsHeaderLogo', 'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop',
    'motifSearchControl', 'styleListContainer', 'detailControl', 'detailHeading', 'detailAcquisition',
    'detailWhereTitle', 'detailLocation', 'detailSource', 'detailAchievement', 'detailIcon',
    'moduleUnavailableTitle', 'moduleUnavailableBody' }
local hiddenLines = { 'collectionsHeaderLine', 'collectionsLogoBottomLine', 'collectionsMenuBottomLine',
    'detailTopLine', 'detailBottomLine', 'motifSearchLine', 'motifSearchBackdrop' }
local function Bounds(screen)
    local owner, root = screen.control, GuiRoot or screen.control
    if not owner or not root or not root.GetLeft or not screen.middle or not screen.right then return end
    local left, top, width, height = root:GetLeft(), root:GetTop(), root:GetWidth(), root:GetHeight()
    if not (left and top and width and height and width > 600 and height > 400) then return end
    local middle, right = screen.middle:GetLeft() - left, screen.right:GetLeft() - left
    if not (middle > 100 and right > middle + 100 and right < width - 100) then return end
    local alley = ZO_GAMEPAD_ALLEY_WIDTH or 10
    local panelLeft = math.max(0, middle - screen.right:GetWidth() - alley)
    local panelRight = math.min(width, screen.right.GetRight and screen.right:GetRight() - left or width)
    local middleEnd = math.min(right - alley, screen.middle.GetRight and screen.middle:GetRight() - left or right - alley)
    local texture = ZO_KeybindStripGamepadBackgroundTexture
    local keybindHeight = texture and texture.GetHeight and texture:GetHeight() or ZO_GAMEPAD_KEYBIND_STRIP_BACKGROUND_HEIGHT or 128
    local footer = texture and texture.GetTop and texture:GetTop() - top or height - keybindHeight
    if not footer or footer <= height / 2 or footer > height then footer = height - keybindHeight end
    footer = footer - 16
    -- All columns share a title baseline and two narrow gold rules. Keep the
    -- left menu and chapter-list divider aligned, leaving the middle list open.
    local titleTop = math.max(24, ZO_GAMEPAD_SAFE_ZONE_INSET_Y or 54) + 8
    local first, second = titleTop + 56, titleTop + 216
    local listTop, lower = second + 18, footer - 234
    if lower - listTop < 314 then return end
    return { root = root, owner = owner, width = width, height = height,
        left = panelLeft, leftEnd = middle - alley, middle = middle, middleEnd = middleEnd,
        right = right, edge = panelRight, titleTop = titleTop, first = first,
        second = second, listTop = listTop, lower = lower, footer = footer }
end
local function Place(control, b, left, right, top, height)
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, b.root, TOPLEFT, left, top)
    control:SetAnchor(TOPRIGHT, b.root, TOPLEFT, right, top)
    control:SetHeight(height)
end
local function Foreground(control)
    if not control then return end
    control:SetDrawLayer(DL_CONTROLS)
    control:SetDrawLevel(90)
end
local function NewControl(state, name, kind, level)
    local isBackground = name == 'Backdrop' or name == 'FooterFill' or name == 'HeaderShade'
    local parent = isBackground and state.backgroundRoot or state.bounds.owner
    local control = WINDOW_MANAGER:CreateControl('TCArchiveLayout' .. name, parent, kind)
    if DT_LOW then control:SetDrawTier(DT_LOW) end
    control:SetDrawLayer(isBackground and DL_BACKGROUND or DL_CONTROLS)
    control:SetDrawLevel(isBackground and 0 or level)
    control:SetHidden(true)
    return control
end
local function MakeControls(state, screen)
    if state.controls then return end
    local c = {}; state.controls = c
    -- Scroll masks and top-level windows compose their descendants as a group.
    -- Raising a label cannot place it above an opaque sibling in another
    -- composed layer. Keep the paint in a distinct, lower background window.
    local background = WINDOW_MANAGER:CreateTopLevelWindow('TCArchiveBackgroundWindow')
    background:SetHidden(true)
    background:SetMouseEnabled(false)
    background:SetDrawTier(DT_LOW)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetDrawLevel(0)
    state.backgroundRoot = background
    state.backgroundFragment = ZO_SimpleSceneFragment:New(background)
    state.backgroundFragment:SetConditional(function() return state.active == true and IsArchive(screen) end)
    screen.scene:AddFragment(state.backgroundFragment)
    -- A near-solid tint retains a faint glimpse of the world beneath the
    -- native gamepad panels, while keeping collection text readable.
    c.Backdrop = NewControl(state, 'Backdrop', CT_TEXTURE, 10)
    c.Backdrop:SetColor(32 / 255, 37 / 255, 38 / 255, 0.72)
    c.FooterFill = NewControl(state, 'FooterFill', CT_TEXTURE, 11)
    c.FooterFill:SetColor(36 / 255, 40 / 255, 40 / 255, 1)
    c.FooterRule = NewControl(state, 'FooterRule', CT_TEXTURE, 20)
    c.FooterRule:SetColor(145 / 255, 137 / 255, 112 / 255, 1)
    c.HeaderShade = NewControl(state, 'HeaderShade', CT_TEXTURE, 15)
    c.HeaderShade:SetColor(0.015, 0.02, 0.02, 0.24)
    for _, name in ipairs({ 'TitleRule', 'HeaderRule', 'MenuRule', 'SourceRule' }) do
        local line = NewControl(state, name, CT_TEXTURE, 20)
        -- The native divider fades toward its ends. A solid two-unit rule
        -- spans the exact panel bounds without fading or stretching an image.
        line:SetColor(224 / 255, 191 / 255, 124 / 255, 1)
        c[name] = line
    end
    for _, name in ipairs({ 'ArchivesTitle', 'ModuleTitle', 'DetailsTitle', 'StarterHint' }) do
        local label = NewControl(state, name, CT_LABEL, 90)
        label:SetFont(name == 'StarterHint' and 'ZoFontGamepad25' or 'ZoFontGamepadBold34')
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if name == 'StarterHint' then label:SetColor(0.72, 0.72, 0.68, 1)
        else label:SetColor(244 / 255, 225 / 255, 182 / 255, 1) end
        c[name] = label
    end
    c.ModuleEmblem = NewControl(state, 'ModuleEmblem', CT_TEXTURE, 90)
    c.ModuleEmblem:SetColor(244 / 255, 225 / 255, 182 / 255, 0.45)
    c.ContextHint = NewControl(state, 'ContextHint', CT_LABEL, 90)
    c.ContextHint:SetFont('ZoFontGamepad25')
    c.ContextHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    c.ContextHint:SetColor(0.72, 0.72, 0.68, 1)
    c.ContextHint:SetText('Collection overview')
    c.ArchivesTitle:SetText('TAMRIEL ARCHIVES')
    c.ModuleTitle:SetText('MOTIFS')
    c.DetailsTitle:SetText('DETAILS')
    c.StarterHint:SetText('Choose a motif to view its chapters,\ncollection progress and sources.')
end
local function HideNative(screen)
    for _, name in ipairs(hiddenLines) do if screen[name] then screen[name]:SetHidden(true) end end
end
function Pilot.Restore(screen)
    local state = screen._tcArchiveLayout
    if not state then return end
    state.generation = (state.generation or 0) + 1
    state.pending, state.attempts = nil, 0
    local wasActive = state.active
    state.active = false
    if state.backgroundFragment then state.backgroundFragment:Refresh() end
    if not wasActive then return end
    for list, offset in pairs(state.listOffsets or {}) do
        list:SetFixedCenterOffset(offset)
    end
    state.listOffsets = nil
    for control, saved in pairs(state.saved) do RestoreControl(control, saved) end
    for _, control in pairs(state.controls or {}) do control:SetHidden(true) end
    if state.ownerLayer ~= nil then screen.control:SetDrawLayer(state.ownerLayer) end
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, screen.headerData or { titleText = 'TAMRIEL ARCHIVES' })
    end
    state.saved = nil
end
function Pilot.Apply(screen)
    local config = Current(screen)
    if not config or screen._tcArchiveLayoutHidden then return false end
    -- Motifs v1.1.1 owns its approved layout independently. Restore it before
    -- capturing native controls for another module, regardless of load order.
    local motifsState = screen._tcmLayoutPilot
    if motifsState and not motifsState.active and motifsState.saved then
        -- Its list-offset restoration fires keybind callbacks before it has
        -- restored the original parents. The enclosing category change will
        -- apply this layout once that restoration has fully completed.
        return false
    end
    if TC.motifLayoutPreview then TC.motifLayoutPreview.Restore(screen) end
    if screen._tcArchiveLayout and screen._tcArchiveLayout.active
        and screen._tcArchiveLayout.moduleId ~= config.id then Pilot.Restore(screen) end
    local state = screen._tcArchiveLayout
    if not state then state = {}; screen._tcArchiveLayout = state end
    local b = state.active and state.bounds or Bounds(screen)
    if not b then
        if zo_callLater and not state.pending and (state.attempts or 0) < 3 then
            state.pending, state.attempts = true, (state.attempts or 0) + 1
            local generation = state.generation or 0
            zo_callLater(function()
                if (state.generation or 0) ~= generation then return end
                state.pending = nil
                if IsArchive(screen) then Pilot.Apply(screen) end
            end, 33)
        end
        return false
    end
    if not state.active then
        state.bounds, state.saved, state.attempts = b, {}, 0
        state.ownerLayer = screen.control:GetDrawLayer()
        for _, name in ipairs(moved) do
            local control = screen[name]
            if control and control.GetNumAnchors then state.saved[control] = Capture(control) end
        end
        for _, row in ipairs(screen.fixedCategoryRows or {}) do state.saved[row] = Capture(row) end
        MakeControls(state, screen)
        state.active, state.moduleId = true, config.id
    end
    -- Explicitly separate the scene's content plane from its background plane.
    screen.control:SetDrawLayer(DL_CONTROLS)
    local c, starter = state.controls, screen.mode == 'categories' or screen.mode == 'starter'
    c.ModuleTitle:SetText(string.upper(config.name))
    c.StarterHint:SetText(config.hint)
    if not starter then screen:SetMotifContentVisible(true) end
    Place(state.backgroundRoot, b, 0, b.width, 0, b.height)
    Place(c.Backdrop, b, 0, b.width, 0, b.height)
    local keybindTop = b.footer + 16
    Place(c.FooterFill, b, 0, b.width, keybindTop, b.height - keybindTop)
    Place(c.FooterRule, b, 0, b.width, keybindTop, 2)
    Place(c.HeaderShade, b, b.left, b.edge, b.titleTop - 20, b.second - b.titleTop + 20)
    Place(c.TitleRule, b, b.left, b.edge, b.first, 2)
    Place(c.HeaderRule, b, b.left, b.edge, b.second, 2)
    Place(c.MenuRule, b, b.left, b.leftEnd, b.lower, 2)
    Place(c.SourceRule, b, b.right, b.edge, b.lower, 2)
    Place(c.ArchivesTitle, b, b.left + 12, b.leftEnd - 12, b.titleTop, 48)
    Place(c.ModuleTitle, b, b.middle + 12, b.middleEnd - 12, b.titleTop, 48)
    Place(c.DetailsTitle, b, b.right + 12, b.edge - 12, b.titleTop, 48)
    local category = TC.GetArchiveCategory and TC:GetArchiveCategory(config.id)
    local emblem = category and screen:GetCategoryIcon(category)
    if emblem then c.ModuleEmblem:SetTexture(emblem) end
    local emblemSize = math.min(128, b.footer - b.lower - 40)
    Place(c.ModuleEmblem, b, (b.left + b.leftEnd - emblemSize) / 2,
        (b.left + b.leftEnd + emblemSize) / 2, (b.lower + b.footer - emblemSize) / 2, emblemSize)
    Place(c.StarterHint, b, b.right + 28, b.edge - 28, (b.listTop + b.lower) / 2 - 48, 96)
    for _, control in pairs(c) do control:SetHidden(false) end
    c.StarterHint:SetHidden(not starter)
    c.ModuleEmblem:SetHidden(not emblem)
    c.ContextHint:SetHidden(config.search)
    if ZO_GamepadGenericHeader_Refresh and screen.header then
        ZO_GamepadGenericHeader_Refresh(screen.header, { titleText = '' })
    end
    local center = (b.first + b.second) / 2
    Place(c.ContextHint, b, b.middle + 32, b.middleEnd - 32, center - 24, 48)
    if screen.collectionsHeaderLogo then
        -- The native header is a separately animated fragment. Its hidden
        -- state and scroll mask must not hide the fixed Archives artwork.
        screen.collectionsHeaderLogo:SetParent(b.owner)
        screen.collectionsHeaderLogo:SetHidden(false)
        screen.collectionsHeaderLogo:ClearAnchors()
        screen.collectionsHeaderLogo:SetDimensions(100, 100)
        screen.collectionsHeaderLogo:SetAnchor(CENTER, b.root, TOPLEFT, (b.left + b.leftEnd) / 2, center)
        Foreground(screen.collectionsHeaderLogo)
    end
    if screen.detailIcon then
        screen.detailIcon:ClearAnchors()
        screen.detailIcon:SetDimensions(100, 100)
        screen.detailIcon:SetAnchor(CENTER, b.root, TOPLEFT, (b.right + b.edge) / 2, center)
        Foreground(screen.detailIcon)
    end
    if screen.motifSearchControl then
        screen.motifSearchControl:ClearAnchors()
        screen.motifSearchControl:SetAnchor(CENTER, b.root, TOPLEFT, (b.middle + b.middleEnd) / 2, center)
        -- The same native search affordance is visible on the starter. Its
        -- existing Search shortcut opens the selected module and then focuses the edit box.
        screen.motifSearchControl:SetHidden(not config.search)
        Foreground(screen.motifSearchControl)
    end
    Place(screen.styleListContainer, b, b.middle + 8, b.middleEnd - 8, b.listTop, b.footer - b.listTop)
    Place(screen.detailControl, b, b.right + 8, b.edge - 8, b.listTop, b.lower - b.listTop - 12)
    for _, name in ipairs({ 'styleListContainer', 'detailControl' }) do
        if screen[name] and screen[name].SetAutoRectClipChildren then screen[name]:SetAutoRectClipChildren(true) end
    end
    -- Native vertical lists anchor the selected row at their center. Bring
    -- that anchor to the top of the viewport without moving the panel itself.
    state.listOffsets = state.listOffsets or {}
    for _, list in ipairs({ screen.styleList, screen.detailList }) do
        if list.SetFixedCenterOffset and list.GetControl then
            if state.listOffsets[list] == nil then
                state.listOffsets[list] = list.fixedCenterOffset or 0
            end
            list:SetFixedCenterOffset(8 - list:GetControl():GetHeight() / 2)
        end
    end
    Place(screen.detailHeading, b, b.right + 24, b.edge - 24, b.first + 20, 76)
    if screen.detailHeading then screen.detailHeading:SetFont('ZoFontGamepadBold27') end
    Place(screen.detailAcquisition, b, b.right + 24, b.edge - 24, b.first + 110, 30)
    Foreground(screen.detailHeading)
    Foreground(screen.detailAcquisition)
    Place(screen.detailWhereTitle, b, b.right + 24, b.edge - 24, b.lower + 10, 28)
    Place(screen.detailLocation, b, b.right + 24, b.edge - 24, b.lower + 42, 30)
    Place(screen.detailSource, b, b.right + 24, b.edge - 24, b.lower + 76, 88)
    Place(screen.detailAchievement, b, b.right + 24, b.edge - 24, b.lower + 170, 58)
    -- Retain foreground placement without changing native data, row templates,
    -- scrolling, search controls or controller bindings.
    for _, name in ipairs({ 'styleListContainer', 'detailControl', 'detailWhereTitle',
        'detailLocation', 'detailSource', 'detailAchievement',
        'moduleUnavailableTitle', 'moduleUnavailableBody' }) do Foreground(screen[name]) end
    local rows = screen.fixedCategoryRows or {}
    local spacing = #rows > 1 and math.min(80, (b.lower - b.listTop - 90) / (#rows - 1)) or 0
    for index, row in ipairs(rows) do
        -- Keep only the visuals outside the animated header. The invisible
        -- native category list retains all controller input and selection.
        row:SetParent(b.owner)
        row:SetHidden(false)
        row:ClearAnchors()
        row:SetAnchor(TOPLEFT, b.root, TOPLEFT, b.left + 44, b.listTop + 14 + (index - 1) * spacing)
        Foreground(row)
    end
    if starter then
        -- A single module heading above the search field identifies this page;
        -- preserve the native press-X prompt without repeating the heading.
        if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
        Place(screen.moduleUnavailableBody, b, b.middle + 32, b.middleEnd - 32,
            (b.listTop + b.lower) / 2 - 76, 152)
    end
    HideNative(screen)
    state.backgroundFragment:Refresh()
    return true
end

-- List refreshes can call selection/keybind callbacks synchronously. Keep a
-- single layout pass active and restore the guard even if native code errors.
local rawApply, rawRestore = Pilot.Apply, Pilot.Restore
function Pilot.Apply(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused then return false end
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawApply, screen)
    screen._tcArchiveLayoutBusy = nil
    if not ok then error(result) end
    return result
end
function Pilot.Restore(screen)
    local busy = screen._tcArchiveLayoutBusy
    screen._tcArchiveLayoutBusy = true
    local ok, result = pcall(rawRestore, screen)
    screen._tcArchiveLayoutBusy = busy
    if not ok then error(result) end
    return result
end
local function Sync(screen)
    if screen._tcArchiveLayoutBusy or screen._tcArchiveLayoutPaused or screen._tcArchiveLayoutHidden then return end
    if Current(screen) then Pilot.Apply(screen) else Pilot.Restore(screen) end
end
function Pilot.WatchLifecycle(screen)
    -- Modules install their reader/loading hooks on first open. Keep this
    -- observer outside the latest hooks: a reader's resume branch can return
    -- without calling an earlier OnShowing implementation.
    if screen.OnShowing ~= screen._tcArchiveLayoutOnShowing then
        local showing = screen.OnShowing
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = nil
            local result
            if showing then result = showing(self, ...) end
            Sync(self)
            return result
        end
        screen.OnShowing, screen._tcArchiveLayoutOnShowing = wrapper, wrapper
    end
    if screen.OnHiding ~= screen._tcArchiveLayoutOnHiding then
        local hiding = screen.OnHiding
        local wrapper = function(self, ...)
            self._tcArchiveLayoutHidden = true
            Pilot.Restore(self)
            if hiding then return hiding(self, ...) end
        end
        screen.OnHiding, screen._tcArchiveLayoutOnHiding = wrapper, wrapper
    end
end
function Pilot.BeforeShowing(screen)
    screen._tcArchiveLayoutHidden = nil
    Pilot.Install(screen)
    -- A standalone module must open on an installed category, rather than
    -- the disabled Motifs row inherited from the native shared menu.
    local selected = screen.categoryList and screen.categoryList:GetTargetData()
    if selected and TC:IsArchiveModuleInstalled(selected.categoryKey) then return end
    for index, category in ipairs(TC.archiveCategories or {}) do
        if TC:IsArchiveModuleInstalled(category.key) then
            screen.categoryList:SetSelectedIndex(index)
            break
        end
    end
end
function Pilot.Install(screen)
    if screen._tcArchiveLayoutInstalled then Pilot.WatchLifecycle(screen); return end
    screen._tcArchiveLayoutInstalled = true
    local category = screen.ShowCategory
    screen.ShowCategory = function(self, data)
        local state = self._tcArchiveLayout
        if state and state.active and (not data or data.categoryKey ~= state.moduleId) then Pilot.Restore(self) end
        local result = category(self, data)
        Sync(self)
        return result
    end
    local show = screen.ShowStyle
    screen.ShowStyle = function(self, data)
        if not Current(self) then Pilot.Restore(self) end
        local result = show(self, data)
        Sync(self)
        return result
    end
    local refresh = screen.RefreshKeybinds
    screen.RefreshKeybinds = function(self, ...)
        local result = refresh(self, ...)
        Sync(self)
        return result
    end
    Pilot.WatchLifecycle(screen)
end
function Pilot.Prompt(screen, data, config)
    screen:ShowUnavailableCategory(data, TC:GetArchiveCategory(config.id))
    if screen.moduleUnavailableTitle then screen.moduleUnavailableTitle:SetHidden(true) end
    if screen.moduleUnavailableBody then screen.moduleUnavailableBody:SetText(config.intro) end
    if screen.motifSearchFocus and screen.motifSearchFocus.GetEditBox then
        screen.motifSearchFocus:GetEditBox():SetDefaultText('Search ' .. config.name)
    end
    Pilot.Apply(screen)
end
function Pilot.Register(id, config)
    config.id = id
    local module = TC:GetArchiveModule(id)
    if not module then return end
    config.search = module.supportsSearch == true
    Pilot.modules[id] = config
    if module._tcArchiveLayoutWrapped then return end
    module._tcArchiveLayoutWrapped = true
    local focus, open = module.onCategoryFocus, module.open
    module.onCategoryFocus = function(screen, data)
        Pilot.Install(screen)
        Pilot.Prompt(screen, data, config)
    end
    module.open = function(screen)
        Pilot.Install(screen)
        -- Style Pages previously populated on focus. Defer that exact native
        -- catalogue routine to X; the other modules prepare themselves on open.
        local paused = screen._tcArchiveLayoutPaused
        screen._tcArchiveLayoutPaused = true
        local ok, result = pcall(function()
            if config.prepareOnOpen and focus then focus(screen) end
            if open then return open(screen) end
        end)
        screen._tcArchiveLayoutPaused = paused
        if not ok then error(result) end
        Pilot.WatchLifecycle(screen)
        Pilot.Apply(screen)
        return result
    end
end

end
TC.archiveLayout.Register("antiquities", { name = "Antiquities", intro = "Explore Tamriel's buried history.\nOpen the Antiquities archive overview.\n\nPress X to open Antiquities.", hint = "Antiquities archive overview.\nCollection data will be added in a later update." })
end
