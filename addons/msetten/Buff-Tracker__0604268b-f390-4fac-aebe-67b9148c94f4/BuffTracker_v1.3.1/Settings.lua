BuffTracker = BuffTracker or {}
local Utils = BuffTracker.Utils
BuffTracker.version = "1.3.1"
BuffTracker.author = "msetten"
BuffTracker.savedVars = BuffTracker.savedVars or { 
    offsetX = 0,
    offsetY = 0,
    fontSize = 40,
    maxItems = 6,
    debug = false,
    invertSort = false,
    useSeperateOffsets = false,
    offsetXDebuff = 0,
    offsetYDebuff = 0
}
BuffTracker.charVars = BuffTracker.charVars or {
      enabled = true,
      majorBuffs = {},
      majorDebuffs = {},
      minorBuffs = {},
      minorDebuffs = {},
      cooldowns = {},
	    seteffects = {},
      trials = {},
      allOtherBuffs = 0;
      allOtherDebuffs = 0;
}
BuffTracker.subPanelDelay = 250

BUFFTRACKER_SORTING_EXPIRE_ASC = 0
BUFFTRACKER_SORTING_EXPIRE_DESC = 1
BUFFTRACKER_SORTING_TYPE_EXPIRE_ASC = 2
BUFFTRACKER_SORTING_TYPE_EXPIRE_DESC = 3
BUFFTRACKER_SORTING_NAME_ASC = 4
BUFFTRACKER_SORTING_NAME_DESC = 5

local panelName = "BuffTrackerPanel"
local optionsTable = {}
local currentAllValue = 0
BuffTracker.majorBuffsPanel = {}
BuffTracker.minorBuffsPanel = {}
BuffTracker.majorDebuffsPanel = {}
BuffTracker.minorDebuffsPanel = {}
BuffTracker.seteffectsPanel = {}
BuffTracker.trialmechanicsPanel = {}
BuffTracker.cooldownsPanel = {}

local function createSubPanel(headerAll, headerIndividual, typeName, buffsTable) 
    local currentAllValue = 0
    local currentAllKeepShowing = false
    local panel = {}

    for buff in Utils.GetValues(buffsTable) do
      currentAllValue = math.max(currentAllValue, buff.threshold)
    end

    local section = {
      type = "header",
      name = headerAll,
    }
    table.insert(panel, section)

    local sliderAll = {
      type = "slider",
      name = Utils.L("THRESHOLD"),
      tooltip = Utils.L("ALL_TOOLTIP", typeName, typeName),
      setFunc = function(value)
        currentAllValue = value
      end,
      getFunc = function()
        return currentAllValue
      end,
      default = 30,
      min = 0,
      max = 60,
      step = 1,
      unit = "s", --optional unit
      format = "%d", --value format
    }

    table.insert(panel, sliderAll)

    local applyAllThreshold = {
      type = "button",
      name = Utils.L("APPLY_ALL"),
      tooltip = Utils.L("APPLY_ALL_TOOLTIP", typeName),
      func = function(control, button)
        for buff in Utils.GetValues(buffsTable) do
          buff.threshold = currentAllValue
        end
      end
    }
    table.insert(panel, applyAllThreshold)

    local keepshowingAll = {
      type = "checkbox",
      name = Utils.L("KEEP_SHOWING_ALL"),
      tooltip = Utils.L("KEEP_SHOWING_ALL_TOOLTIP", typeName),
      setFunc = function(value)
          currentAllKeepShowing = value
      end,
      getFunc = function()
          return currentAllKeepShowing
      end,
      default = false
    }

    table.insert(panel, keepshowingAll)

    local applyAllKeepShowing = {
      type = "button",
      name = Utils.L("APPLY_ALL"),
      tooltip = Utils.L("APPLY_ALL_KEEP_SHOWING_TOOLTIP", typeName, typeName),
      func = function(control, button)
        for buff in Utils.GetValues(buffsTable) do
          buff.keepshowing = currentAllKeepShowing
        end
      end
    }

    table.insert(panel, applyAllKeepShowing)

    for buff in Utils.GetValues(buffsTable) do
        local buffName = GetAbilityName(buff.abilityId)

        local section = {
          type = "header",
          name = buffName,
        }
        table.insert(panel, section)

        local slider = {
            type = "slider",
            name = Utils.L("THRESHOLD"),
            tooltip = Utils.L("COUNTDOWN_TOOLTIP", buffName),
            setFunc = function(value)
                buff.threshold = value
            end,
            getFunc = function()
                return buff.threshold
            end,
            default = 30,
            min = 0,
            max = 60,
            step = 1,
            unit = "s", --optional unit
            format = "%d", --value format
        }
        table.insert(panel, slider)
        local checkbox = {
            type = "checkbox",
            name = Utils.L("KEEP_SHOWING"),
            tooltip = Utils.L("KEEP_SHOWING_TOOLTIP", buffName),
            setFunc = function(value)
                buff.keepshowing = value
            end,
            getFunc = function()
                return buff.keepshowing
            end,
        }
        table.insert(panel, checkbox)

        local divider = {
          type = "divider",
        }
        table.insert(panel, divider)
      end

      return panel
end

local function createSubPanelTrials(headerAll, headerIndividual, typeName, trialsTable) 
    local panel = {}
    local section = {
      type = "header",
      name = headerAll,
    }
    table.insert(panel, section)

    local enableAll = {
      type = "button",
      name = Utils.L("ENABLE_ALL"),
      tooltip = Utils.L("ENABLE_ALL_TOOLTIP"),
      func = function(control, button)
        for trial in Utils.GetValues(trialsTable) do
          trial.enabled = true
        end
      end
    }

    table.insert(panel, enableAll)

    local disableAll = {
      type = "button",
      name = Utils.L("DISABLE_ALL"),
      tooltip = Utils.L("DISABLE_ALL_TOOLTIP"),
      func = function(control, button)
        for trial in Utils.GetValues(trialsTable) do
          trial.enabled = false
        end
      end
    }

    table.insert(panel, disableAll)

    local section = {
      type = "header",
      name = headerIndividual,
    }
    table.insert(panel, section)

    for trial in Utils.GetValues(trialsTable) do
        local trialName = trial.trial or Utils.L("UNKNOWN_TRIAL")
        local checkbox = {
            type = "checkbox",
            name = trialName,
            tooltip = Utils.L("TOGGLE_TRIAL_TOOLTIP", trialName),
            setFunc = function(value)
                trial.enabled = value
            end,
            getFunc = function()
                return trial.enabled
            end,
        }
        table.insert(panel, checkbox)
    end
    return panel
end

function BuffTracker.startCreationOfSubPanels()
     BuffTracker.majorBuffsPanel = createSubPanel(Utils.L("ALL_MAJOR_BUFFS"), Utils.L("INDIVIDUAL_MAJOR_BUFFS"), Utils.L("MAJOR_BUFFS"), BuffTracker.charVars.majorBuffs)
     --d("Created majorBuffsPanel.")
     zo_callLater(function()
        BuffTracker.minorBuffsPanel = createSubPanel(Utils.L("ALL_MINOR_BUFFS"), Utils.L("INDIVIDUAL_MINOR_BUFFS"), Utils.L("MINOR_BUFFS"), BuffTracker.charVars.minorBuffs)
        --d("Created minorBuffsPanel.")
        zo_callLater(function()
            BuffTracker.majorDebuffsPanel = createSubPanel(Utils.L("ALL_MAJOR_DEBUFFS"), Utils.L("INDIVIDUAL_MAJOR_DEBUFFS"), Utils.L("MAJOR_DEBUFFS"), BuffTracker.charVars.majorDebuffs)
            --d("Created majorDebuffsPanel.")
            zo_callLater(function()
                BuffTracker.minorDebuffsPanel = createSubPanel(Utils.L("ALL_MINOR_DEBUFFS"), Utils.L("INDIVIDUAL_MINOR_DEBUFFS"), Utils.L("MINOR_DEBUFFS"), BuffTracker.charVars.minorDebuffs)
                --d("Created minorDebuffsPanel.")
                zo_callLater(function()
                    BuffTracker.seteffectsPanel = createSubPanel(Utils.L("ALL_SET_EFFECTS"), Utils.L("INDIVIDUAL_SET_EFFECTS"), Utils.L("SET_EFFECTS"), BuffTracker.charVars.seteffects)
                    --d("Created seteffectsPanel.")
                    zo_callLater(function()
                        BuffTracker.trialmechanicsPanel = createSubPanelTrials(Utils.L("ALL_TRIAL_MECHANICS"), Utils.L("INDIVIDUAL_TRIAL_MECHANICS"), Utils.L("TRIAL_MECHANICS"), BuffTracker.charVars.trials)
                       --d("Created trialmechanicsPanel.")
                        zo_callLater(function()
                            BuffTracker.cooldownsPanel = createSubPanel(Utils.L("ALL_COOLDOWNS"), Utils.L("INDIVIDUAL_COOLDOWNS"), Utils.L("COOLDOWNS"), BuffTracker.charVars.cooldowns)
                            --d("Created cooldownsPanel.")
                            BuffTracker.continueCreateSettings()
                        end, BuffTracker.subPanelDelay)                    
                    end, BuffTracker.subPanelDelay)
                end, BuffTracker.subPanelDelay)
            end, BuffTracker.subPanelDelay)
        end, BuffTracker.subPanelDelay)
    end, BuffTracker.subPanelDelay)
end

function BuffTracker.CreateSettings()
    if IsConsoleUI() and not LibAddonMenu2 then return end

    BuffTracker.startCreationOfSubPanels()
end

function BuffTracker.continueCreateSettings()
    -- BuffTracker.majorBuffsPanel = createSubPanel(Utils.L("ALL_MAJOR_BUFFS"), Utils.L("INDIVIDUAL_MAJOR_BUFFS"), Utils.L("MAJOR_BUFFS"), BuffTracker.charVars.majorBuffs)
    -- BuffTracker.minorBuffsPanel = createSubPanel(Utils.L("ALL_MINOR_BUFFS"), Utils.L("INDIVIDUAL_MINOR_BUFFS"), Utils.L("MINOR_BUFFS"), BuffTracker.charVars.minorBuffs)
    -- BuffTracker.majorDebuffsPanel = createSubPanel(Utils.L("ALL_MAJOR_DEBUFFS"), Utils.L("INDIVIDUAL_MAJOR_DEBUFFS"), Utils.L("MAJOR_DEBUFFS"), BuffTracker.charVars.majorDebuffs)
    -- BuffTracker.minorDebuffsPanel = createSubPanel(Utils.L("ALL_MINOR_DEBUFFS"), Utils.L("INDIVIDUAL_MINOR_DEBUFFS"), Utils.L("MINOR_DEBUFFS"), BuffTracker.charVars.minorDebuffs)
    -- BuffTracker.seteffectsPanel = createSubPanel(Utils.L("ALL_SET_EFFECTS"), Utils.L("INDIVIDUAL_SET_EFFECTS"), Utils.L("SET_EFFECTS"), BuffTracker.charVars.seteffects)
    -- BuffTracker.trialmechanicsPanel = createSubPanelTrials(Utils.L("ALL_TRIAL_MECHANICS"), Utils.L("INDIVIDUAL_TRIAL_MECHANICS"), Utils.L("TRIAL_MECHANICS"), BuffTracker.charVars.trials)
    -- BuffTracker.cooldownsPanel = createSubPanel(Utils.L("ALL_COOLDOWNS"), Utils.L("INDIVIDUAL_COOLDOWNS"), Utils.L("COOLDOWNS"), BuffTracker.charVars.cooldowns)

    -- d(BuffTracker.majorBuffsPanel)

    optionsTable = {
        {
          type = "header",
          name = Utils.L("DISPLAY_SETTINGS"),
          width = "full",
        },
        -- {
        --     type = "checkbox",
        --     name = Utils.L("SEPERATE_TRACKERS"),
        --     tooltip = Utils.L("SEPERATE_TRACKERS_TOOLTIP"),
        --     getFunc = function() return BuffTracker.savedVars.useSeperateOffsets end,
        --     setFunc = function(value) 
        --       BuffTracker.savedVars.useSeperateOffsets = value 
        --       if value then
                
        --       end
        --     end,
        --     width = "full",
        -- },
        {
            type = "slider",
            name = Utils.L("HORIZONTAL_OFFSET"),
            tooltip = Utils.L("HORIZONTAL_OFFSET_TOOLTIP"),
            min = -1250,
            max = 1250,
            step = 2,
            getFunc = function() return BuffTracker.savedVars.offsetX end,
            setFunc = function(value)
              BuffTracker.savedVars.offsetX = value
              BuffTrackerContainer:ClearAnchors()
              BuffTrackerContainer:SetAnchor(CENTER, GuiRoot, CENTER, BuffTracker.savedVars.offsetX, BuffTracker.savedVars.offsetY)
            end,
        },
        {
            type = "slider",
            name = Utils.L("VERTICAL_OFFSET"),
            tooltip = Utils.L("VERTICAL_OFFSET_TOOLTIP"),
            min = -750,
            max = 750,
            step = 2,
            getFunc = function() return BuffTracker.savedVars.offsetY end,
            setFunc = function(value)
              BuffTracker.savedVars.offsetY = value
              BuffTrackerContainer:ClearAnchors()
              BuffTrackerContainer:SetAnchor(CENTER, GuiRoot, CENTER, BuffTracker.savedVars.offsetX, BuffTracker.savedVars.offsetY)
            end,
        },
        -- {
        --     type = "slider",
        --     name = Utils.L("HORIZONTAL_OFFSET_DEBUFFS"),
        --     tooltip = Utils.L("HORIZONTAL_OFFSET_DEBUFFS_TOOLTIP"),
        --     min = -1250,
        --     max = 1250,
        --     step = 2,
        --     getFunc = function() return BuffTracker.savedVars.offsetXDebuff end,
        --     setFunc = function(value)
        --       BuffTracker.savedVars.offsetXDebuff = value
        --       DebuffTrackerContainer:ClearAnchors()
        --       DebuffTrackerContainer:SetAnchor(CENTER, GuiRoot, CENTER, DebuffTracker.savedVars.offsetXDebuff, DebuffTracker.savedVars.offsetYDebuff)
        --     end,
        --     enabled = function() return BuffTracker.savedVars.useSeperateOffsets end,
        -- },
        -- {
        --     type = "slider",
        --     name = Utils.L("VERTICAL_OFFSET_DEBUFFS"),
        --     tooltip = Utils.L("VERTICAL_OFFSET_DEBUFFS_TOOLTIP"),
        --     min = -750,
        --     max = 750,
        --     step = 2,
        --     getFunc = function() return BuffTracker.savedVars.offsetYDebuff end,
        --     setFunc = function(value)
        --       BuffTracker.savedVars.offsetYDebuff = value
        --       DebuffTrackerContainer:ClearAnchors()
        --       DebuffTrackerContainer:SetAnchor(CENTER, GuiRoot, CENTER, BuffTracker.savedVars.offsetXDebuff, BuffTracker.savedVars.offsetYDebuff)
        --     end,
        --     enabled = function() return BuffTracker.savedVars.useSeperateOffsets end,
        -- },
        {
            type = "slider",
            name = Utils.L("FONT_SIZE"),
            tooltip = Utils.L("FONT_SIZE_TOOLTIP"),
            min = 30,
            max = 80,
            step = 2,
            getFunc = function() return BuffTracker.savedVars.fontSize end,
            setFunc = function(value)
              BuffTracker.savedVars.fontSize = value
            end,
        },
        {
            type = "slider",
            name = Utils.L("MAXIMUM_AMOUNT"),
            tooltip = Utils.L("MAXIMUM_AMOUNT_TOOLTIP"),
            min = 2,
            max = 12,
            step = 1,
            getFunc = function() return BuffTracker.savedVars.maxItems end,
            setFunc = function(value)
              BuffTracker.savedVars.maxItems = value
              if BuffTracker.amountOfControls > value then
                BuffTracker.hideControls(value)
              end
            end,
        },
        {
            type = "dropdown",
            name = Utils.L("SORTING"),
            tooltip = Utils.L("SORTING_TOOLTIP"),
            choices = {
              Utils.L("SORTING_EXPIRE_ASC"),
              Utils.L("SORTING_EXPIRE_DESC"),
              Utils.L("SORTING_TYPE_EXPIRE_ASC"),
              Utils.L("SORTING_TYPE_EXPIRE_DESC"),
              Utils.L("SORTING_NAME_ASC"),
              Utils.L("SORTING_NAME_DESC")
            },
            choicesValues = {
              BUFFTRACKER_SORTING_EXPIRE_ASC,
              BUFFTRACKER_SORTING_EXPIRE_DESC,
              BUFFTRACKER_SORTING_TYPE_EXPIRE_ASC,
              BUFFTRACKER_SORTING_TYPE_EXPIRE_DESC,
              BUFFTRACKER_SORTING_NAME_ASC,
              BUFFTRACKER_SORTING_NAME_DESC
            },
            getFunc = function() return BuffTracker.savedVars.sorting end,
            setFunc = function(value)
              BuffTracker.savedVars.sorting = value
            end,
        },
        {
          type = "header",
          name = Utils.L("BUFFS_MENU"),
          width = "full",
        },
        {
            type = "checkbox",
            name = Utils.L("ENABLE_TRACKER"),
            tooltip = Utils.L("ENABLE_TRACKER_TOOLTIP"),
            getFunc = function() return BuffTracker.charVars.enabled end,
            setFunc = function(value)
                BuffTracker.charVars.enabled = value
            end,
            width = "full",
        },
        { type = "submenu",
          name = Utils.L("MAJOR_BUFFS"),
          controls = BuffTracker.majorBuffsPanel,
        },
        { type = "submenu",
          name = Utils.L("MINOR_BUFFS"),
          controls = BuffTracker.minorBuffsPanel,
        },
        { type = "submenu",
          name = Utils.L("MAJOR_DEBUFFS"),
          controls = BuffTracker.majorDebuffsPanel,
        },
        { type = "submenu",
          name = Utils.L("MINOR_DEBUFFS"),
          controls = BuffTracker.minorDebuffsPanel,
        },
        {
          type = "header",
          name = Utils.L("EXPERIMENTAL"),
          width = "full",
        },
        { type = "submenu",
          name = Utils.L("SET_EFFECTS"),
          controls = BuffTracker.seteffectsPanel,
        },
        { type = "submenu",
          name = Utils.L("TRIAL_MECHANICS"),
          controls = BuffTracker.trialmechanicsPanel,
        },
        { type = "submenu",
          name = Utils.L("COOLDOWNS"),
          controls = BuffTracker.cooldownsPanel,
        },
        {
          type = "header",
          name = Utils.L("OTHER_BUFFS"),
          width = "full",
        }
    }

    table.insert(optionsTable, {
      type = "slider",
      name = Utils.L("ALL_OTHER_BUFFS"),
      tooltip = Utils.L("ALL_OTHER_BUFFS_TOOLTIP"),
      min = 0,
      max = 60,
      step = 1,
      disabled = function() return not BuffTracker.charVars.enabled end,
      getFunc = function() return BuffTracker.charVars.allOtherBuffs end,
      setFunc = function(value)
        BuffTracker.charVars.allOtherBuffs = value
      end,
    })

    table.insert(optionsTable, {
      type = "slider",
      name = Utils.L("ALL_OTHER_DEBUFFS"),
      tooltip = Utils.L("ALL_OTHER_DEBUFFS_TOOLTIP"),
      min = 0,
      max = 60,
      step = 1,
      disabled = function() return not BuffTracker.charVars.enabled end,
      getFunc = function() return BuffTracker.charVars.allOtherDebuffs end,
      setFunc = function(value)
        BuffTracker.charVars.allOtherDebuffs = value
      end,
    })

    table.insert(optionsTable, {
        type = "checkbox",
        name = Utils.L("DEBUG_TRACKER"),
        tooltip = Utils.L("DEBUG_TRACKER_TOOLTIP"),
        getFunc = function() return BuffTracker.savedVars.debug end,
        setFunc = function(value)
            BuffTracker.savedVars.debug = value
        end,
        width = "full",
    })

    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = Utils.L("BUFF_TRACKER_NAME"),
        displayName = Utils.L("BUFF_TRACKER_DISPLAYNAME"),
        author = BuffTracker.author or "Unknown Author",
        version = BuffTracker.version,
        registerForRefresh = true,
    })

    LibAddonMenu2:RegisterOptionControls(panelName, optionsTable)
end
