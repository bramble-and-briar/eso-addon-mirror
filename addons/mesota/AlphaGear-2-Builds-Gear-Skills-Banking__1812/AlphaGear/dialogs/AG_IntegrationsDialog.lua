--[[

Dialog to edit settings of integrations

--]]


-- locals
local OFMGR = ZO_OUTFIT_MANAGER


--- Writes trace messages to the console
-- fmt with %d, %s,
local function trace(fmt, ...)
	if AG.isDebug then
		d(string.format(fmt, ...))
	end
end

-- AG Integrations Dialog

AGIntDlg = {
}

AGIntDlg.currentBuildNr = -1
AGIntDlg.currentBuildData = nil
AGIntDlg.currentBuildName = 'No Build'

AGIntDlg.selection = {}
AGIntDlg.selection.useOutfit = true
AGIntDlg.selection.outfit = 0
AGIntDlg.selection.styleId = 0
AGIntDlg.selection.oldIconId = 0
AGIntDlg.selection.newIconId = 0

AGIntDlg.selection.newCPSSlotName = ''
AGIntDlg.selection.newCPSHostName = ''

------------------------------------------------------
-- Style Integration
------------------------------------------------------


function AGIntDlg.SetupOutfitCombo(dropdown)

    local currentOutfitIndex = AGIntDlg.currentBuildData.outfit
    AGIntDlg.selection.outfit = currentOutfitIndex

    dropdown:ClearItems()
    dropdown:SetSortsItems(false)

    local function OnKeepOutfitSelected()
        AGIntDlg.selection.outfit = AG.OUTFIT_KEEP
    end

    local function OnNoOutfitSelected()
        AGIntDlg.selection.outfit = AG.OUTFIT_NONE
    end

    local function OnOutfitEntrySelected(_, _, entry)
        AGIntDlg.selection.outfit = entry.outfitIndex
    end

    -- Add Keep-Outfit Item
    local keepOutfitEntry = ZO_ComboBox:CreateItemEntry(AGLang.msg.KeepOutfitItemLabel, OnKeepOutfitSelected)
    dropdown:AddItem(keepOutfitEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    -- Add No-Outfit Item
    local unequippedOutfitEntry = ZO_ComboBox:CreateItemEntry(GetString(SI_NO_OUTFIT_EQUIP_ENTRY), OnNoOutfitSelected)
    dropdown:AddItem(unequippedOutfitEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = unequippedOutfitEntry
    if currentOutfitIndex == AG.OUTFIT_KEEP  then
        defaultEntry = keepOutfitEntry
    end

    -- Add available Outfit Items
    local numOutfits = OFMGR:GetNumOutfits(GAMEPLAY_ACTOR_CATEGORY_PLAYER) 
    for outfitIndex = 1, numOutfits do
        local outfitManipulator = OFMGR:GetOutfitManipulator(GAMEPLAY_ACTOR_CATEGORY_PLAYER, outfitIndex)
        local entry = ZO_ComboBox:CreateItemEntry(outfitManipulator:GetOutfitName(), OnOutfitEntrySelected)
        entry.outfitIndex = outfitIndex
        dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if currentOutfitIndex == outfitIndex then
            defaultEntry = entry
        end
    end

    dropdown:UpdateItems()
    dropdown:SelectItem(defaultEntry)
end

function AGIntDlg.SetupAlphaStyleCombo(dropdown)

    local function OnStyleSelected(_, _, entry)
        AGIntDlg.selection.styleId = entry.styleId
    end

    -- Add available Style Items
    local AGplugAS = AG.plugins.AlphaStyle

    local currentStyleId = AGIntDlg.currentBuildData.AlphaStyleId or AGplugAS.STYLE_KEEP

    dropdown:ClearItems()
    dropdown:SetSortsItems(false)


    -- Add Keep-Style Item
    local keepStyleEntry = ZO_ComboBox:CreateItemEntry("-Keep Style-", OnStyleSelected)
    keepStyleEntry.styleId = AGplugAS.STYLE_KEEP
    dropdown:AddItem(keepStyleEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = keepStyleEntry
    
    local styles = AGplugAS.GetStyles()

    for _, style in pairs(styles) do 
        local entry = ZO_ComboBox:CreateItemEntry(style.name, OnStyleSelected)
        entry.styleId = style.id
        dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if currentStyleId == style.id then
            defaultEntry = entry
        end        
    end

    dropdown:UpdateItems()
    dropdown:SelectItem(defaultEntry)
end

function AGIntDlg.SetupStyleIntegration(control)
    local ctrlContent = GetControl(control, "Content")

    -- outfit or alphastyle
    local comboOutfit = ZO_ComboBox_ObjectFromContainer(ctrlContent:GetNamedChild("OutfitDropdown"))
    local labelStyle = GetControl(ctrlContent, "OutfitLabel")

    local AGplugAS = AG.plugins.AlphaStyle
    if AGplugAS.useAddon() then
        AGIntDlg.selection.useOutfit = false

        -- updates the AlphaStyleCombo
        labelStyle:SetText("AlphaStyle Style")
        AGIntDlg.SetupAlphaStyleCombo(comboOutfit)
    else
        AGIntDlg.selection.useOutfit = true

        -- updates the outfitCombo
        labelStyle:SetText(AGLang.msg.OutfitLabel)
        AGIntDlg.SetupOutfitCombo(comboOutfit)
    end
end

function AGIntDlg.CommitStyleIntegration()
    if AGIntDlg.selection.useOutfit then
        AGIntDlg.currentBuildData.outfit = AGIntDlg.selection.outfit
    else
        AGIntDlg.currentBuildData.AlphaStyleId = AGIntDlg.selection.styleId
    end
end

------------------------------------------------------
-- Inventory Integration
------------------------------------------------------

--> BAERTRAM - FCOIS
function AGIntDlg.SetupFCOISSetMarkerIconCombo(dropdown)

    local function OnEntrySelected(_, _, entry)
        local AGplugFCOIS = AG.plugins.FCOIS
        -- store selection
        AGIntDlg.selection.newIconId = entry.FCOISgearMarkerIcon
    end

    local AGplugFCOIS = AG.plugins.FCOIS

    -- store current/old icon id
    AGIntDlg.selection.oldIconId = AGplugFCOIS.getFCOISIconId(AGIntDlg.currentBuildData)

    -- fill combo
    dropdown:ClearItems()
    dropdown:SetSortsItems(false)

    -- Add "None" entry
    local noFCOISGearMarkerIconEntry = ZO_ComboBox:CreateItemEntry(AGLang.msg.Integrations.Inventory.FCOIS.NoGearMarkerIconEntry, OnEntrySelected)
    noFCOISGearMarkerIconEntry.FCOISgearMarkerIcon = 0
    dropdown:AddItem(noFCOISGearMarkerIconEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = noFCOISGearMarkerIconEntry

    local gearMarkerIconsList, gearMarkerIconsValuesList = AGplugFCOIS.getFCOISGearSetMarkerIconsList()
    if gearMarkerIconsList ~= nil and gearMarkerIconsValuesList ~= nil then
        -- Add available FCOIS Markers
        local currentIconId = AGplugFCOIS.getFCOISIconId(AGIntDlg.currentBuildData)

        for FCOISgearMarkerIcon = 1, #gearMarkerIconsList do
            local entry = ZO_ComboBox:CreateItemEntry(gearMarkerIconsList[FCOISgearMarkerIcon], OnEntrySelected)
            entry.FCOISgearMarkerIcon = gearMarkerIconsValuesList[FCOISgearMarkerIcon]
            dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
            if currentIconId == gearMarkerIconsValuesList[FCOISgearMarkerIcon] then
                defaultEntry = entry
            end
        end
    end
	
    dropdown:UpdateItems()
    dropdown:SelectItem(defaultEntry)
end
--< BAERTRAM - FCOIS

function AGIntDlg.SetupInventoryIntegration(control)
    local ctrlContent = GetControl(control, "Content")

    -- updates the FCOIS gear marker icons combobox, if the settings are enabled to show it
    local comboFCOISParent = ctrlContent:GetNamedChild("FCOISSetMarkerIconDropdown")
    local comboFCOIS = ZO_ComboBox_ObjectFromContainer(comboFCOISParent)
    local labelFCOIS = GetControl(ctrlContent, "FCOISLabel")

    local AGplugFCOIS = AG.plugins.FCOIS
    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        comboFCOIS:SetEnabled(true)
        comboFCOISParent:SetHidden(false)
        labelFCOIS:SetHidden(false)
        AGIntDlg.SetupFCOISSetMarkerIconCombo(comboFCOIS)
    else
        comboFCOIS:SetEnabled(false)
        comboFCOISParent:SetHidden(true)
        labelFCOIS:SetHidden(true)
    end
end


function AGIntDlg.CommitInventoryIntegration()
    -- icon has changed. update markers
    if AGIntDlg.selection.oldIconId ~= AGIntDlg.selection.newIconId then
        local AGplugFCOIS = AG.plugins.FCOIS
        AG.handleBuildIconChanged(AGIntDlg.currentBuildNr, AGIntDlg.selection.newIconId)            

        --Set the new set marker icon
        AGplugFCOIS.setFCOISIconId(AGIntDlg.currentBuildData, AGIntDlg.selection.newIconId)
    end
end

------------------------------------------------------
-- Champion Point Integration
------------------------------------------------------

function AGIntDlg.SetupCPSCombos(comboHost, comboProfile)

    local AGplugCPS = AG.plugins.CPSlots
    local cpsProfiles = AGplugCPS.GetCPSProfiles()

    local function OnProfileSelected(_, _, entry)
        AGIntDlg.selection.newCPSProfileName  = entry.name
    end


    local function OnHostSelected(_, _, entry)
        AGIntDlg.selection.newCPSHostName = entry.hostname

        local currentCPSProfileName = AGIntDlg.currentBuildData.CPSProfileName or ''
        comboProfile:ClearItems()
        comboProfile:SetSortsItems(false)

        local defaultEntry

        for _, profileName in pairs(entry.names) do 
            local cbEntry = ZO_ComboBox:CreateItemEntry(profileName, OnProfileSelected)
            comboProfile:AddItem(cbEntry, ZO_COMBOBOX_SUPRESS_UPDATE)
            if currentCPSProfileName == profileName then
                defaultEntry = cbEntry
            end        
        end

        comboProfile:UpdateItems()

        if not defaultEntry then
            comboProfile:SelectFirstItem()
        else
            comboProfile:SelectItem(defaultEntry)
        end
    end

    -- Add available CPS Hosts

    local currentCPSHostName = AGIntDlg.currentBuildData.CPSHostName or AGplugCPS.CPS_KEEP

    comboHost:ClearItems()
    comboHost:SetSortsItems(false)

    -- Add Keep-Host Item
    local keepCPS = ZO_ComboBox:CreateItemEntry("-Keep Champion Points-", OnHostSelected)
    keepCPS.hostname = AGplugCPS.CPS_KEEP
    keepCPS.names = {'-Keep-'}
    comboHost:AddItem(keepCPS, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = keepCPS
    

    for key, hostInfo in pairs(cpsProfiles) do 
        local entry = ZO_ComboBox:CreateItemEntry(hostInfo.label, OnHostSelected)
        entry.hostname = key
        entry.names = hostInfo.names
        comboHost:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if currentCPSHostName == key then
            defaultEntry = entry
        end        
    end

    comboHost:UpdateItems()
    comboHost:SelectItem(defaultEntry)
end



local function SetupCPSlotsIntegration(control)
    local ctrlContent = GetControl(control, "Content")

    -- updates the CPS host and slotname combobox, if the settings are enabled to show it
    local comboHostParent = ctrlContent:GetNamedChild("CPSHostDropdown")
    local comboHost = ZO_ComboBox_ObjectFromContainer(comboHostParent)
    local labelHost = GetControl(ctrlContent, "CPSHostLabel")

    local comboProfileParent = ctrlContent:GetNamedChild("CPSProfileDropdown")
    local comboProfile = ZO_ComboBox_ObjectFromContainer(comboProfileParent)
    local labelProfile = GetControl(ctrlContent, "CPSProfileLabel")


    local AGplugCPS = AG.plugins.CPSlots
    if AGplugCPS.useAddon() then
        comboHost:SetEnabled(true)
        comboHostParent:SetHidden(false)
        labelHost:SetHidden(false)
        comboProfile:SetEnabled(true)
        comboProfileParent:SetHidden(false)
        labelProfile:SetHidden(false)
        AGIntDlg.SetupCPSCombos(comboHost, comboProfile)
    else
        comboHost:SetEnabled(false)
        comboHostParent:SetHidden(true)
        labelHost:SetHidden(true)

        comboProfile:SetEnabled(false)
        comboProfileParent:SetHidden(true)
        labelProfile:SetHidden(true)
    end
end


local function SetUpDCPDropdown(combo, tree)
    local AGplugDCP = AG.plugins.DynamicCP
    local currentSlotSetId = AGIntDlg.currentBuildData["DCPSlotSet" .. tree] or -1

    local function OnSlottableSetSelected(_, _, entry)
        AGIntDlg.selection["newDCPSlotSet" .. tree] = entry.slotSetId
    end

    combo:ClearItems()

    local nothingEntry = ZO_ComboBox:CreateItemEntry("--", OnSlottableSetSelected)
    nothingEntry.slotSetId = -1
    combo:AddItem(nothingEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = nothingEntry

    for slotSetId, slotSet in pairs(AGplugDCP.GetDCPSlottableSet(tree)) do
        local entry = ZO_ComboBox:CreateItemEntry(slotSet.name, OnSlottableSetSelected)
        entry.slotSetId = slotSetId
        combo:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if (currentSlotSetId == slotSetId) then
            defaultEntry = entry
        end
    end
    combo:UpdateItems()
    combo:SelectItem(defaultEntry)
end


local function SetUpDynamicCPIntegration(control)
    local ctrlContent = GetControl(control, "Content")

    local AGplugDCP = AG.plugins.DynamicCP
    local enabled = AGplugDCP.useAddon()
    local TREES = {"Green", "Blue", "Red"}
    for _, tree in ipairs(TREES) do
        local comboParent = ctrlContent:GetNamedChild("DCP" .. tree .. "Dropdown")
        local combo = ZO_ComboBox_ObjectFromContainer(comboParent)
        local label = ctrlContent:GetNamedChild("DCP" .. tree .. "Label")

        combo:SetEnabled(enabled)
        comboParent:SetHidden(not enabled)
        label:SetHidden(not enabled)

        if (enabled) then
            SetUpDCPDropdown(combo, tree)
        end
    end
end

local COLORS = {
    Green = "a5d752",
    Blue = "59bae7",
    Red = "e46b2e",
}

function AGIntDlg.ShowDCPPreview(control)
    local result = "Preview:"
    local TREES = {"Green", "Blue", "Red"}
    for _, tree in ipairs(TREES) do
        local slotSetId = AGIntDlg.selection["newDCPSlotSet" .. tree]
        if (slotSetId) then
            local stars = AG.plugins.DynamicCP.GetDCPSlottableSetStars(tree, slotSetId)
            if (stars) then
                for _, skillId in ipairs(stars) do
                    result = zo_strformat("<<1>>\n|c<<2>><<C:3>>|r", result, COLORS[tree], GetChampionSkillName(skillId))
                end
            end
        end
    end
    ZO_Tooltips_ShowTextTooltip(control, RIGHT, result)
end


function AGIntDlg.SetupChampionPointIntegration(control)
    SetupCPSlotsIntegration(control)
    SetUpDynamicCPIntegration(control)
end


function AGIntDlg.CommitChampionPointIntegration()
    AGIntDlg.currentBuildData.CPSHostName = AGIntDlg.selection.newCPSHostName
    AGIntDlg.currentBuildData.CPSProfileName = AGIntDlg.selection.newCPSProfileName

    AGIntDlg.currentBuildData.DCPSlotSetGreen = AGIntDlg.selection.newDCPSlotSetGreen
    AGIntDlg.currentBuildData.DCPSlotSetBlue = AGIntDlg.selection.newDCPSlotSetBlue
    AGIntDlg.currentBuildData.DCPSlotSetRed = AGIntDlg.selection.newDCPSlotSetRed
end


------------------------------------------------------
-- Common Settings
------------------------------------------------------


function AGIntDlg.SetupCommons(control)
    local ctrlContent = GetControl(control, "Content")

    -- update Build Name
    local labelName = GetControl(ctrlContent, "BuildLabel")
    labelName:SetText(AGIntDlg.currentBuildName)
end


function AGIntDlg:Commit(control)
    trace('AGIntDlg:Commit()')

    -- commit inventory selection
    AGIntDlg.CommitInventoryIntegration()

    -- commit style selection
    AGIntDlg.CommitStyleIntegration()

    -- commit champion point selection
    AGIntDlg.CommitChampionPointIntegration()
end

function AGIntDlg:Setup(control)
    trace('AGIntDlg:Setup()')

    AGIntDlg.currentBuildNr = control.data.buildNr
    AGIntDlg.currentBuildData = AG.setdata[AGIntDlg.currentBuildNr].Set
    AGIntDlg.currentBuildName = control.data.buildName

    -- setup common data
    AGIntDlg.SetupCommons(control)

    -- setup inventory integration
    AGIntDlg.SetupInventoryIntegration(control)

    -- setup style integration
    AGIntDlg.SetupStyleIntegration(control)

    -- setup champion point integration
    AGIntDlg.SetupChampionPointIntegration(control)
end


function AGIntDlg.Initialize()
    trace('AGIntDlg:Initialize()')

    local control = AGAdvancedBuildDialog
    local data = nil

    ZO_Dialogs_RegisterCustomDialog("AG_ADVANCED_BUILD_DIALOG", {
        customControl = control,
        title = { text = "Advanced Build Options" },
		setup = function(self) AGIntDlg:Setup(control, data) end,
        buttons =
        {
            {
                control =   GetControl(control, "Accept"),
                text =      SI_DIALOG_ACCEPT,
                keybind =   "DIALOG_PRIMARY",
                callback =  function(dialog) AGIntDlg:Commit(control) end,
            },  
            {
                control =   GetControl(control, "Cancel"),
                text =      SI_DIALOG_CANCEL,
                keybind =   "DIALOG_NEGATIVE",
                callback =  function(dialog) end,
            },
        },
    })
end

AGIntDlg.Initialize()