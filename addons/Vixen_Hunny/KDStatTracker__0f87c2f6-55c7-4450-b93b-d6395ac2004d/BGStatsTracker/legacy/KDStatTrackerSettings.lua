KDStatTracker = KDStatTracker or {}
KDStatTrackerUI = KDStatTrackerUI or {}
KDStatTracker.name = "KDStatTracker"
KDStatTracker.version = "2.0"
KDStatTracker.author = "Vixen Hunny"
KDStatTracker.isLoaded = KDStatTracker.isLoaded or false
KDStatTrackerSettings = KDStatTrackerSettings or {}
KDStatTracker.default_settings = {
    showKD = true,
    scale = 1.0,
    fontSize = 16,
    x = 0,
    y = 0,
    fontColor = "FFFFFF",
}
function CreateSettingsMenu()
    local LAM2 = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = "KDStatTracker",
        displayName = "|c00FF88KDStatTracker|r",
        author = KDStatTracker.author,
        version = KDStatTracker.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }
    KDStatTrackerSettings.settingsPanel = LAM2:RegisterAddonPanel("KDStatTrackerSettingsPanel", panelData)
    EVENT_MANAGER:UnregisterForEvent(KDStatTracker.name, EVENT_ADD_ON_LOADED)
    KDStatTracker.db = ZO_SavedVars:NewAccountWide("KDStatTrackerSettings", 1, nil, KDStatTracker.default_settings)
    local optionsData = {
        { type = "checkbox", name = "Show KD Display",
          getFunc = function() return KDStatTracker.db.showKD end,
          setFunc = function(v) KDStatTracker.db.showKD = v; KDStatTrackerUI.UpdateVisibility() end },
        { type = "slider", name = "UI Scale", min = 0, max = 10, step = 0.01,
        getFunc = function() return KDStatTracker.db.scale end,
        setFunc = function(v) KDStatTracker.db.scale = v
        KDStatTrackerUI.kdDisplay:SetScale(v)
        KDStatTrackerUI.CreateUI() end,
        default = 1.0
        },
        { type = "slider", name = "Font Size", min = 14, max = 36, step = 1,
          getFunc = function() return KDStatTracker.db.fontSize end,
          setFunc = function(v) 
              KDStatTracker.db.fontSize = v
              KDStatTrackerUI.CreateUI()
          end ,
          default = 16},
        -- NEW: X position slider
        { type = "slider", name = "X Position", min = 0, max = GuiRoot:GetWidth(), step = 1,
          getFunc = function() return KDStatTracker.db.x end,
          setFunc = function(v)
              KDStatTracker.db.x = v
              KDStatTrackerUI.CreateUI()
          end, 
          default = 0 },

        -- NEW: Y position slider
        { type = "slider", name = "Y Position", min = 0, max = GuiRoot:GetHeight(), step = 1,
          getFunc = function() return KDStatTracker.db.y end,
          setFunc = function(v)
              KDStatTracker.db.y = v
              KDStatTrackerUI.CreateUI()
          end ,
          default = 0 },
        { type = "editbox", name = "Hex color", 
          getFunc = function() return KDStatTracker.db.fontColor end,
          setFunc = function(v) 
              KDStatTracker.db.fontColor = v
              KDStatTrackerUI.CreateUI()
          end ,
          default = "FFFFFF"},
        { type = "button", name = "Reset Position",
          func = function()
              KDStatTracker.db.x, KDStatTracker.db.y = 0, 0
              KDStatTrackerUI.CreateUI()
          end},
    }
        LAM2:RegisterOptionControls("KDStatTrackerSettingsPanel", optionsData)
end

EVENT_MANAGER:RegisterForEvent(KDStatTracker.name .. "Settings", EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == "KDStatTracker" and KDStatTracker.isLoaded == true then
        CreateSettingsMenu()
    end
end)