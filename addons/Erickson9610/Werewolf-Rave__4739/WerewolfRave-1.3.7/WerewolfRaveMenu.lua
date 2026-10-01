--[[
    If LibAddonMenu-2.0 is installed, this will add a menu for this addon.
]]

WerewolfRave = WerewolfRave or {}
local WWR = WerewolfRave

WWR.optionsData = {}
WWR.panel = nil
WWR.panelName = "WerewolfRaveOptions"
WWR.panelData = {}

-- constants
WWR.STYLESEQUENCE_ICON_SIZE = 64
WWR.STYLESEQUENCE_MAX_COLUMNS = 3
WWR.STYLESEQUENCE_VISIBLE_ROWS = 2


function WWR.GetRandom()
    return WWR.savedVars.randomized
end

function WWR.SetRandom(value)
    if (value == true) then
        WWR.randomized = true
        WWR.savedVars.randomized = true
    else
        WWR.randomized = false
        WWR.savedVars.randomized = false
    end
end

function WWR.GetForceNewIndex()
    return WWR.savedVars.randomizedPickNew
end

function WWR.SetForceNewIndex(value)
    if (value == true) then
        WWR.randomizedPickNew = true
        WWR.savedVars.randomizedPickNew = true
    else
        WWR.randomizedPickNew = false
        WWR.savedVars.randomizedPickNew = false
    end
end

function WWR.GetAuto()
    return WWR.savedVars.allowChangeWhenAuto
end

function WWR.SetAuto(value)
    if (value == true) then
        WWR.allowChangeWhenAuto = true
        WWR.savedVars.allowChangeWhenAuto = true
    else
        WWR.allowChangeWhenAuto = false
        WWR.savedVars.allowChangeWhenAuto = false
    end
    WWR.UpdateFrequency() -- update the frequency, which also registers or unregisters the continuous update
end

function WWR.GetTF()
    return WWR.savedVars.allowChangeWhenTF
end

function WWR.SetTF(value)
    if (value == true) then
        WWR.allowChangeWhenTF = true
        WWR.savedVars.allowChangeWhenTF = true
    else
        WWR.allowChangeWhenTF = false
        WWR.savedVars.allowChangeWhenTF = false
    end
end

function WWR.GetCombat()
    return WWR.savedVars.enabledInCombat
end

function WWR.SetCombat(value)
    if (value == true) then
        WWR.enabledInCombat = true
        WWR.savedVars.enabledInCombat = true
    else
        WWR.enabledInCombat = false
        WWR.savedVars.enabledInCombat = false
    end
end

function WWR.GetFrequency()
    return WWR.savedVars.frequency
end

--[[function WWR.SetFrequency(value)
    
    WWR.frequency = value
    WWR.savedVars.frequency = value
    WWR.UpdateFrequency()
end]]

function WWR.GetCombatFrequency()
    return WWR.savedVars.frequencyInCombat
end

--[[function WWR.SetCombatFrequency(value)
    WWR.frequencyInCombat = value
    WWR.savedVars.frequencyInCombat = value
    WWR.UpdateFrequency()
end]]

function WWR.GetStyleSequence(index) -- returns the icon of the skill at this index in the chosenStyleList
    index = tonumber(index)
    -- return chosenStyleList icon at this index
    return GetCollectibleIcon(WWR.savedVars.chosenStyleList[index])
end

function WWR.SetStyleSequence(index, value) -- sets the style at this index in the chosenStyleList, picked by the user via icon
    index = tonumber(index)
    value = tonumber(value)

    WWR.SetList(false, index, value)
end


function WWR.GetStyleSequence(index) -- returns the icon of the skill at this index in the chosenStyleList
    index = tonumber(index)
    -- return chosenStyleList icon at this index
    return GetCollectibleIcon(WWR.savedVars.chosenStyleList[index])
end

function WWR.SetStyleSequence(index, value) -- sets the style at this index in the chosenStyleList, picked by the user via icon
    index = tonumber(index)
    value = tonumber(value)

    WWR.SetList(false, index, value)
end

function WWR.AddNewStyleRow()
    -- determine the default style
    local defaultStyle = nil
    local currentStyle = nil
    for i = 1, #WWR.discoveredStyleList do
        currentStyle = WWR.discoveredStyleList[i]
        if (IsCollectibleUnlocked(currentStyle)) then
            defaultStyle = currentStyle -- default style is the first unlocked style discovered
            break
        end
    end

    if (defaultStyle == nil) then return end -- if there are no styles unlocked, return

    -- create a new row internally
    WWR.SetList(false, "new", defaultStyle)

    -- create a new row in the gui
    WWR.optionsData[#WWR.optionsData + 1] =
    {
        type = "iconpicker",
        name = tostring(i),
        choices = styleSequenceImages,
        choicesTooltips = styleSequenceNames,
        iconSize = WWR.STYLESEQUENCE_ICON_SIZE,
        maxColumns = WWR.STYLESEQUENCE_MAX_COLUMNS,
        visibleRows = WWR.STYLESEQUENCE_VISIBLE_ROWS,
        getFunc = function() return WWR.GetStyleSequence(i) end,
        setFunc = function(value) WWR.SetStyleSequence(i, styleSequenceImageToID[value]) end
    }
end

function WWR.RemoveLastStyleRow()
    if (#WWR.savedVars.chosenStyleList > 0) then
        -- remove the last element from the internal list
        WWR.SetList(false, "new", "nil")

        -- set the last entry of the optionsData table to nil
        WWR.optionsData[#WWR.optionsData] = nil
    end
end

function WWR.InitializeMenu()
    if (LibAddonMenu2) then
        -- addon is installed
        local LAM2 = LibAddonMenu2

        WWR.panelData = {}
        WWR.panelData.type = "panel"
        WWR.panelData.name = "Werewolf Rave"
        WWR.panelData.displayName = "|c3D3D4CWere|c8F807Ewolf |cE3E0E0Rave|r"
        WWR.panelData.author = "@Erickson9610"
        WWR.panelData.keywords = "werewolf"
        WWR.panelData.slashCommand = "/wwrui"
        WWR.panelData.registerForRefresh = true

        -- build valid icon picker options
        local styleSequenceImages = {}
        local styleSequenceNames = {}
        local styleSequenceImageToID = {}
        for i = 1, #WWR.discoveredStyleList do
            local currentStyle = WWR.discoveredStyleList[i]
            if (IsCollectibleUnlocked(currentStyle)) then
                styleSequenceImages[#styleSequenceImages + 1] = GetCollectibleIcon(currentStyle)
                styleSequenceNames[#styleSequenceNames + 1] = GetCollectibleName(currentStyle)
                styleSequenceImageToID[GetCollectibleIcon(currentStyle)] = currentStyle
            end
        end

        WWR.optionsData = {
            {
                type = "description",
                text = "Werewolf Rave automatically equips Werewolf Form Skill Styles depending on the selected activation methods, according to your custom style sequence.\n\nUse this addon to shuffle between your unlocked styles, loop through them in a sequence, give a weighted chance for certain styles to appear, and more!"
            },
            {
                type = "header",
                name = "Activation Methods",
                width = "full"
            },
            {
                type = "checkbox",
                name = "Activate continuously while transformed",
                tooltip = "Enables continuous swapping of Werewolf Form styles while transformed. Use this if you want to continuously change your fur color!",
                getFunc = function() 
                    return WWR.GetAuto() 
                end,
                setFunc = function(value) 
                    WWR.SetAuto(value)
                end
            },
            {
                type = "checkbox",
                name = "Activate every time you revert form",
                tooltip = "Change your Werewolf Form style every time you revert form. Use this if you want to look different when you transform again!",
                getFunc = function() 
                    return WWR.GetTF()
                end,
                setFunc = function(value) 
                    WWR.SetTF(value)
                end
            },
            {
                type = "header",
                name = "Settings",
                width = "full"
            },
            {
                type = "dropdown",
                name = "Selection Method",
                choices = {"Randomized", "Sequential"},
                choicesValues = {true, false},
                choicesTooltips = {"The next style will be randomly selected.", "The next style will be the next in the sequence."},
                tooltip = "Determines whether the style sequence should be iterated through in a sequence, or treated as a list of weighted probabilities.",
                getFunc = function()
                    return WWR.GetRandom()
                end,
                setFunc = function(value)
                    WWR.SetRandom(value)
                end
            },
            {
                type = "checkbox",
                name = "Allow style changes while in combat",
                tooltip = "Allows Werewolf Rave to change your equipped style while you are in combat.",
                warning = "|cFF0000Style changes will delay ability casts!|r Adjust the frequency to make interrupts less likely or leave this disabled!",
                getFunc = function() 
                    return WWR.GetCombat()
                end,
                setFunc = function(value) 
                    WWR.SetCombat(value)
                end
            },
            {
                type = "checkbox",
                name = "Force new random index",
                tooltip = "Forces the next index selected in the randomized mode to be a new index, picking from N-1 elements rather than from all N elements of your style sequence.",
                getFunc = function()
                    return WWR.GetForceNewIndex()
                end,
                setFunc = function(value)
                    WWR.SetForceNewIndex(value)
                end,
                disabled = function() 
                    return (not WWR.randomized)
                end
            },
            {
                type = "slider",
                name = "Frequency",
                tooltip = "Determines the out-of-combat interval between style changes in seconds in the continuous mode.",
                getFunc = function()
                    return WWR.GetFrequency()
                end,
                setFunc = function(value)
                    WWR.SetFrequency(false, value)
                end,
                disabled = function() 
                    return (not WWR.allowChangeWhenAuto)
                end,
                min = WWR.FREQUENCY_LOWER,
                max = WWR.FREQUENCY_UPPER
            },
            {
                type = "slider",
                name = "Frequency (in combat)",
                tooltip = "Determines the in-combat interval between style changes in seconds in the continuous mode.",
                getFunc = function()
                    return WWR.GetCombatFrequency()
                end,
                setFunc = function(value)
                    WWR.SetCombatFrequency(false, value)
                end,
                disabled = function() 
                    return (not WWR.allowChangeWhenAuto or not WWR.enabledInCombat)
                end,
                min = WWR.FREQUENCY_COMBAT_LOWER,
                max = WWR.FREQUENCY_COMBAT_UPPER
            },
            {
                type = "header",
                name = "Style Sequence",
                width = "full"
            },
            {
                type = "description",
                text = '|cFF0000Reload the UI to see changes to the list size!|r Alternatively, you can edit the list with /wwr idtable, /wwr getlist, and /wwr setlist <index> <styleID>.'
            },
            {
                type = "button",
                name = "Add New",
                tooltip = "Create a new entry at the end of the list.",
                width = "half",
                func = function()
                    return WWR.AddNewStyleRow()
                end
            },
            {
                type = "button",
                name = "Remove Last",
                tooltip = "Remove the last entry from the end of the list.",
                width = "half",
                func = function() 
                    return WWR.RemoveLastStyleRow()
                end
            } -- 14th
            --[[{  
                type = "iconpicker",
                name = "1",
                choices = styleSequenceImages,
                choicesTooltips = styleSequenceNames,
                iconSize = WerewolfRaveMenu.STYLESEQUENCE_ICON_SIZE,
                maxColumns = WerewolfRaveMenu.STYLESEQUENCE_MAX_COLUMNS,
                visibleRows = WerewolfRaveMenu.STYLESEQUENCE_VISIBLE_ROWS,
                getFunc = function()
                    return WerewolfRaveMenu.GetStyleSequence(WerewolfRaveMenu.optionsData[14].name)
                end,
                setFunc = function(value) 
                    WerewolfRaveMenu.SetStyleSequence(WerewolfRaveMenu.optionsData[14].name, styleSequenceImageToID[value])
                end
            }]]

        }
        
        -- now generate and append iconpicker options to the optionsData table to represent entries in the chosenStyleList
        local currentRow = 0
        for i = 1, #WWR.savedVars.chosenStyleList do
            -- populate each row with the data corresponding to an entry in chosenStyleList
            currentRow = #WWR.optionsData + 1
            WWR.optionsData[currentRow] =
            {
                type = "iconpicker",
                name = tostring(i),
                choices = styleSequenceImages,
                choicesTooltips = styleSequenceNames,
                iconSize = WWR.STYLESEQUENCE_ICON_SIZE,
                maxColumns = WWR.STYLESEQUENCE_MAX_COLUMNS,
                visibleRows = WWR.STYLESEQUENCE_VISIBLE_ROWS,
                getFunc = function() return WWR.GetStyleSequence(i) end,
                setFunc = function(value) WWR.SetStyleSequence(i, styleSequenceImageToID[value]) end
            }
        end
        
        WWR.panel = LibAddonMenu2:RegisterAddonPanel(WWR.panelName, WWR.panelData)
        LibAddonMenu2:RegisterOptionControls(WWR.panelName, WWR.optionsData)
    end
end