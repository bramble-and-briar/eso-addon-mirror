PBsHpsChecker = PBsHpsChecker or {}
local ADDON = PBsHpsChecker

---------------------------------------------------------------------------------------------------
-- The settings panel (LibHarvensAddonSettings, optional)
--
-- Settings only. The statistics are on the statistics screen (Screen.lua), which has its own entry in
-- the main menu; the panel has a button that opens it and lists none of the numbers itself.
--
-- The HUD meter is drawn over the panel while the panel is open (the panel is not a HUD scene), with
-- sample numbers, to place and size it.
---------------------------------------------------------------------------------------------------

-- Position moves in fives: a d-pad press that moves the meter one unit at a time would take a minute
-- to cross the screen.
local LAYOUT_STEP = 5

local function L(id)
    return GetString(id)
end

---------------------------------------------------------------------------------------------------
-- Following the settings panel
--
-- On console the library opens a panel in two steps (LibHarvensAddonSettings, Console/Settings.lua):
--
--   addon:Select()                                      fires AddonSelected, then sets .selected
--   SCENE_MANAGER:Push("LibHarvensAddonSettingsScene")  and only then shows the panel
--
-- So AddonSelected arrives while the add-on list is still the current scene, and Select() returns
-- early for the add-on already selected, so a second visit to the same panel fires nothing at all.
-- The panel scene itself is the reliable signal: shown with our panel selected means the HUD meter's
-- preview is wanted, hiding means it is not. It only exists once the library has initialised, which it
-- does the first time the main menu opens, so it is looked up when a panel is picked. The same as PB's
-- KillLog, measured on PS5.
---------------------------------------------------------------------------------------------------

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

-- LibHarvensAddonSettings_AddonSelected. On console the panel scene is not up yet, and its
-- SCENE_SHOWN does the showing; the PC copy of the library has no such scene and shows the panel in
-- place, so there it goes up at once.
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

---------------------------------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------------------------------

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
    local records = ADDON.records
    local hud = ADDON.hud

    -- The sliders' ranges are the screen. GuiRoot is the space the anchor offsets are measured in.
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

    local function ApplyHud()
        hud:ApplyLayout()
        hud:Refresh()
    end

    settings:AddSetting({ type = Library.ST_LABEL, label = L(SI_PBSHPS_EXPLANATION) })

    -- ---- Statistics ----------------------------------------------------------------------
    -- The statistics are on their own screen, in the main menu. This is a way to it from here.
    AddSection(SI_PBSHPS_SECTION_STATS)
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L(SI_PBSHPS_STATS_BUTTON),
        tooltip = L(SI_PBSHPS_STATS_BUTTON_TIP),
        buttonText = L(SI_PBSHPS_STATS_BUTTON_TEXT),
        clickHandler = function() ADDON.menu:Open() end,
    })
    AddCheckbox(SI_PBSHPS_SHOW_PSN, SI_PBSHPS_SHOW_PSN_TIP, "showPsn", nil)

    -- ---- HUD meter -----------------------------------------------------------------------
    AddSection(SI_PBSHPS_SECTION_HUD)
    AddCheckbox(SI_PBSHPS_HUD, SI_PBSHPS_HUD_TIP, "hud", ApplyHud)
    AddSlider(SI_PBSHPS_HUD_SIZE, SI_PBSHPS_HUD_SIZE_TIP, "hudSize", 1, hud.NUM_SIZES, 1, function() hud:ApplySize() end)
    -- The box's own size in pixels. Off, it is as big as its text needs. Switching it on starts from the
    -- size the box has now, and the two sliders are redrawn to show it.
    AddCheckbox(SI_PBSHPS_HUD_CUSTOM, SI_PBSHPS_HUD_CUSTOM_TIP, "hudCustomSize", function(value)
        if value then
            hud:StartCustomSize(LAYOUT_STEP)
        end
        hud:ApplySize()
        settings:UpdateControls()
    end)
    AddSlider(SI_PBSHPS_HUD_WIDTH, SI_PBSHPS_HUD_WIDTH_TIP, "hudWidth", 120, rootWidth, LAYOUT_STEP, function() hud:ApplySize() end)
    AddSlider(SI_PBSHPS_HUD_HEIGHT, SI_PBSHPS_HUD_HEIGHT_TIP, "hudHeight", 60, rootHeight, LAYOUT_STEP, function() hud:ApplySize() end)
    AddSlider(SI_PBSHPS_HUD_HOLD, SI_PBSHPS_HUD_HOLD_TIP, "hudHoldSec", 3, 60, 1, nil)
    AddSlider(SI_PBSHPS_HUD_LEFT, SI_PBSHPS_HUD_LEFT_TIP, "hudLeft", 0, rootWidth, LAYOUT_STEP, ApplyHud)
    AddSlider(SI_PBSHPS_HUD_TOP, SI_PBSHPS_HUD_TOP_TIP, "hudTop", 0, rootHeight, LAYOUT_STEP, ApplyHud)

    -- ---- Recording -----------------------------------------------------------------------
    AddSection(SI_PBSHPS_SECTION_RECORD)
    AddCheckbox(SI_PBSHPS_ENABLED, SI_PBSHPS_ENABLED_TIP, "enabled", ADDON.SetEnabled)
    AddCheckbox(SI_PBSHPS_OTHERS, SI_PBSHPS_OTHERS_TIP, "countOthers", ADDON.SetCountOthers)

    local zoneItems, zoneItemByKey = {}, {}
    for _, key in ipairs(ADDON.ZONES) do
        local item = { name = L(_G["SI_PBSHPS_ZONE_" .. zo_strupper(key)]), data = key }
        zoneItems[#zoneItems + 1] = item
        zoneItemByKey[key] = item
    end
    settings:AddSetting({
        type = Library.ST_DROPDOWN,
        label = L(SI_PBSHPS_ZONES),
        tooltip = L(SI_PBSHPS_ZONES_TIP),
        items = zoneItems,
        default = zoneItemByKey[defaults.zones].name,
        getFunction = function()
            -- Never nil: a dropdown handed nil falls back to showing its first item, which reads as
            -- the setting having reset itself.
            return (zoneItemByKey[sv.zones] or zoneItemByKey[defaults.zones]).name
        end,
        setFunction = function(combobox, name, item)
            ADDON.SetZones(item.data)
        end,
    })

    AddSlider(SI_PBSHPS_GAP, SI_PBSHPS_GAP_TIP, "gapSec", 5, 30, 1, nil)

    -- ---- Data ----------------------------------------------------------------------------
    AddSection(SI_PBSHPS_SECTION_DATA)
    settings:AddSetting({
        type = Library.ST_BUTTON,
        label = L(SI_PBSHPS_CLEAR),
        tooltip = L(SI_PBSHPS_CLEAR_TIP),
        buttonText = L(SI_PBSHPS_BUTTON_RUN),
        clickHandler = function()
            -- Deleting records is asked about first, and does nothing if it cannot be asked.
            if not records:ConfirmClear(function()
                -- Nothing on the panel shows the records; the screen is drawn afresh when it is opened.
            end) then
                ADDON.Print(L(SI_PBSHPS_ERR_NO_DIALOG))
            end
        end,
    })

    -- Registered on the client's callback manager, beside everyone else's.
    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", function(_, addonSettings)
        OnAddonSelected(addonSettings)
    end)
end
