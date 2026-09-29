ResearchPanel = ResearchPanel or {}
ResearchPanel.version = "1.0.14" -- Version of the Research Panel addon
ResearchPanel.author = "msetten" -- Author of the Research Panel addon
ResearchPanel.name = "ResearchPanel" -- Name of the addon
ResearchPanel.displayName = "Research Panel"
RESEARCHPANEL_LIGHT_MODE = 1
RESEARCHPANEL_GRAY_MODE = 2
RESEARCHPANEL_DARK_MODE = 3
ResearchPanel.defaultSettings = {
  offsetX = 540, -- X offset for the display
  offsetY = -20, -- Y offset for the display
  theme = RESEARCHPANEL_DARK_MODE, -- Default theme
  transparency = 0.4, -- Default transparency
  highlightUnusedSlots = true, -- Highlight unused slots
}
ResearchPanel.characterDefaults = {
  enabled = true, -- Enable or disable the addon
}

function ResearchPanel.createSettingsPanel()
  if IsConsoleUI() and not LibAddonMenu2 then return end

  local LAM = LibAddonMenu2
  if not LAM then return end

  local panelData = {
    type = "panel",
    name = ResearchPanel:L("PANEL_NAME"),
    displayName = ResearchPanel:L("PANEL_NAME"),
    author = ResearchPanel.author,
    version = ResearchPanel.version,
    registerForRefresh = true,
  }

  LAM:RegisterAddonPanel(ResearchPanel.name .. "Panel", panelData)

  local optionsData = {
   {
      type = "checkbox",
      name = ResearchPanel:L("ENABLE_ADDON_LABEL"),
      tooltip = ResearchPanel:L("ENABLE_ADDON_TOOLTIP"),
      getFunc = function() return ResearchPanel.charVars.enabled end,
      setFunc = function(value) 
        ResearchPanel.charVars.enabled = value 
        if ResearchPanelContainer:IsHidden() == false then ResearchPanelContainer:SetHidden(true) end
      end,
      default = ResearchPanel.characterDefaults.enabled,
    },
    {
      type = "dropdown",
      name = ResearchPanel:L("THEME_LABEL"),
      tooltip = ResearchPanel:L("THEME_TOOLTIP"),
      choices = { ResearchPanel:L("LIGHT_MODE"), ResearchPanel:L("GRAY_MODE"), ResearchPanel:L("DARK_MODE") },
      choicesValues = { RESEARCHPANEL_LIGHT_MODE, RESEARCHPANEL_GRAY_MODE, RESEARCHPANEL_DARK_MODE },
      getFunc = function() return ResearchPanel.savedVars.theme end,
      setFunc = function(value)
        ResearchPanel.savedVars.theme = value
        ResearchPanel:updatePosition()
      end,
      default = ResearchPanel.defaultSettings.theme,
    },
    {
      type = "slider",
      name = ResearchPanel:L("TRANSPARENCY_LABEL"),
      tooltip = ResearchPanel:L("TRANSPARENCY_TOOLTIP"),
      min = 0,
      max = 1,
      step = 0.05,
      getFunc = function() return 1 - ResearchPanel.savedVars.transparency end,
      setFunc = function(value)
        ResearchPanel.savedVars.transparency = 1 - value
        if ResearchPanelContainer:IsHidden() then ResearchPanelContainer:SetHidden(false) end
        ResearchPanel:updatePosition()
      end,
      default = 1 - ResearchPanel.defaultSettings.transparency,
    },
     {
      type = "checkbox",
      name = ResearchPanel:L("HIGHLIGHT_EMPTY_SLOTS_LABEL"),
      tooltip = ResearchPanel:L("HIGHLIGHT_EMPTY_SLOTS_TOOLTIP"),
      getFunc = function() return ResearchPanel.savedVars.highlightUnusedSlots end,
      setFunc = function(value)
        ResearchPanel.savedVars.highlightUnusedSlots = value
        ResearchPanel:update()
      end,
      default = ResearchPanel.defaultSettings.highlightUnusedSlots,
    },
    {
      type = "slider",
      name = ResearchPanel:L("HORIZONTAL_OFFSET_LABEL"),
      tooltip = ResearchPanel:L("HORIZONTAL_OFFSET_TOOLTIP"),
      min = 0,
      max = 3000,
      step = 5,
      getFunc = function() return ResearchPanel.savedVars.offsetX end,
      setFunc = function(value) 
        ResearchPanel.savedVars.offsetX = value 
        if ResearchPanelContainer:IsHidden() then ResearchPanelContainer:SetHidden(false) end
        ResearchPanel:updatePosition()
      end,
      default = ResearchPanel.defaultSettings.offsetX,
    },
    {
      type = "slider",
      name = ResearchPanel:L("VERTICAL_OFFSET_LABEL"),
      tooltip = ResearchPanel:L("VERTICAL_OFFSET_TOOLTIP"),
      min = 0,
      max = 2000,
      step = 5,
      getFunc = function() return -ResearchPanel.savedVars.offsetY end,
      setFunc = function(value) 
        ResearchPanel.savedVars.offsetY = -value 
        if ResearchPanelContainer:IsHidden() then ResearchPanelContainer:SetHidden(false) end
        ResearchPanel:updatePosition()
      end,
      default = -ResearchPanel.defaultSettings.offsetY,
    },
  }

  LAM:RegisterOptionControls(ResearchPanel.name .. "Panel", optionsData)
end
