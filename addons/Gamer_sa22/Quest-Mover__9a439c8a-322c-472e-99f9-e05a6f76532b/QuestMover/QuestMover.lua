QuestMover = {}
local QuestMover = QuestMover
QuestMover.name = "QuestMover"
QuestMover.VisualName = "Quest Mover"
QuestMover.version = 1
QuestMover.defaultCharacter = 
{	
	["offsetY"] = 325,
	["offsetX"] = 0,
	["scale"] = 1,
	["useCharacterSettings"] = false,
}
QuestMover.default = {
	["accountWideProfile"] = QuestMover.defaultCharacter,
}

function QuestMover.GetSettings()--
	if QuestMover.charSavedVars.useCharacterSettings then
		return QuestMover.charSavedVars
	else
		return QuestMover.savedvars.accountWideProfile
	end
end

function QuestMover.ApplyAnchor()
	ZO_HUDTrackers:ClearAnchors()	
	ZO_HUDTrackers:SetAnchor(9, GuiRoot, 0, QuestMover.GetSettings().offsetX, QuestMover.GetSettings().offsetY)	
end	
local ZoneStoryQuest =false
function QuestMover.enableInheritScaleRecursive(control)
    if not control then return end
    if not control:GetInheritsScale() then control:SetInheritScale(true) end
    local numChildren = control:GetNumChildren()
    for i = 1, numChildren do
        local child = control:GetChild(i)
        if child then
            QuestMover.enableInheritScaleRecursive(child)
        end
    end
end

---Applies scale transform to Quest Tracker (ty DakJaniels)
function QuestMover.applyScale(controlToScale, scale)
    if not controlToScale then return end
    local appliedScale = scale or 1
    QuestMover.enableInheritScaleRecursive(controlToScale);
    controlToScale:SetTransformScale(appliedScale);
end
function QuestMover.applyScales()
	--QuestMover.applyScale(ZO_FocusedQuestTrackerPanelContainer,QuestMover.GetSettings().scale)
	--QuestMover.applyScale(ZO_ZoneStoryTrackerContainer,QuestMover.GetSettings().scale)
	--QuestMover.applyScale(ZO_PromotionalEventTracker_TL,QuestMover.GetSettings().scale)
	QuestMover.applyScale(ZO_HUDTrackers,QuestMover.GetSettings().scale)
end
local QuestTrackerInMenu = false
function QuestMover.Initialize()
	--Load up, those Saved Vars
	local serverName = GetWorldName()
	QuestMover.savedvars = ZO_SavedVars:NewAccountWide("QuestMoverSavedVariables", QuestMover.version, serverName, QuestMover.default)
	QuestMover.charSavedVars = ZO_SavedVars:NewCharacterIdSettings("QuestMoverSavedVariables",QuestMover.version, serverName, QuestMover.savedvars.accountWideProfile) 	
	QuestMover.applyScales()
	QuestMover.ApplyAnchor()
	--used showing it in settings
	ZO_FocusedQuestTrackerPanelContainer:SetHandler("OnShow",function() ZoneStoryQuest=false end)
	ZO_ZoneStoryTrackerContainer:SetHandler("OnShow",function()ZoneStoryQuest=true end)
    
	local LHAS = LibHarvensAddonSettings
    local options = {
        allowDefaults = true,
		allowRefresh = false,
		defaultsFunction = function()      
		d("QuestMover Reset")
        end,
    }
    
    local settings = LHAS:AddAddon(QuestMover.VisualName, options)
    if not settings then
        return
    end
	--On/Off for Character Settings
    local checkbox = {
        type = LHAS.ST_CHECKBOX,
        label = "Use character settings", 
		--default = false, 
        setFunction = function(value)
           QuestMover.charSavedVars.useCharacterSettings = value
        end,
        getFunction = function()
            return QuestMover.charSavedVars.useCharacterSettings
        end,
    }
    settings:AddSetting(checkbox)
	local scene
	local function addQT()
		if QuestTrackerInMenu then return end
		scene = SCENE_MANAGER:GetCurrentScene()					
		if ZoneStoryQuest then
			scene:AddFragment(ZONE_STORY_TRACKER_FRAGMENT)
			ZONE_STORY_TRACKER_FRAGMENT:Refresh()
			ZO_ZoneStoryTrackerContainer:SetHidden(false)
		else
			scene:AddFragment(FOCUSED_QUEST_TRACKER_FRAGMENT)
			FOCUSED_QUEST_TRACKER_FRAGMENT:Refresh()
			ZO_FocusedQuestTrackerPanelContainer:SetHidden(false)
		end
		QuestTrackerInMenu = true	
	end
	
	local function addonSelected(_, addonSettings)
		if QuestTrackerInMenu then	
			scene:RemoveFragment(ZONE_STORY_TRACKER_FRAGMENT)
			ZONE_STORY_TRACKER_FRAGMENT:Refresh()
			scene:RemoveFragment(FOCUSED_QUEST_TRACKER_FRAGMENT)
			FOCUSED_QUEST_TRACKER_FRAGMENT:Refresh()
			QuestTrackerInMenu = false
		end
	end
		
	CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", addonSelected)

	settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Show Quest Tracker",		
        buttonText = "Show",
        clickHandler = function(control, button)
			if not QuestTrackerInMenu then
				addQT()
			else
				addonSelected()
			end
        end,
    })	
	local maxX, maxY = GuiRoot:GetDimensions()
	maxX = math.floor(maxX)
	maxY = math.floor(maxY)
	--Slider to Adjust Quest Traker's X Position
	 settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Left <- -> Right",
		tooltip = "Default is 0",
        setFunction = function(value)
            QuestMover.GetSettings().offsetX = value
			QuestMover.ApplyAnchor()
        end,
        getFunction = function()
            return QuestMover.GetSettings().offsetX
        end,
        default = QuestMover.defaultCharacter.offsetX,
        min = -maxX,
        max = 100,
        step = 5
    })
	--Slider to Adjust Quest Traker's Y Position
    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Up <- -> Down",
		tooltip = "Default: 325 \nBase Game: 100",
        setFunction = function(value)
            QuestMover.GetSettings().offsetY = value
			QuestMover.ApplyAnchor()
        end,
        getFunction = function()
            return QuestMover.GetSettings().offsetY
        end,
        default = QuestMover.defaultCharacter.offsetY,
        min = -50,
        max = maxY,
        step = 5
    })
	--Slider to Adjust Quest Traker's Scale
    settings:AddSetting({
        type = LHAS.ST_SLIDER,
        label = "Small <- -> Large",
		tooltip = "Default: 1",
        setFunction = function(value)
            QuestMover.GetSettings().scale = value
			QuestMover.applyScales()
        end,
        getFunction = function()
            return QuestMover.GetSettings().scale
        end,
        default = QuestMover.defaultCharacter.scale,
        min = 0.5,
        max = 1.5,
        step = 0.05
    })
	settings:AddSetting({
        type = LHAS.ST_BUTTON,
        label = "Submit Feedback / Request",
		tooltip = "link to a form where you can leave feedback or even leave a request",
		buttonText = "Open URL",
		clickHandler = function(control, button)
			RequestOpenUnsafeURL("https://docs.google.com/forms/d/e/1FAIpQLScYWtcIJmjn0ZUrjsvpB5rwA5AlsLvasHUIcKqzIYcogo9vjQ/viewform?usp=pp_url&entry.550722213="..QuestMover.VisualName)
		end,
	})
end
function QuestMover.OnAddOnLoaded(event, addonName)
	if addonName == QuestMover.name then
		QuestMover.Initialize()		
		EVENT_MANAGER:UnregisterForEvent(QuestMover.name, EVENT_ADD_ON_LOADED)
	end
end
 
EVENT_MANAGER:RegisterForEvent(QuestMover.name, EVENT_ADD_ON_LOADED, QuestMover.OnAddOnLoaded)

--HUGE thanks to Dolgubon for helping me working out on how to do this