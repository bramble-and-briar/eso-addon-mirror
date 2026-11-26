PBsBattleScrolls = PBsBattleScrolls or {}
local ADDON = PBsBattleScrolls

---------------------------------------------------------------------------------------------------
-- The settings panel (LibHarvensAddonSettings, optional)
--
-- While the panel is open the HUD box is drawn over it with sample numbers, so it can be placed.
-- On console the library opens a panel in two steps (AddonSelected fires while the add-on list is
-- still the scene, then the panel scene is pushed), so the panel scene's own StateChange is what
-- says the panel is up -- the way PB's HPS Checker and KillLog do it (measured on PS5).
---------------------------------------------------------------------------------------------------

local L = ADDON.L
local LAYOUT_STEP = 5
local PANEL_SCENE_NAME = "LibHarvensAddonSettingsScene"

local function PanelScene()
    local library = LibHarvensAddonSettings
    local scene = library and library.scene
    if not scene and SCENE_MANAGER and type(SCENE_MANAGER.GetScene) == "function" then
        scene = SCENE_MANAGER:GetScene(PANEL_SCENE_NAME)
    end
    if type(scene) == "table" and type(scene.RegisterCallback) == "function" then
        return scene
    end
    return nil
end

local function SetPanelOpen(open)
    ADDON.panelOpen = open and true or false
    ADDON.hud:OnPanelOpen(ADDON.panelOpen)
end

local panelScene
local function WatchPanelScene()
    if panelScene then
        return panelScene
    end
    local scene = PanelScene()
    if not scene then
        return nil
    end
    panelScene = scene
    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWN then
            local panel = ADDON.settingsPanel
            SetPanelOpen(panel ~= nil and panel.selected == true)
        elseif newState == SCENE_HIDING then
            SetPanelOpen(false)
        end
    end)
    return scene
end

local function OnAddonSelected(addonSettings)
    local scene = WatchPanelScene()
    if addonSettings ~= ADDON.settingsPanel then
        SetPanelOpen(false)
        return
    end
    if scene and not (type(scene.IsShowing) == "function" and scene:IsShowing()) then
        return
    end
    SetPanelOpen(true)
end

function ADDON.InitializeSettings()
    local Library = LibHarvensAddonSettings
    if not Library then
        return
    end
    local settings = Library:AddAddon(ADDON.title)
    if not settings then
        return
    end
    ADDON.settingsPanel = settings
    settings.allowDefaults = true
    settings.author = ADDON.author
    settings.version = ADDON.version

    local sv = ADDON.sv
    local defaults = ADDON.defaults
    local hud = ADDON.hud
    local rootWidth = zo_floor(GuiRoot:GetWidth())
    local rootHeight = zo_floor(GuiRoot:GetHeight())

    local function AddSection(id)
        settings:AddSetting({ type = Library.ST_SECTION or Library.ST_LABEL, label = L(id) })
    end

    local function AddCheckbox(labelId, tipId, key, apply)
        settings:AddSetting({
            type = Library.ST_CHECKBOX,
            label = L(labelId),
            tooltip = L(tipId),
            default = defaults[key],
            getFunction = function() return sv[key] end,
            setFunction = function(value)
                sv[key] = value
                if apply then
                    apply(value)
                end
            end,
        })
    end

    local function AddSlider(labelId, tipId, key, min, max, step, apply)
        settings:AddSetting({
            type = Library.ST_SLIDER,
            label = L(labelId),
            tooltip = L(tipId),
            min = min,
            max = max,
            step = step,
            default = defaults[key],
            format = "%d",
            unit = "",
            getFunction = function() return sv[key] end,
            setFunction = function(value)
                sv[key] = value
                if apply then
                    apply(value)
                end
            end,
        })
    end

    local function ApplyStyle()
        hud:ApplyStyle()
        hud:Refresh()
    end

    settings:AddSetting({ type = Library.ST_LABEL, label = L(SI_PBSBS_EXPLANATION) })

    AddSection(SI_PBSBS_SECTION_WINDOW)
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L(SI_PBSBS_OPEN),
        tooltip = L(SI_PBSBS_OPEN_TIP),
        buttonText = L(SI_PBSBS_OPEN_BUTTON),
        clickHandler = function() ADDON.menu:Open() end,
    })

    AddSection(SI_PBSBS_SECTION_HUD)
    AddCheckbox(SI_PBSBS_HUD, SI_PBSBS_HUD_TIP, "hud", function() hud:Refresh() end)
    AddCheckbox(SI_PBSBS_HUD_HPS, SI_PBSBS_HUD_HPS_TIP, "hudHps", ApplyStyle)
    AddSlider(SI_PBSBS_HUD_SIZE, SI_PBSBS_HUD_SIZE_TIP, "hudSize", 1, hud.NUM_SIZES, 1, ApplyStyle)
    AddSlider(SI_PBSBS_HUD_ALPHA, SI_PBSBS_HUD_ALPHA_TIP, "hudAlpha", 0, 100, 5, ApplyStyle)
    AddSlider(SI_PBSBS_HUD_X, SI_PBSBS_HUD_X_TIP, "hudX", 0, rootWidth, LAYOUT_STEP, ApplyStyle)
    AddSlider(SI_PBSBS_HUD_Y, SI_PBSBS_HUD_Y_TIP, "hudY", 0, rootHeight, LAYOUT_STEP, ApplyStyle)
    AddSlider(SI_PBSBS_HUD_HOLD, SI_PBSBS_HUD_HOLD_TIP, "hudHoldSec", 0, 60, 1, nil)

    AddSection(SI_PBSBS_SECTION_GROUP)
    AddCheckbox(SI_PBSBS_SHARE, SI_PBSBS_SHARE_TIP, "share", function() hud:Refresh() end)
    AddCheckbox(SI_PBSBS_HUD_GROUP_SHOW, SI_PBSBS_HUD_GROUP_SHOW_TIP, "hudGroup", ApplyStyle)
    AddSlider(SI_PBSBS_HUD_GROUP_ROWS, SI_PBSBS_HUD_GROUP_ROWS_TIP, "hudGroupRows", 1, hud.MAX_GROUP_ROWS, 1, ApplyStyle)

    AddSection(SI_PBSBS_SECTION_RECORD)
    AddCheckbox(SI_PBSBS_ENABLED, SI_PBSBS_ENABLED_TIP, "enabled", ADDON.SetEnabled)
    AddCheckbox(SI_PBSBS_DEBUFFS, SI_PBSBS_DEBUFFS_TIP, "debuffs", ADDON.SetDebuffs)
    AddSlider(SI_PBSBS_END_SEC, SI_PBSBS_END_SEC_TIP, "endSec", 1, 10, 1, nil)
    AddSlider(SI_PBSBS_IDLE_SEC, SI_PBSBS_IDLE_SEC_TIP, "idleSec", 5, 60, 1, nil)
    AddSlider(SI_PBSBS_MIN_SECS, SI_PBSBS_MIN_SECS_TIP, "minSecs", 0, 30, 1, nil)

    AddSection(SI_PBSBS_SECTION_DATA)
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L(SI_PBSBS_CLEAR),
        tooltip = L(SI_PBSBS_CLEAR_TIP),
        buttonText = L(SI_PBSBS_CLEAR_BUTTON),
        clickHandler = function() ADDON.ClearHistory() end,
    })

    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
        OnAddonSelected(addonSettings)
    end)
end
