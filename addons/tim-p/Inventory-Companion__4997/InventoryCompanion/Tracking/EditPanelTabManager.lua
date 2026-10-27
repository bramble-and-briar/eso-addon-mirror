-- Tracking/EditPanelTabManager.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

this.state = this.state or {}
this.state.lastActiveEditTab = this.state.lastActiveEditTab or "InventoryCompanion_TrackedItemsScene"

------------------------------------------------------------------
-- Panel Switching & Toggle Endpoints
------------------------------------------------------------------
local function SyncPanelGeometry(sourceWindow, targetWindow)
    targetWindow:ClearAnchors()
    targetWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sourceWindow:GetLeft(), sourceWindow:GetTop())
    targetWindow:SetDimensions(sourceWindow:GetWidth(), sourceWindow:GetHeight())
end

function this.UpdateEditorLayout()
    local itemWindow = InventoryCompanion_TrackedItemsWindow
    local groupWindow = InventoryCompanion_GroupsWindow

    local itemHidden = itemWindow and itemWindow:IsHidden()
    local groupHidden = groupWindow and groupWindow:IsHidden()

    local isItemOpen = itemWindow and not itemHidden
    local isGroupOpen = groupWindow and not groupHidden

    -- Diagnostic print to verify execution and values
    d(string.format("[IC Layout Debug] UpdateEditorLayout called -> ItemHidden: %s | GroupHidden: %s", tostring(itemHidden), tostring(groupHidden)))

    if isItemOpen and this.AdjustTrackerPositionForEditor then
        this.Utils.DebugMessage(" -> Adjusting for Items Window")
        this.AdjustTrackerPositionForEditor(itemWindow)
    elseif isGroupOpen and this.AdjustTrackerPositionForEditor then
        this.Utils.DebugMessage(" -> Adjusting for Groups Window")
        this.AdjustTrackerPositionForEditor(groupWindow)
    else
        this.Utils.DebugMessage("<- Restoring Tracker Position")
        if this.RestoreTrackerPosition then
            this.RestoreTrackerPosition()
        end
    end
end
--/debug

function this.OpenEditItemsPanel()
    if SCENE_MANAGER:IsShowing("InventoryCompanion_GroupsScene") then
        SyncPanelGeometry(InventoryCompanion_GroupsWindow, InventoryCompanion_TrackedItemsWindow)
    end

    this.state.lastActiveEditTab = "InventoryCompanion_TrackedItemsScene"
    SCENE_MANAGER:Hide("InventoryCompanion_GroupsScene")
    SCENE_MANAGER:Show("InventoryCompanion_TrackedItemsScene")
    this.RefreshTrackedItemsEditor()
end

function this.OpenEditGroupsPanel()
    if SCENE_MANAGER:IsShowing("InventoryCompanion_TrackedItemsScene") then
        SyncPanelGeometry(InventoryCompanion_TrackedItemsWindow, InventoryCompanion_GroupsWindow)
    end

    this.state.lastActiveEditTab = "InventoryCompanion_GroupsScene"
    SCENE_MANAGER:Hide("InventoryCompanion_TrackedItemsScene")
    SCENE_MANAGER:Show("InventoryCompanion_GroupsScene")
    this.RefreshGroupsEditor()
end

function this.ToggleTrackedItemsEditor()
    if SCENE_MANAGER:IsShowing("InventoryCompanion_TrackedItemsScene") then
        this.state.lastActiveEditTab = "InventoryCompanion_TrackedItemsScene"
        SCENE_MANAGER:Hide("InventoryCompanion_TrackedItemsScene")
    elseif SCENE_MANAGER:IsShowing("InventoryCompanion_GroupsScene") then
        this.state.lastActiveEditTab = "InventoryCompanion_GroupsScene"
        SCENE_MANAGER:Hide("InventoryCompanion_GroupsScene")
    else
        SCENE_MANAGER:Show(this.state.lastActiveEditTab)
        if this.state.lastActiveEditTab == "InventoryCompanion_TrackedItemsScene" then
            if this.RefreshTrackedItemsEditor then this.RefreshTrackedItemsEditor() end
        elseif this.state.lastActiveEditTab == "InventoryCompanion_GroupsScene" then
            if this.RefreshGroupsEditor then this.RefreshGroupsEditor() end
        end
    end
end