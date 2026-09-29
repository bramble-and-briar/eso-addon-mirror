ResearchPanel = ResearchPanel or {}
ResearchPanel.totalHeight = 0
ResearchPanel.totalWidth = 125

ResearchPanel.craftingIcons = {
	[CRAFTING_TYPE_BLACKSMITHING] = "esoui/art/icons/mapkey/mapkey_smithy.dds",
	[CRAFTING_TYPE_CLOTHIER] = "esoui/art/icons/mapkey/mapkey_clothier.dds",
	[CRAFTING_TYPE_JEWELRYCRAFTING] = "esoui/art/icons/mapkey/mapkey_jewelrycrafting.dds",
	[CRAFTING_TYPE_WOODWORKING] = "esoui/art/icons/mapkey/mapkey_woodworker.dds",
}

--- Gather data regarding crafting skill line research for the current character
--- @param craftingSkillType = enum CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING
--- @return totalTraits, totalTraitsKnown, beingResearched
function ResearchPanel:GetNumItemsBeingResearched(craftingSkillType)
    local beingResearched = 0
    local totalTraits = 0
    local totalTraitsKnown = 0
    local numLines = GetNumSmithingResearchLines(craftingSkillType)
    for lineIndex = 1, numLines do
        local _, _, numTraits = GetSmithingResearchLineInfo(craftingSkillType, lineIndex)
        totalTraits = totalTraits + numTraits
        for traitIndex = 1, numTraits do
            local _, _, known = GetSmithingResearchLineTraitInfo(craftingSkillType, lineIndex, traitIndex)
            local duration, timeRemaining = GetSmithingResearchLineTraitTimes(craftingSkillType, lineIndex, traitIndex)
            if known then totalTraitsKnown = totalTraitsKnown + 1 end
            if duration and timeRemaining and timeRemaining > 0 then beingResearched = beingResearched + 1 end
        end
    end
    return totalTraits, totalTraitsKnown, beingResearched
end

local function getIconSize()
  return 24
end

function ResearchPanel:craftingString(craftingType, beingResearched, maxSimultaneous, highlight)
  local color = "|ccccccc"
  if ResearchPanel.savedVars.highlightUnusedSlots and highlight then
    color = "|cff0000"
  end
  local result = string.format("|t%d:%d:%s:inheritColor|t%s %d/%d", getIconSize(), getIconSize(), ResearchPanel.craftingIcons[craftingType], color, beingResearched, maxSimultaneous)
  return result
end

function ResearchPanel:craftingPercentage(totalTraits, totalTraitsKnown)
  local percentage = totalTraitsKnown / totalTraits * 100
  local result = string.format("- %d%%", percentage)
  return result
end

function ResearchPanel:updatePosition()
  ResearchPanelContainer:ClearAnchors()
	ResearchPanelContainer:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, ResearchPanel.savedVars.offsetX, ResearchPanel.savedVars.offsetY)
	
  ResearchPanelContainer:SetDimensions(ResearchPanel.totalWidth, ResearchPanel.totalHeight)

  ResearchPanelContainerBackdrop:SetBlendMode(TEX_BLEND_MODE_ALPHA)
  if ResearchPanel.savedVars.theme == RESEARCHPANEL_LIGHT_MODE then
    ResearchPanelContainerBackdrop:SetCenterColor(0.8, 0.8, 0.8, ResearchPanel.savedVars.transparency)
  elseif ResearchPanel.savedVars.theme == RESEARCHPANEL_GRAY_MODE then
    ResearchPanelContainerBackdrop:SetCenterColor(0.4, 0.4, 0.4, ResearchPanel.savedVars.transparency)
  elseif ResearchPanel.savedVars.theme == RESEARCHPANEL_DARK_MODE then
    ResearchPanelContainerBackdrop:SetCenterColor(0, 0, 0, ResearchPanel.savedVars.transparency)
  end
end

function ResearchPanel:update()
  if ResearchPanel.charVars.enabled == false then 
    ResearchPanelContainer:SetHidden(true)
    return 
  else
    ResearchPanelContainer:SetHidden(false)
  end
  local lineSize = getIconSize() + 3
  local leftMargin = 10
  local rightMargin = 15
  local topMargin = 10
  local totalHeight = 2 * topMargin + lineSize * 4 

  -- Blacksmithing
  local totalTraits, totalTraitsKnown, beingResearched = ResearchPanel:GetNumItemsBeingResearched(CRAFTING_TYPE_BLACKSMITHING)
  local maxSimultaneous = GetMaxSimultaneousSmithingResearch(CRAFTING_TYPE_BLACKSMITHING)
  local togo = totalTraits - totalTraitsKnown
  local highlight = (beingResearched < maxSimultaneous and togo > beingResearched)
  ResearchPanelContainerBackdropBlacksmithing:SetText(ResearchPanel:craftingString(CRAFTING_TYPE_BLACKSMITHING, beingResearched, maxSimultaneous, highlight))
  ResearchPanelContainerBackdropBlacksmithing:SetAnchor(TOPLEFT, ResearchPanelContainerBackdrop, TOPLEFT, leftMargin, topMargin)
  ResearchPanelContainerBackdropBlacksmithingPercentage:SetText(ResearchPanel:craftingPercentage(totalTraits, totalTraitsKnown))
  ResearchPanelContainerBackdropBlacksmithingPercentage:SetAnchor(TOPRIGHT, ResearchPanelContainerBackdrop, TOPRIGHT, -rightMargin, topMargin)
  
  -- Clothier
  local totalTraits, totalTraitsKnown, beingResearched = ResearchPanel:GetNumItemsBeingResearched(CRAFTING_TYPE_CLOTHIER)
  local maxSimultaneous = GetMaxSimultaneousSmithingResearch(CRAFTING_TYPE_CLOTHIER)
  local togo = totalTraits - totalTraitsKnown
  local highlight = (beingResearched < maxSimultaneous and togo > beingResearched)
  ResearchPanelContainerBackdropClothier:SetText(ResearchPanel:craftingString(CRAFTING_TYPE_CLOTHIER, beingResearched, maxSimultaneous, highlight))
  ResearchPanelContainerBackdropClothier:SetAnchor(TOPLEFT, ResearchPanelContainerBackdrop, TOPLEFT, leftMargin, topMargin + lineSize)
  ResearchPanelContainerBackdropClothierPercentage:SetText(ResearchPanel:craftingPercentage(totalTraits, totalTraitsKnown))
  ResearchPanelContainerBackdropClothierPercentage:SetAnchor(TOPRIGHT, ResearchPanelContainerBackdrop, TOPRIGHT, -rightMargin, topMargin + lineSize)

  -- Jewelry Crafting
  local totalTraits, totalTraitsKnown, beingResearched = ResearchPanel:GetNumItemsBeingResearched(CRAFTING_TYPE_JEWELRYCRAFTING)
  local maxSimultaneous = GetMaxSimultaneousSmithingResearch(CRAFTING_TYPE_JEWELRYCRAFTING)
  local togo = totalTraits - totalTraitsKnown
  local highlight = (beingResearched < maxSimultaneous and togo > beingResearched)
  ResearchPanelContainerBackdropJewelrycrafting:SetText(ResearchPanel:craftingString(CRAFTING_TYPE_JEWELRYCRAFTING, beingResearched, maxSimultaneous, highlight))
  ResearchPanelContainerBackdropJewelrycrafting:SetAnchor(TOPLEFT, ResearchPanelContainerBackdrop, TOPLEFT, leftMargin, topMargin + 2 * lineSize)
  ResearchPanelContainerBackdropJewelrycraftingPercentage:SetText(ResearchPanel:craftingPercentage(totalTraits, totalTraitsKnown))
  ResearchPanelContainerBackdropJewelrycraftingPercentage:SetAnchor(TOPRIGHT, ResearchPanelContainerBackdrop, TOPRIGHT, -rightMargin, topMargin + 2 * lineSize)

  -- Woodworking
  local totalTraits, totalTraitsKnown, beingResearched = ResearchPanel:GetNumItemsBeingResearched(CRAFTING_TYPE_WOODWORKING)
  local maxSimultaneous = GetMaxSimultaneousSmithingResearch(CRAFTING_TYPE_WOODWORKING)
  local togo = totalTraits - totalTraitsKnown
  local highlight = (beingResearched < maxSimultaneous and togo > beingResearched)
  ResearchPanelContainerBackdropWoodworking:SetText(ResearchPanel:craftingString(CRAFTING_TYPE_WOODWORKING,  beingResearched, maxSimultaneous, highlight))
  ResearchPanelContainerBackdropWoodworking:SetAnchor(TOPLEFT, ResearchPanelContainerBackdrop, TOPLEFT, leftMargin, topMargin + 3 * lineSize)
  ResearchPanelContainerBackdropWoodworkingPercentage:SetText(ResearchPanel:craftingPercentage(totalTraits, totalTraitsKnown))
  ResearchPanelContainerBackdropWoodworkingPercentage:SetAnchor(TOPRIGHT, ResearchPanelContainerBackdrop, TOPRIGHT, -rightMargin, topMargin + 3 * lineSize)

  ResearchPanel.totalHeight = totalHeight
  ResearchPanel:updatePosition()
end

function ResearchPanel:combatStateChanged()
  if ResearchPanel.charVars.enabled == false then 
    ResearchPanelContainer:SetHidden(true)
    return 
  end
  if IsUnitInCombat("player") then
    ResearchPanelContainer:SetHidden(true)
  else
    if ResearchPanel.charVars.enabled then
      ResearchPanelContainer:SetHidden(false)
    end
  end
end

-- Initialize the ResearchPanel addon
--- This function sets up the saved variables, registers events, and creates the settings panel.
--- It is called when the addon is loaded.
--- @return void   
function ResearchPanel:Initialize()
        -- Initialize the pocket money settings
    ResearchPanel.savedVars = ZO_SavedVars:NewAccountWide("ResearchPanelSavedVars", 1, nil, ResearchPanel.defaultSettings)
    ResearchPanel.charVars = ZO_SavedVars:NewCharacterIdSettings("ResearchPanelCharVars", 1, nil, ResearchPanel.characterDefaults)

    -- ResearchPanelContainerBackdrop:SetCenterColor(255, 255, 255, 128)

    ResearchPanel:createSettingsPanel()

    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_ResearchComplete", EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_ResearchCanceled", EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_ResearchStarted", EVENT_SMITHING_TRAIT_RESEARCH_STARTED, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_EndCraftingStation", EVENT_END_CRAFTING_STATION_INTERACT, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_EndSkillUpdate", EVENT_END_SKILL_UPDATE, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_SkillPointsChanged", EVENT_SKILL_POINTS_CHANGED, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_AbilityProgressionResult", EVENT_ABILITY_PROGRESSION_RESULT, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, ResearchPanel.combatStateChanged)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_SubZoneChanged", EVENT_CURRENT_SUBZONE_LIST_CHANGE, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_ZoneChanged", EVENT_ZONE_CHANGED, ResearchPanel.update)
    EVENT_MANAGER:RegisterForEvent(ResearchPanel.name .. "_FastTravelEnd", EVENT_END_FAST_TRAVEL_INTERACTION, ResearchPanel.update)

    local rootMenu = SCENE_MANAGER:GetScene("hud")
    if rootMenu then 
      rootMenu:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
          ResearchPanelContainer:SetHidden(false)
          ResearchPanel:update()
        elseif newState == SCENE_HIDDEN then
          ResearchPanelContainer:SetHidden(true)
        end
      end)
    end

    zo_callLater(function() ResearchPanel:update() end, 1000)

    -- ResearchPanelContainer:SetAnchor(LEFT, GuiRoot, BOTTOMLEFT, ResearchPanel.savedVars.offsetX, ResearchPanel.savedVars.offsetY)

end

--- Event handler for the add-on loaded event
--- This function initializes the ResearchPanel addon when it is loaded.
--- It checks if the add-on name matches "ResearchPanel" and then calls the Initialize function.
--- It unregisters the event after initialization to prevent it from being called again.
EVENT_MANAGER:RegisterForEvent("ResearchPanel_Loaded", EVENT_ADD_ON_LOADED, function(event, addonName)
    if addonName == "ResearchPanel" then
        ResearchPanel:Initialize()
        EVENT_MANAGER:UnregisterForEvent("ResearchPanel_Loaded", EVENT_ADD_ON_LOADED)
    end
end)