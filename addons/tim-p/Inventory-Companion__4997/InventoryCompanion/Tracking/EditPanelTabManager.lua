-- Tracking/EditPanelTabManager.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.state = this.state or {}
this.state.lastActiveEditTab = this.state.lastActiveEditTab or "InventoryCompanion_TrackedItemsScene"

local ITEMS_SCENE = "InventoryCompanion_TrackedItemsScene"
local GROUPS_SCENE = "InventoryCompanion_GroupsScene"
local AUTOCATEGORY_SCENE = "InventoryCompanion_AutoCategoryScene"

local editorTabs = {
    { scene = ITEMS_SCENE, window = "InventoryCompanion_TrackedItemsWindow", refresh = "RefreshTrackedItemsEditor" },
    { scene = GROUPS_SCENE, window = "InventoryCompanion_GroupsWindow", refresh = "RefreshGroupsEditor" },
    { scene = AUTOCATEGORY_SCENE, window = "InventoryCompanion_AutoCategoryWindow", refresh = "RefreshAutoCategoryEditor" },
}
local visits = {}

function this.EndEditorVisit(window)
    visits[window] = nil
end

function this.RefreshEditorChrome(window, panel, contextKey, mode)
    if window:IsHidden() then return end
    local buttons = {
        { "BtnEditItems", "items", this.OpenEditItemsPanel },
        { "BtnEditGroups", "groups", this.OpenEditGroupsPanel },
        { "BtnAutoCategory", "autocategory", this.OpenAutoCategoryPanel },
    }
    for _, entry in ipairs(buttons) do
        local button = GetControl(window, entry[1])
        button:SetEnabled(entry[2] ~= panel)
        button:SetHidden(entry[2] == "autocategory" and not this.AutoCategoryIntegration.IsPanelAvailable())
        button:SetHandler("OnClicked", entry[3])
    end
    local undo = GetControl(window, "BtnUndo")
    undo:SetHidden(true)
    if panel == "autocategory" and not this.AutoCategoryIntegration.IsEditorActive() then return end
    local profile = this.GetSettingsProfile()
    local visit = visits[window]
    if visit and visit.profile ~= profile then
        visits[window] = nil
        visit = nil
    end
    if not visit then
        visit = { profile = profile,
            baseline = panel == "autocategory" and this.CopySavedValue(profile.autoCategoryOrder)
                or this.CaptureEditorState(panel) }
        visits[window] = visit
    end
    local snapshot = visit.baseline
    visit.context, visit.mode = contextKey, mode
    if panel == "autocategory" then
        local saved = snapshot.contexts[contextKey]
        snapshot = { order = saved[mode], hidden = saved.hidden, displayPositions = saved.displayPositions }
    end
    undo:SetHidden(this.SavedValuesEqual(snapshot, this.CaptureEditorState(panel, contextKey, mode)))
    undo:SetHandler("OnClicked", function()
        assert(visits[window] == visit and this.GetSettingsProfile() == profile,
            "Undo action targets a previous editor visit")
        assert(visit.context == contextKey and visit.mode == mode, "Undo action targets a previous editor page")
        if this.AutoCategoryIntegration.NeedsRecovery() then
            this.Utils.UserError("Resolve the AutoCategory problem before restoring the opening state.",
                "Undo changes unavailable")
            return
        end
        local function Restore()
            if this.RestoreEditorState(panel, snapshot, contextKey, mode) then
                this.RefreshTrackedItemsEditor()
                this.RefreshGroupsEditor()
                this.RefreshAutoCategoryEditor()
            end
        end
        if this.AutoCategoryIntegration.IsEditorActive() then
            this.AutoCategoryIntegration.Run(Restore)
        else
            Restore()
        end
    end)
end

local function GetTab(sceneName)
    for _, tab in ipairs(editorTabs) do
        if tab.scene == sceneName then return tab end
    end
    error("Unknown editor tab scene: " .. tostring(sceneName))
end

local function GetShowingTab()
    for _, tab in ipairs(editorTabs) do
        if SCENE_MANAGER:IsShowing(tab.scene) then return tab end
    end
end

------------------------------------------------------------------
-- Panel Switching & Toggle Endpoints
------------------------------------------------------------------
local function SyncPanelGeometry(sourceWindow, targetWindow)
    targetWindow:ClearAnchors()
    targetWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sourceWindow:GetLeft(), sourceWindow:GetTop())
    targetWindow:SetDimensions(sourceWindow:GetWidth(), sourceWindow:GetHeight())
end

function this.IsEditorWindowOpen()
    for _, tab in ipairs(editorTabs) do
        local window = _G[tab.window]
        if window and not window:IsHidden() then return true, window end
    end
    return false
end

function this.UpdateEditorLayout()
    local isOpen, openWindow = this.IsEditorWindowOpen()
    if isOpen and this.AdjustTrackerPositionForEditor then
        this.Utils.DebugMessage(" -> Adjusting for editor window")
        this.AdjustTrackerPositionForEditor(openWindow)
    else
        this.Utils.DebugMessage("<- Restoring Tracker Position")
        if this.RestoreTrackerPosition then
            this.RestoreTrackerPosition()
        end
    end
end

local function OpenEditorTab(sceneName)
    local target = GetTab(sceneName)
    local showing = GetShowingTab()
    if showing and showing ~= target then
        SyncPanelGeometry(_G[showing.window], _G[target.window])
    end

    this.state.lastActiveEditTab = sceneName
    for _, tab in ipairs(editorTabs) do
        if tab ~= target then SCENE_MANAGER:Hide(tab.scene) end
    end
    SCENE_MANAGER:Show(sceneName)
    this[target.refresh]()
end

function this.OpenEditItemsPanel()
    OpenEditorTab(ITEMS_SCENE)
end

function this.OpenEditGroupsPanel()
    OpenEditorTab(GROUPS_SCENE)
end

function this.OpenAutoCategoryPanel()
    assert(this.AutoCategoryIntegration.IsPanelAvailable(), "AutoCategory panel opened while integration is inactive")
    OpenEditorTab(AUTOCATEGORY_SCENE)
end

function this.OpenSettingsFromEditor()
    for _, tab in ipairs(editorTabs) do
        SCENE_MANAGER:Hide(tab.scene)
    end
    this.OpenSettingsPanel()
end

function this.ToggleTrackedItemsEditor()
    local showing = GetShowingTab()
    if showing then
        this.state.lastActiveEditTab = showing.scene
        SCENE_MANAGER:Hide(showing.scene)
        return
    end

    local sceneName = this.state.lastActiveEditTab
    -- The AutoCategory tab may have been closed before integration was disabled or AutoCategory was removed.
    if sceneName == AUTOCATEGORY_SCENE and not this.AutoCategoryIntegration.IsPanelAvailable() then
        sceneName = GROUPS_SCENE
    end
    SCENE_MANAGER:Show(sceneName)
    this[GetTab(sceneName).refresh]()
end
