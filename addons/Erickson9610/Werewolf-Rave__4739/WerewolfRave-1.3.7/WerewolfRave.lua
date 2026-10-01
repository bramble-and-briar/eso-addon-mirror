--[[
    Add-On developed by Erickson9610
    No AI has been used in the development of this addon.

    As of Update 50, the ID Table reads:
    "Werewolf Form, Hircine's Hunter", ID: 14659
    "Werewolf Form, Black", ID: 14773
    "Werewolf Form, Ashen", ID: 14774
    "Werewolf Form, White", ID: 14775

    As of Update 51, the ID Table reads:
    "Werewolf Form, Red", ID: 14659
    "Werewolf Form, Black", ID: 14773
    "Werewolf Form, Ashen", ID: 14774
    "Werewolf Form, White", ID: 14775
    "Werewolf Form, Ragefire", ID: 14814

    This addon does not hardcode the above IDs, as I would need to update this addon every patch new styles are added otherwise.

    Instead, this addon will automatically search for any Skill Styles with the name containing "Werewolf Form" (or the equivalent for your game client language)
    and add them to the discovered list. It will then check to see if you have the style unlocked so it will determine if you can add it to your style sequence.
]]

WerewolfRave = WerewolfRave or {}
local WWR = WerewolfRave or {}
WWR.discoveredStyleList = {} -- the list of discovered Werewolf Form styles, used for display of all possible styles to choose from, equippable or not
WWR.chosenStyleList = {} -- the list of chosen Werewolf Form styles, used for randomizing and sequencing. These are the styles that the user wants to use and can equip
WWR.allowChangeWhenAuto = true -- enables or disables the continuous swap of skill styles while transformed
WWR.enabledInCombat = false -- enables or disables the automatic swap of skill styles while in combat
WWR.frequency = 3 -- the frequency of the automatic swap while not in combat
WWR.frequencyInCombat = 10 -- the frequency of the automatic swap while in combat
WWR.randomizedPickNew = true -- in the randomized selection mode, determines if the pool of potential next indices should exclude the current index; that is, with N elements, pick from N-1, which excludes the current element
WWR.randomized = true -- if true, the next style is randomly picked from the chosenStyleList. Otherwise, it loops through the chosenStyleList in a sequence
WWR.currentStyleIndex = 0 -- an index into chosenStyleList which corresponds to the current style that is equipped
WWR.currentStyleId = 0 -- the CollectibleID for the current skill style equipped
WWR.allowChangeWhenTF = false -- enables or disables the change of your fur style whenever you revert form

-- constants
WWR.NAME = "WerewolfRave"
WWR.FREQUENCY_LOWER = 2 -- the lower bound for out of combat frequency (WerewolfRave.frequency)
WWR.FREQUENCY_UPPER = 60 -- the upper bound for out of combat frequency (WerewolfRave.frequency)
WWR.FREQUENCY_COMBAT_LOWER = 2 -- the lower bound for in-combat frequency (WerewolfRave.frequencyInCombat)
WWR.FREQUENCY_COMBAT_UPPER = 60 -- the upper bound for in-combat frequency (WerewolfRave.frequencyInCombat)
WWR.VAR_VERSION = 3 -- the internal version of the saved variables. I will increment this if I restructure the data stored by this addon.

WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES = {} -- a table that matches the name of the Werewolf Form skill styles to the game language
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["en"] = "Werewolf Form"
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["fr"] = "Forme de loup%-garou" -- hyphens are special characters that need to be escaped
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["de"] = "Werwolf" -- skill styles for this Ultimate can be written as either "Werwolfgestalt" or "Werwolfverwandlung"
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["jp"] = "ウェアウルフ" -- similar to the above, some styles are listed as "Werewolf Form, <style>" or "Werewolf Transformation, <style>"
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["ru"] = "Обличье вервольфа"
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["es"] = "Forma lupina"
WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES["zh"] = "狼人形态"











function WWR.CreateAndSaveDefaultList() -- Creates and returns the default style list for first-time users, saving it in the process
    local defaultStyleList = {}
    WWR.savedVars.chosenStyleList = {}

    for i = 1, #WWR.discoveredStyleList do
        if (IsCollectibleUnlocked(WWR.discoveredStyleList[i])) then
            defaultStyleList[#defaultStyleList + 1] = WWR.discoveredStyleList[i]
            WWR.savedVars.chosenStyleList[#WWR.savedVars.chosenStyleList + 1] = WWR.discoveredStyleList[i]
        end
    end
    return defaultStyleList
end

function WWR.ResetChosenList() -- Resets the chosenStyleList to have one of every unlocked style
    -- This function should only run after BuildStyleList populates discoveredStyleList!
    WWR.chosenStyleList = {}
    WWR.savedVars.chosenStyleList = {}
    
    for i = 1, #WWR.discoveredStyleList do
        if (IsCollectibleUnlocked(WWR.discoveredStyleList[i])) then
            WWR.chosenStyleList[#WWR.chosenStyleList + 1] = WWR.discoveredStyleList[i]
            WWR.savedVars.chosenStyleList[#WWR.savedVars.chosenStyleList + 1] = WWR.discoveredStyleList[i] -- save changes
        end
    end
end

function WWR.BuildStyleList() -- Builds the discoveredStyleList based on which styles are discovered, then populates the chosenStyleList.
    WWR.discoveredStyleList = {}

    local language = ZoGetOfficialGameLanguageDescriptor()
    local targetString = WWR.SKILLSTYLE_LANGUAGE_NAME_MATCHES[language]

    --[[
        Search through GetCollectibleIdFromType(30, x) and add every collectibleId
        in which GetCollectibleName(collectibleId) contains a matching substring from
        the current language (e.g., "Werewolf Form" for English clients) to discoveredStyleList

        1 <= x <= GetTotalCollectiblesByCategoryType(30)
        category 30 corresponds to Skill Styles

        This will future-proof the addon so I will not need to manually update and maintain a list
        of known style IDs every time ZOS introduces a new Werewolf Form skill style.
    ]]
    for i = 1, GetTotalCollectiblesByCategoryType(30) do
        -- check for "Werewolf Form"
        local currentCollectibleId = GetCollectibleIdFromType(30, i)
        if (string.find(GetCollectibleName(currentCollectibleId), targetString)) then
            -- add found style to discovered list
            WWR.discoveredStyleList[#WWR.discoveredStyleList + 1] = currentCollectibleId
        end
    end
    --[[Again, all that the above does is try to find any and all Skill Styles that apply to Werewolf Transformation.
        Since there doesn't seem to be a way to link the known skill ID of Werewolf Transformation to an unknown number of skill style collectible IDs that apply to that skill ID,
        I am manually searching through the list of all skill styles and grabbing all of them whose *name* matches the naming convention of known Werewolf Form Skill Styles
        This will break if ZOS ever makes a Werewolf Transformation Skill Style that has a typo or a different naming convention! I really need a better way of linking these!]]
end

function WWR.UpdateFrequency() -- Determines whether the player is in combat, then registers the refresh to happen according to the corresponding frequency value.
    EVENT_MANAGER:UnregisterForUpdate(WWR.NAME .. "Loop")
    if (WWR.allowChangeWhenAuto == false) then return end -- if auto is disabled, return early
    if (IsUnitInCombat("player")) then
        -- use in-combat frequency
        EVENT_MANAGER:RegisterForUpdate(WWR.NAME .. "Loop", WWR.frequencyInCombat * 1000, function() WWR.ChangeStyleWhenAuto() end)
    else
        -- use out of combat frequency
        EVENT_MANAGER:RegisterForUpdate(WWR.NAME .. "Loop", WWR.frequency * 1000, function() WWR.ChangeStyleWhenAuto() end)
    end
end

function WWR.ToggleAuto(printOutput) -- Toggles the automatic mode on or off
    if (WWR.allowChangeWhenAuto) then -- disable wwr
        WWR.allowChangeWhenAuto = false
        if (printOutput) then d("[WWR] Automatic style change disabled!") end
    else -- enable wwr
        WWR.allowChangeWhenAuto = true
        if (printOutput) then d("[WWR] Automatic style change enabled!") end
    end
    WWR.savedVars.allowChangeWhenAuto = WWR.allowChangeWhenAuto -- save changes
    WWR.UpdateFrequency() -- update the frequency, which also registers or unregisters the continuous update
end

function WWR.ToggleTF(printOutput) -- Toggles transformation as a trigger for changing styles
    if (WWR.allowChangeWhenTF) then -- toggle tf off
        WWR.allowChangeWhenTF = false
        if (printOutput) then d("[WWR] Style change on transformation disabled!") end
    else -- toggle tf on
        WWR.allowChangeWhenTF = true
        if (printOutput) then d("[WWR] Style change on transformation enabled!") end
    end
    WWR.savedVars.allowChangeWhenTF = WWR.allowChangeWhenTF -- save changes
end

function WWR.ToggleCombat(printOutput) -- Toggles whether styles can be changed in combat
    if (WWR.enabledInCombat) then -- toggle in-combat off
        WWR.enabledInCombat = false
        if (printOutput) then d("[WWR] Style change in combat disabled!") end
    else -- toggle in-combat on
        WWR.enabledInCombat = true
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Style change in combat enabled!") end
    end
    WWR.savedVars.enabledInCombat = WWR.enabledInCombat -- save changes
end

function WWR.ToggleRandomOrSequential(printOutput) -- Toggles whether the next style picked is random or in sequence
    if (WWR.randomized) then -- toggle random order off
        WWR.randomized = false
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Style order is now sequential!") end
    else -- toggle random order on
        WWR.randomized = true
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Style order is now randomized!") end
    end
    WWR.savedVars.randomized = WWR.randomized -- save changes
end

function WWR.SetFrequency(printOutput, seconds) -- Sets the out of combat frequency of the automatic mode
    -- convert seconds to number
    numSeconds = tonumber(seconds)
    if(numSeconds == nil) then
        if (printOutput) then d("[WWR] Invalid number of seconds for frequency command.") end
    else
        -- bounds check
        if (numSeconds < WWR.FREQUENCY_LOWER) then
            numSeconds = WWR.FREQUENCY_LOWER
        elseif (numSeconds > WWR.FREQUENCY_UPPER) then
            numSeconds = WWR.FREQUENCY_UPPER
        end

        WWR.frequency = numSeconds
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Out of combat frequency set to " .. WWR.frequency) end
        WWR.savedVars.frequency = WWR.frequency -- save changes
    end
end

function WWR.SetCombatFrequency(printOutput, seconds) -- Sets the in-combat frequency of the automatic mode
    -- convert seconds to number
    numSeconds = tonumber(seconds)
    if(numSeconds == nil) then
        if (printOutput) then d("[WWR] Invalid number of seconds for cfrequency command.") end
    else
        -- bounds check
        if (numSeconds < WWR.FREQUENCY_COMBAT_LOWER) then
            numSeconds = WWR.FREQUENCY_COMBAT_LOWER
        elseif (numSeconds > WWR.FREQUENCY_COMBAT_UPPER) then
            numSeconds = WWR.FREQUENCY_COMBAT_UPPER
        end

        WWR.frequencyInCombat = numSeconds
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] In combat frequency set to " .. WWR.frequencyInCombat) end
        WWR.savedVars.frequencyInCombat = WWR.frequencyInCombat -- save changes
    end
end

function WWR.ToggleForceNewIndex(printOutput) -- Toggles whether the randomized mode always picks a new index
    if (WWR.randomizedPickNew) then -- toggle off
        WWR.randomizedPickNew = false
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Randomized mode can pick from N elements!") end
    else -- toggle on
        WWR.randomizedPickNew = true
        WWR.UpdateFrequency()
        if (printOutput) then d("[WWR] Randomized mode can pick from N-1 elements!") end
    end
    WWR.savedVars.randomizedPickNew = WWR.randomizedPickNew -- save changes
end

function WWR.SetList(printOutput, listIndex, styleId) -- Modifies the element at a specific index, for Create, Update, and Delete functionality
    local indexNum = nil
    if (listIndex == "new") then
        if (styleId == "nil") then -- "new nil" to remove last element
            if (#WWR.chosenStyleList > 0) then
                WWR.chosenStyleList[#WWR.chosenStyleList] = nil
                WWR.savedVars.chosenStyleList[#WWR.savedVars.chosenStyleList] = nil -- save remove element change
                if (printOutput) then d("[WWR] The style list size has been reduced to " .. #WWR.chosenStyleList) end
            else
                if (printOutput) then d("[WWR] No more entries to remove from the style list!") end
            end
            return
        else
            indexNum = #WWR.chosenStyleList+1
        end
    else
        indexNum = tonumber(listIndex)
    end
    if (indexNum) then -- if index is a number
        if (indexNum < 1) then indexNum = 1 end -- lower bounds check, cannot be less than 1
        if (indexNum > #WWR.chosenStyleList+1) then indexNum = #WWR.chosenStyleList+1 end -- upper bounds check, cannot create gaps in list

        local styleNum = tonumber(styleId)
        if (styleNum) then -- if collectible ID is a number
            local isValidStyle = false
            for i = 1, #WWR.discoveredStyleList do -- test to see if this style is in the discovered list
                if (styleNum == WWR.discoveredStyleList[i]) then
                    if (IsCollectibleUnlocked(styleNum)) then isValidStyle = true end -- we only want to add unlocked styles to the chosen list
                end
            end
            if (isValidStyle) then -- if this style is valid, then add it to the list at the specified index
                WWR.chosenStyleList[indexNum] = styleNum
                WWR.savedVars.chosenStyleList[indexNum] = styleNum -- save add/replace element change
                if (printOutput) then d('[WWR] Set the style "' .. GetCollectibleName(styleNum) .. '" in index position ' .. tostring(indexNum)) end
            else
                if (printOutput) then d("[WWR] Error: Locked or Invalid Style!") end
            end
        else
            if (printOutput) then d("[WWR] Invalid style value entered for /wwr setlist!") end
        end
    else
        if (printOutput) then d("[WWR] Invalid index value entered for /wwr setlist!") end
    end
end


function WerewolfRaveSlashCommand(parameter) -- Handles the slash commands for adjusting addon settings without the GUI.
    parameter = string.lower(parameter)
    local parameterList = {}
    local parameterNum = 0
    --split parameter string into list
    for w in parameter:gmatch("%S+") do
        table.insert(parameterList, w)
    end
    --[[
        /wwr menu
        /wwr auto
        /wwr tf
        /wwr combat
        /wwr random
        /wwr newindex
        /wwr setlist <#> <#>
        /wwr getlist
        /wwr resetlist
        /wwr idtable
        /wwr frequency <#>
        /wwr frequencycombat <#>
    ]]

    if (parameterList[1] == nil or parameterList[1] == "" or parameterList[1] == "help") then
        d("=== Werewolf Rave (WWR) Commands ===")
        if (LibAddonMenu2) then d("/wwrui -> Opens the LibAddonMenu-2.0 panel for modifying these settings.") end
        d("/wwr auto -> Toggles whether Werewolf Rave automatically changes your style while transformed. Currently " .. tostring(WWR.allowChangeWhenAuto))
        d("/wwr tf -> Toggles whether Werewolf Rave changes your style each time you revert form. Currently " .. tostring(WWR.allowChangeWhenTF))
        d("/wwr combat -> Toggles WWR to be used while in combat. Currently " .. tostring(WWR.enabledInCombat))
        d("/wwr random -> Toggles WWR to randomize the style order. Currently " .. tostring(WWR.randomized))
        d("/wwr newindex -> Toggles WWR to always pick a new index in the randomized mode. Currently " .. tostring(WWR.randomizedPickNew))
        d('/wwr setlist <index> <collectibleID> -> Manually edit the style sequence. Index can be [1, listSize+1] or "new" for new. CollectibleID corresponds to the ID of the style for that sequence position. Use "new nil" to remove the last element.')
        d("/wwr getlist -> Print the style sequence. Edit this list with /wwr setlist!")
        d("/wwr resetlist -> Resets the style sequence to the default setting.")
        d("/wwr idtable -> Print the list of unique Werewolf Form styles, their IDs, and whether you've unlocked them. Reference this when using /wwr setlist!")
        d("/wwr frequency <seconds> -> Sets the number of seconds between automatic style changes. Currently " .. tostring(WWR.frequency))
        d("/wwr cfrequency <seconds> -> Sets the number of seconds between automatic style changes while in combat. Currently " .. tostring(WWR.frequencyInCombat))  
    elseif (parameterList[1] == "auto") then -- /wwr toggle
        WWR.ToggleAuto(true)
    elseif (parameterList[1] == "tf") then -- /wwr tf
        WWR.ToggleTF(true)
    elseif (parameterList[1] == "combat") then -- /wwr combat
        WWR.ToggleCombat(true)
    elseif (parameterList[1] == "random") then -- /wwr random
        WWR.ToggleRandomOrSequential(true)
    elseif (parameterList[1] == "frequency") then -- /wwr frequency <seconds>
        WWR.SetFrequency(true, parameterList[2])
    elseif (parameterList[1] == "cfrequency") then -- /wwr cfrequency <seconds>
        WWR.SetCombatFrequency(true, parameterList[2])
    elseif (parameterList[1] == "newindex") then -- /wwr newindex
        WWR.ToggleForceNewIndex(true)
    elseif (parameterList[1] == "setlist") then -- /wwr setlist <index> <collectibleId>
        WWR.SetList(true, parameterList[2], parameterList[3])
    elseif (parameterList[1] == "getlist") then -- /wwr getlist
        d("=== Werewolf Rave Sequence List ===")
        for i = 1, #WWR.chosenStyleList do
            -- print each line
            d('[' .. i .. '] = "' .. GetCollectibleName(WWR.chosenStyleList[i]) .. '", ID: ' .. WWR.chosenStyleList[i])
        end
    elseif (parameterList[1] == "idtable") then -- /wwr idtable
        d("=== Werewolf Transformation Skill Style Reference Table ===")
        for i = 1, #WWR.discoveredStyleList do
            local currentStyle = WWR.discoveredStyleList[i]
            d('"' .. GetCollectibleName(currentStyle) .. '", ID: ' .. tostring(currentStyle) .. ', Collected: ' .. tostring(IsCollectibleUnlocked(currentStyle)))
        end
    elseif (parameterList[1] == "resetlist") then -- /wwr resetlist
        WWR.ResetChosenList()
        d("[WWR] Reset the style list!")
    else
        d('[WWR] Invalid /wwr command. Type "/wwr help" for help.')
    end
end

function WWR.EquipNextStyle() -- Changes the equipped Skill Style according to the sequence type. Used by ChangeStyleWhenAuto() and ChangeStyleWhenTransforming()
    -- if the chosenStyleList only has one element, return
    if (#WWR.chosenStyleList <= 1) then return end
    
    -- determine the selection order
    if (WWR.randomized == true) then
        -- === RANDOMIZED ===

        -- if we can pick from N elements
        if (WWR.randomizedPickNew == false) then
            local nextIndex = math.random(1, #WWR.chosenStyleList)
            if (IsCollectibleUsable(WWR.chosenStyleList[nextIndex]) == false) then return end -- return if this collectible cannot be used
            
            -- if the next style in the sequence is the current style, do not set the style
            if (WWR.currentStyleId ~= WWR.chosenStyleList[nextIndex]) then
                UseCollectible(WWR.chosenStyleList[nextIndex]) -- equip the style
            end

            WWR.currentStyleId = WWR.chosenStyleList[nextIndex]
            WWR.currentStyleIndex = nextIndex
        else -- if we can pick from N-1 elements, excluding the current style

            -- set the style to the last, unreachable element if we get the element we're currently using
            --[[    Presume we have a chosenStyleList with indices {1, 2, 3}. We can only roll 1 or 2.
                    If currentStyleIndex is 1 and we roll 1, change the roll to 3
                    If currentStyleIndex is 1 and we roll 2, do nothing
                    If currentStyleIndex is 3, we can roll 1 or 2 with no conflict.
                    This gives us an equal probability for all styles but the currently equipped style. ]]
            local nextIndex = math.random(1, #WWR.chosenStyleList - 1)
            if (nextIndex == WWR.currentStyleIndex) then
                nextIndex = #WWR.chosenStyleList
            end
            if (IsCollectibleUsable(WWR.chosenStyleList[nextIndex]) == false) then return end -- return if this collectible cannot be used

            -- if the next style in the sequence is the current style, do not set the style
            if (WWR.currentStyleId ~= WWR.chosenStyleList[nextIndex]) then
                UseCollectible(WWR.chosenStyleList[nextIndex]) -- equip the style
            end

            WWR.currentStyleId = WWR.chosenStyleList[nextIndex]
            WWR.currentStyleIndex = nextIndex
        end
    else
        -- === SEQUENCED ===

        --[[    Presume we have a chosenStyleList with indices {1, 2, 3}. #chosenStyleList == 3
                nextIndex = (currentStyleIndex % #chosenStyleList) + 1
                If currentStyleIndex is 1, nextIndex will be 2
                If currentStyleIndex is 2, nextIndex will be 3
                If currentStyleIndex is 3, nextIndex will be 1
                ]]
        local nextIndex = (WWR.currentStyleIndex % #WWR.chosenStyleList) + 1
        if (IsCollectibleUsable(WWR.chosenStyleList[nextIndex]) == false) then return end -- return if this collectible cannot be used

        -- if the next style in the sequence is the current style, do not set the style
        if (WWR.currentStyleId ~= WWR.chosenStyleList[nextIndex]) then
            UseCollectible(WWR.chosenStyleList[nextIndex]) -- equip the style
        end

        WWR.currentStyleId = WWR.chosenStyleList[nextIndex]
        WWR.currentStyleIndex = nextIndex
    end
end

function WWR.ChangeStyleWhenAuto() -- Changes the active Werewolf Form Skill Style based on the shuffle type and the chosenStyleList.

    -- if player is not in Werewolf form, return
    if (IsPlayerInWerewolfForm() == false) then return end

    -- if continuous style change is not enabled, return
    if (WWR.allowChangeWhenAuto == false) then return end

    -- if there are no styles in the selected list, return
    if (#WWR.chosenStyleList <= 0) then return end

    -- if in combat and that is not allowed, return
    if (IsUnitInCombat("player") and WWR.enabledInCombat == false) then return end

    -- if dead, return (this works when resurrecting though!)
    if (IsUnitDead("player")) then return end

    -- update the frequency, which selects the correct frequency depending on combat state
    WWR.UpdateFrequency()

    WWR.EquipNextStyle() -- equip a style
end

function WWR.ChangeStyleWhenTransforming()
    -- if style change on revert form is not enabled, return
    if (WWR.allowChangeWhenTF == false) then return end

    -- if there are no styles selected, return
    if (#WWR.chosenStyleList <= 0) then return end

    -- if in combat and that is not allowed, return
    if (IsUnitInCombat("player") and WWR.enabledInCombat == false) then return end

    -- if dead, return (this works when resurrecting though!)
    if (IsUnitDead("player")) then return end

    if (IsPlayerInWerewolfForm() == false) then --[[We can only change the fur color during the revert form animation, since the transform animation conflicts with the style equip.
                                                    For some reason, the EVENT_WEREWOLF_STATE_CHANGED event fires TWICE when transforming (once when the ultimate is cast, once when the animation finishes)
                                                    and *neither* of those times allow a Skill Style to be equipped due to the channel time of transforming blocking UseCollectible()
                                                    This event only fires once when reverting form and allows UseCollectible() to run, so I opt for that instead.

                                                    The player is considered to be in the opposite form the moment they activate the transformation,
                                                    e.g. when reverting form, the player is considered to be in human form before the de-transformation animation finishes
                                                    This is why we're checking for the player to NOT be in Werewolf form for the revert form animation! ]]
        WWR.EquipNextStyle() -- equip a style
    end
end

function WWR.LoadSettings() -- set the default values and read from the saved variables table
    local defaultVars = {
        chosenStyleList = {},
        allowChangeWhenAuto = true,
        enabledInCombat = false,
        frequency = 3,
        frequencyInCombat = 10,
        randomizedPickNew = true,
        randomized = true,
        allowChangeWhenTF = false
    }
    WWR.savedVars = ZO_SavedVars:NewAccountWide("WerewolfRaveVars", WWR.VAR_VERSION, GetWorldName(), defaultVars, nil, nil)

    -- if the saved list size is 0, reset the list to create the default list
    if (#WWR.savedVars.chosenStyleList <= 0) then
        WWR.chosenStyleList = WWR.CreateAndSaveDefaultList() -- this should be the default list for first-time users, but that must be generated first
    end
    -- load the saved list
    for i = 1, #WWR.savedVars.chosenStyleList do
        WWR.chosenStyleList[i] = WWR.savedVars.chosenStyleList[i]
    end
    WWR.allowChangeWhenAuto = WWR.savedVars.allowChangeWhenAuto
    WWR.enabledInCombat = WWR.savedVars.enabledInCombat
    WWR.frequency = WWR.savedVars.frequency
    WWR.frequencyInCombat = WWR.savedVars.frequencyInCombat
    WWR.randomizedPickNew = WWR.savedVars.randomizedPickNew
    WWR.randomized = WWR.savedVars.randomized
    WWR.allowChangeWhenTF = WWR.savedVars.allowChangeWhenTF
end

function WWR.OnAddOnLoaded(event, name) -- Initializes the addon by building the style list and updating the frequency to start the refresh
    if (name ~= WWR.NAME) then return end
    EVENT_MANAGER:UnregisterForEvent(WWR.NAME, EVENT_ADD_ON_LOADED)
    WWR.BuildStyleList() -- build the discovered list, aka id table of all possible styles
    WWR.LoadSettings() -- load the settings after building the discovered list
    WWR.UpdateFrequency()

    WWR.InitializeMenu()
    SLASH_COMMANDS["/wwr"] = WerewolfRaveSlashCommand
    EVENT_MANAGER:RegisterForEvent(WWR.NAME, EVENT_WEREWOLF_STATE_CHANGED, WWR.ChangeStyleWhenTransforming)
end

EVENT_MANAGER:RegisterForEvent(WWR.NAME, EVENT_ADD_ON_LOADED, WWR.OnAddOnLoaded)