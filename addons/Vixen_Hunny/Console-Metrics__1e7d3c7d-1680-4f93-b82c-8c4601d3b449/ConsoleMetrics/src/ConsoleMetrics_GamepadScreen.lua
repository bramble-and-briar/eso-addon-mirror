-- ConsoleMetrics_GamepadScreen.lua
-- ConsoleMetrics' own gamepad screen for the fight viewer (console, and PC in
-- gamepad mode).
--
-- The viewer used to borrow the LibHarvensAddonSettings settings screen. That
-- screen owns the Back button, hides itself on Back and rebuilds its list in
-- its own way, which made navigation unreliable. This file gives the viewer a
-- screen of its own, built on the base game's ZO_Gamepad_ParametricList_Screen
-- (the same base LibHarvensAddonSettings uses), so ConsoleMetrics controls:
--
--   * page history   - opening a page remembers where you came from;
--                      B / Back rows go back one page, Y goes to Main Menu,
--                      B on Main closes the viewer,
--   * the list       - rebuilt in place, cursor kept on the same row,
--   * the keybinds   - A = row action, B = Back, Y = Main Menu,
--                      LB / RB = older / newer fight, X = Live.
--
-- Panels are unchanged: they still describe their rows through
-- dialog:AddSetting(params) with LibHarvensAddonSettings-style params. The
-- RowCollector below turns those params into list entries.

local CM = ConsoleMetrics

local SCENE_NAME = "ConsoleMetricsFightViewer"
local ROW_TEMPLATE = "ZO_GamepadOptionsLabelRow"
local SECTION_TEMPLATE = "ZO_Options_SectionTitle_WithDivider"

-- Row types (same numbers LibHarvensAddonSettings uses).
local ST = {
    CHECKBOX = 1, SLIDER = 2, EDIT = 3, DROPDOWN = 4, COLOR = 5,
    BUTTON = 6, LABEL = 7, SECTION = 8, ICONPICKER = 9,
}

local function Resolve(value, ...)
    if type(value) == "function" then
        local ok, result = pcall(value, ...)
        return ok and result or nil
    end
    return value
end

local function Muted(text)
    return string.format("|c9A9A9A%s|r", tostring(text or ""))
end

---------------------------------------------------------------------------
-- RowCollector: stands in for the LibHarvensAddonSettings dialog object
---------------------------------------------------------------------------
-- Panels call collector:AddSetting(params) / collector:Clear() exactly as they
-- did on the settings dialog; the rows end up in collector.rows.
local RowCollector = {}
RowCollector.__index = RowCollector

local function NewRowCollector()
    return setmetatable({ rows = {}, headerData = {}, selected = true }, RowCollector)
end

function RowCollector:Clear()
    self.rows = {}
    self.pendingHeader = nil
end

-- A section header is attached to the next row.
function RowCollector:AddRow(row)
    if self.pendingHeader then
        row.header = self.pendingHeader
        self.pendingHeader = nil
    end
    self.rows[#self.rows + 1] = row
    return row
end

local SLIDER_PRESETS = { 3, 5, 8, 12, 15, 20, 30, 45, 60, 90, 120 }

function RowCollector:AddSetting(params)
    local kind = params.type
    local label = tostring(Resolve(params.label) or "")
    local tooltip = Resolve(params.tooltip)
    if type(tooltip) == "number" and GetString then
        tooltip = GetString(tooltip)
    end

    if kind == ST.SECTION then
        if self.pendingHeader then
            -- Two headers in a row: keep the first one visible on an empty row.
            self:AddRow({ text = Muted("-"), tooltip = nil })
        end
        self.pendingHeader = label
        return
    end

    local disabled = Resolve(params.disable) == true

    if kind == ST.BUTTON then
        return self:AddRow({
            text = label ~= "" and label or tostring(Resolve(params.buttonText) or ""),
            tooltip = tooltip,
            keyText = Resolve(params.buttonText) or "Select",
            action = params.clickHandler,
            enabled = not disabled,
        })
    elseif kind == ST.CHECKBOX then
        local get, set = params.getFunction, params.setFunction
        local on = Resolve(get) == true
        return self:AddRow({
            text = string.format("%s   %s", label, on and "|c7CFC00On|r" or Muted("Off")),
            tooltip = tooltip,
            keyText = "Toggle",
            enabled = not disabled,
            action = function()
                if set then set(not (Resolve(get) == true)) end
            end,
        })
    elseif kind == ST.SLIDER then
        local get, set = params.getFunction, params.setFunction
        local value = tonumber(Resolve(get)) or params.min or 0
        local unit = tostring(Resolve(params.unit) or "")
        local minValue, maxValue, step = params.min or 0, params.max or 100, params.step or 1
        return self:AddRow({
            text = string.format("%s   |cFFFFFF%s%s|r", label, tostring(math.floor(value + 0.5)), unit),
            tooltip = (tooltip and (tooltip .. "\n") or "") .. "Press to change the value.",
            keyText = "Change",
            enabled = not disabled,
            action = function()
                local current = tonumber(Resolve(get)) or minValue
                local nextValue
                if (maxValue - minValue) / step > 20 then
                    for i = 1, #SLIDER_PRESETS do
                        local preset = SLIDER_PRESETS[i]
                        if preset > current and preset >= minValue and preset <= maxValue then
                            nextValue = preset
                            break
                        end
                    end
                    nextValue = nextValue or minValue
                else
                    nextValue = current + step
                    if nextValue > maxValue then nextValue = minValue end
                end
                if set then set(nextValue) end
            end,
        })
    elseif kind == ST.EDIT then
        local value = tostring(Resolve(params.getFunction) or "")
        return self:AddRow({
            text = string.format("%s   |cFFFFFF%s|r", label, value ~= "" and value or "(auto)"),
            tooltip = (tooltip and (tooltip .. "\n\n") or "") .. "Text entry is not available here; use the buttons below (for example Use Auto Name).",
        })
    end

    -- ST.LABEL and anything else: read-only row.
    return self:AddRow({ text = label, tooltip = tooltip })
end

---------------------------------------------------------------------------
-- Row and section setup
---------------------------------------------------------------------------
-- Uses the same list row templates LibHarvensAddonSettings uses on console
-- (a label row for every entry, the options section title for headers) and
-- fills them the same way: the text goes straight into the row's label.
local rowLabelWarned = false

local function FindLabel(control)
    return control.label or control:GetNamedChild("Name") or control:GetNamedChild("Label") or control:GetNamedChild("Text")
end

local function WarnMissingLabel(control, what)
    if rowLabelWarned then
        return
    end
    -- Report once what the template contains, so it can be fixed from chat.
    rowLabelWarned = true
    local names = {}
    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        names[#names + 1] = child and child:GetName() or "?"
    end
    CM:Print(string.format("Fight viewer: %s label not found. Children: %s", what, table.concat(names, ", ")))
end

local function LabelColor(selected, disabled)
    if ZO_GamepadMenuEntryTemplate_GetLabelColor then
        local ok, color = pcall(ZO_GamepadMenuEntryTemplate_GetLabelColor, selected, disabled)
        if ok and color then
            return color
        end
    end
    if disabled then return ZO_DISABLED_TEXT end
    return selected and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT
end

local function SetupRow(control, data, selected)
    local label = FindLabel(control)
    if not label then
        WarnMissingLabel(control, "row")
        return
    end
    control:SetHidden(false)
    label:SetHidden(false)
    label:SetText(data.cmText or "")
    local color = LabelColor(selected, data.cmRow and data.cmRow.enabled == false)
    if color and color.UnpackRGB then
        label:SetColor(color:UnpackRGB())
    end
end

local function SetupSection(control, data)
    local label = FindLabel(control)
    if not label then
        WarnMissingLabel(control, "section")
        return
    end
    control:SetHidden(false)
    label:SetHidden(false)
    label:SetText(data.cmText or "")
    control:SetHeight(label:GetTextHeight() + 4)
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------
local Screen = ZO_Gamepad_ParametricList_Screen and ZO_Gamepad_ParametricList_Screen:Subclass() or nil

if Screen then
    function Screen:New(...)
        return ZO_Gamepad_ParametricList_Screen.New(self, ...)
    end

    function Screen:Initialize(control, scene)
        self.addon = CM
        self.collector = NewRowCollector()
        self.headerData = { titleText = "Console Metrics" }
        ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
    end

    function Screen:SetupList(list)
        list:AddDataTemplate(ROW_TEMPLATE, SetupRow, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "CMRow")
        list:AddDataTemplate(SECTION_TEMPLATE, SetupSection, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "CMSection")
        list:SetOnSelectedDataChangedCallback(function(_, selectedData)
            self:OnRowSelected(selectedData)
        end)
    end

    -- Called by the base class when the screen shows; fill the list.
    function Screen:PerformUpdate()
        self.dirty = false
        self:Rebuild(true)
    end

    function Screen:SelectedRow()
        local list = self:GetMainList()
        local data = list and list:GetTargetData()
        return data and data.cmRow or nil
    end

    function Screen:RefreshKeybinds()
        if self.keybindStripDescriptor and KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    end

    function Screen:OnRowSelected(data)
        local row = data and data.cmRow
        if GAMEPAD_TOOLTIPS then
            if row and row.tooltip and row.tooltip ~= "" then
                -- Same tooltip call LibHarvensAddonSettings uses on console.
                local ok = pcall(GAMEPAD_TOOLTIPS.LayoutSettingTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, row.tooltip, "")
                if not ok then
                    pcall(GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, "", row.tooltip)
                end
            else
                pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP)
            end
        end
        local list = self:GetMainList()
        local index = list and list:GetSelectedIndex()
        if index ~= self.lastSelectedIndex then
            -- Cursor moves made by a rebuild are not player input.
            if self.lastSelectedIndex ~= nil and not self.rebuilding then
                self.addon:NoteConsoleDialogInteraction()
            end
            self.lastSelectedIndex = index
        end
        self:RefreshKeybinds()
    end

    -- Renders the current panel into the list. keepSelection keeps the cursor
    -- on the same row number (same page, live refresh).
    function Screen:Rebuild(keepSelection)
        local addon = self.addon
        local list = self:GetMainList()
        local oldIndex = keepSelection and list:GetSelectedIndex() or nil
        self.rebuilding = true
        self.rebuildCount = (self.rebuildCount or 0) + 1

        addon:PopulateFightViewDialog(self.collector)

        -- Section titles are their own rows (not selectable), like on the
        -- settings screen; every other row is a label row.
        list:Clear()
        local entries = {}
        local rows = self.collector.rows
        for i = 1, #rows do
            local row = rows[i]
            if row.header then
                local section = { cmText = row.header, canSelect = false }
                entries[#entries + 1] = section
                list:AddEntry(SECTION_TEMPLATE, section)
            end
            local data = { cmText = row.text or "", cmRow = row, canSelect = true }
            entries[#entries + 1] = data
            list:AddEntry(ROW_TEMPLATE, data)
        end
        if self.collector.pendingHeader then
            -- A section title with nothing under it (end of the page).
            local section = { cmText = self.collector.pendingHeader, canSelect = false }
            entries[#entries + 1] = section
            list:AddEntry(SECTION_TEMPLATE, section)
        end
        list:Commit()

        -- Put the cursor on a selectable row: the same row number when
        -- refreshing the same page, else the first row.
        local target = nil
        local start = (oldIndex and oldIndex > 0) and math.min(oldIndex, #entries) or 1
        for i = start, #entries do
            if entries[i].canSelect then target = i break end
        end
        if not target then
            for i = start, 1, -1 do
                if entries[i] and entries[i].canSelect then target = i break end
            end
        end
        if target then
            list:SetSelectedIndexWithoutAnimation(target, true, false)
        end
        self.lastSelectedIndex = list:GetSelectedIndex()

        -- Header: panel name and the viewed fight's numbers.
        local headerData = self.collector.headerData or {}
        ZO_ClearTable(self.headerData)
        for key, value in pairs(headerData) do
            self.headerData[key] = value
        end
        if self.header then
            ZO_GamepadGenericHeader_RefreshData(self.header, self.headerData)
        end

        self:OnRowSelected(list:GetTargetData())
        self.rebuilding = false
    end

    function Screen:RunSelectedAction()
        local row = self:SelectedRow()
        if not row or not row.action or row.enabled == false then
            return
        end
        local addon = self.addon
        addon:NoteConsoleDialogInteraction()
        local before = self.rebuildCount
        local ok, err = pcall(row.action)
        if not ok then
            self.rebuilding = false
            addon:Print("Console Metrics: " .. tostring(err))
        end
        -- The action may have changed the page (page history is handled in
        -- RebuildConsoleDialog) or closed the viewer. Buttons made with
        -- ctx:AddButton already rebuilt; others (Back rows, toggles) did not.
        if addon:IsConsoleDialogOnScreen() and self.rebuildCount == before then
            addon:RebuildConsoleDialog(true)
        end
    end

    function Screen:InitializeKeybindStripDescriptors()
        local screen = self
        local addon = CM
        self.keybindStripDescriptor = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            {
                name = function()
                    local row = screen:SelectedRow()
                    return row and row.keyText or GetString(SI_GAMEPAD_SELECT_OPTION)
                end,
                keybind = "UI_SHORTCUT_PRIMARY",
                visible = function()
                    local row = screen:SelectedRow()
                    return row ~= nil and row.action ~= nil
                end,
                enabled = function()
                    local row = screen:SelectedRow()
                    return row ~= nil and row.enabled ~= false
                end,
                callback = function()
                    screen:RunSelectedAction()
                end,
            },
            {
                name = "Main Menu",
                keybind = "UI_SHORTCUT_TERTIARY",
                visible = function()
                    return (addon.dialogPanel or "main") ~= "main"
                end,
                callback = function()
                    addon:ConsoleGoMain()
                end,
            },
            {
                name = "Live",
                keybind = "UI_SHORTCUT_SECONDARY",
                visible = function()
                    return not addon:IsConsoleViewingLive()
                end,
                callback = function()
                    addon:ConsoleStepFight(0)
                end,
            },
            {
                name = "Older Fight",
                keybind = "UI_SHORTCUT_LEFT_SHOULDER",
                visible = function()
                    return addon:ConsoleHasFightHistory()
                end,
                callback = function()
                    addon:ConsoleStepFight(-1)
                end,
            },
            {
                name = "Newer Fight",
                keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
                visible = function()
                    return addon:ConsoleHasFightHistory()
                end,
                callback = function()
                    addon:ConsoleStepFight(1)
                end,
            },
        }
        ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function()
            addon:ConsoleGoBack()
        end)
    end

    function Screen:OnHide()
        if ZO_Gamepad_ParametricList_Screen.OnHide then
            ZO_Gamepad_ParametricList_Screen.OnHide(self)
        end
        if GAMEPAD_TOOLTIPS then
            pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP)
        end
    end
end

---------------------------------------------------------------------------
-- Creating the screen (once, on first open)
---------------------------------------------------------------------------
local screen = nil
local scene = nil

local function CreateScreen()
    if screen then
        return screen
    end
    if not Screen then
        return nil
    end
    local ok, err = pcall(function()
        local control = WINDOW_MANAGER:CreateControlFromVirtual("ConsoleMetricsFightViewerTopLevel", GuiRoot, "ConsoleMetricsGamepadTopLevel")
        local fragment = ZO_FadeSceneFragment:New(control)

        scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
        scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
        scene:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
        scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
        scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
        scene:AddFragment(fragment)

        screen = Screen:New(control, scene)
    end)
    if not ok then
        CM:Print("Could not create the gamepad fight viewer: " .. tostring(err))
        screen, scene = nil, nil
    end
    return screen
end

function CM:GetConsoleScreen()
    return screen
end

---------------------------------------------------------------------------
-- Page history and navigation
---------------------------------------------------------------------------
local pageStack = {}
local lastRenderedPanel = nil
local navigatingBack = false

local function ResetHistory()
    pageStack = {}
    lastRenderedPanel = nil
end

function CM:IsConsoleDialogOnScreen()
    return scene ~= nil and SCENE_MANAGER:IsShowing(SCENE_NAME)
end

-- Where Back goes from the current page.
function CM:GetConsoleBackTarget()
    if #pageStack > 0 then
        return pageStack[#pageStack]
    end
    if (self.dialogPanel or "main") == "main" then
        return nil
    end
    return self:GetConsoleParentPanel(self.dialogPanel) or "main"
end

function CM:GetConsoleBackLabel()
    local target = self:GetConsoleBackTarget()
    if not target then
        return nil
    end
    local titles = self.ConsolePanelTitles or {}
    if target == "main" then
        return "Back to Main Menu"
    end
    return "Back to " .. tostring(titles[target] or target)
end

-- Rebuilds the screen. A changed page (set by a row action) is recorded in
-- the history so Back returns to the page it was opened from.
function CM:RebuildConsoleDialog(keepSelection)
    if not self:IsConsoleDialogOnScreen() or not screen then
        return false
    end
    local panel = self.dialogPanel or "main"
    local changed = lastRenderedPanel ~= nil and panel ~= lastRenderedPanel
    if changed and not navigatingBack then
        if panel == "main" then
            pageStack = {}
        else
            pageStack[#pageStack + 1] = lastRenderedPanel
        end
    end
    lastRenderedPanel = panel
    screen:Rebuild(keepSelection and not changed)
    self.lastDialogRefreshKey = nil
    return true
end

function CM:ConsoleGoBack()
    if not self:IsConsoleDialogOnScreen() then
        return false
    end
    local target = self:GetConsoleBackTarget()
    if not target then
        self:CloseFightViewDialog(true, "back")
        return true
    end
    if #pageStack > 0 then
        pageStack[#pageStack] = nil
    end
    if target == "main" then
        pageStack = {}
    end
    self.dialogPanel = target
    navigatingBack = true
    self:RebuildConsoleDialog(false)
    navigatingBack = false
    self:NoteConsoleDialogInteraction()
    return true
end

function CM:ConsoleGoMain()
    if not self:IsConsoleDialogOnScreen() then
        return false
    end
    pageStack = {}
    self.dialogPanel = "main"
    navigatingBack = true
    self:RebuildConsoleDialog(false)
    navigatingBack = false
    self:NoteConsoleDialogInteraction()
    return true
end

---------------------------------------------------------------------------
-- Fight stepping (keybinds)
---------------------------------------------------------------------------
function CM:IsConsoleViewingLive()
    if self:IsCmxPanel() then
        return self.cmxFightOverride == nil and (self.libFightsViewOffset or 0) == 0
    end
    return (self.viewFightIndex or 0) == 0
end

function CM:ConsoleHasFightHistory()
    if self:IsCmxPanel() then
        local _, _, count = self:GetLibFightsViewedFight()
        return (count or 0) > 1 or self.cmxFightOverride ~= nil
    end
    return #(self.fightHistory or {}) > 0
end

-- step: -1 older, +1 newer, 0 live
function CM:ConsoleStepFight(step)
    if self:IsCmxPanel() then
        self.cmxFightOverride = nil
        self.cmxLogPage = 1
        if step == 0 then
            self.libFightsViewOffset = 0
            self.libFightsRev = (self.libFightsRev or 0) + 1
        else
            self:StepLibFightsView(step)
        end
    else
        if step == 0 then
            self.viewFightIndex = 0
        else
            self:StepFightView(step)
        end
    end
    self:NoteConsoleDialogInteraction()
    self:RebuildConsoleDialog(true)
end

---------------------------------------------------------------------------
-- Input tracking (pauses live refresh / auto-hide while browsing)
---------------------------------------------------------------------------
local CONSOLE_INPUT_HOLD_MS = 2000

function CM:NoteConsoleDialogInteraction()
    self.consoleLastInputMs = GetFrameTimeMilliseconds()
    if self.dialogAutoHideAtMs then
        self:ArmDialogAutoHide()
    end
end

-- Selection changes are reported by the screen itself.
function CM:TrackConsoleDialogInput()
end

function CM:IsConsoleDialogBusy()
    if not self:IsConsoleDialogOnScreen() then
        return false
    end
    return GetFrameTimeMilliseconds() < (self.consoleLastInputMs or 0) + CONSOLE_INPUT_HOLD_MS
end

---------------------------------------------------------------------------
-- Open / close / showing / refresh (replace the settings-dialog versions)
---------------------------------------------------------------------------
-- The old settings-screen hooks are not needed any more.
function CM:RegisterConsoleFightKeybinds()
    self.consoleFightKeybindsRegistered = true
end

function CM:HookConsoleBackButton()
end

function CM:RefreshConsoleDialogHeader()
end

local function UseGamepadScreen()
    return ConsoleMetrics.IsGamepadUI() and Screen ~= nil
end

function CM:OpenFightViewDialog(forceLive)
    if not UseGamepadScreen() then
        self:OpenPCDialog(forceLive)
        return
    end
    if not CreateScreen() then
        if type(IsConsoleUI) == "function" and IsConsoleUI() then
            return
        end
        self:OpenPCDialog(forceLive)
        return
    end

    -- The fight keybinds live on this screen's own strip.
    self.consoleFightKeybindsRegistered = true
    self.ui.fightViewDialog = screen.collector

    if forceLive then
        self.viewFightIndex = 0
    end
    if self:IsConsoleDialogOnScreen() then
        -- Already open: show Main again.
        self:ConsoleGoMain()
    else
        self.dialogPanel = "main"
        ResetHistory()
        lastRenderedPanel = "main"
        -- Fill the list before the screen appears.
        screen:Rebuild(false)
        SCENE_MANAGER:Push(SCENE_NAME)
    end
    self:NoteConsoleDialogInteraction()
    self:ArmDialogAutoHide()
    self.dialogRefreshAtMs = 0
    self.lastDialogRefreshKey = nil
    self.wasFightViewDialogShowing = true
end

function CM:IsFightViewDialogShowing()
    return self:IsFightViewDialogShowingPC() or self:IsConsoleDialogOnScreen()
end

function CM:RefreshFightViewDialog()
    if self:IsFightViewDialogShowingPC() then
        self:RefreshPCDialog()
    elseif self:IsConsoleDialogOnScreen() then
        self:RebuildConsoleDialog(true)
    end
end

function CM:CloseFightViewDialog(silent, reason)
    self.isClosingFightViewDialog = true
    self.dialogAutoHideAtMs = nil
    self.dialogRefreshAtMs = nil
    self.lastDialogRefreshKey = nil

    if self:IsFightViewDialogShowingPC() then
        -- The PC window keeps its panel for the next open.
        self:ClosePCDialog()
    else
        self.dialogPanel = "main"
    end

    if self:IsConsoleDialogOnScreen() and reason ~= "cancel" then
        if SCENE_MANAGER:GetCurrentScene() == scene then
            SCENE_MANAGER:HideCurrentScene()
        else
            SCENE_MANAGER:Hide(SCENE_NAME)
        end
    end
    ResetHistory()

    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false
    if not silent then
        self:Print(string.format("Fight data dialog closed (%s)", reason or "manual"))
    end
end
