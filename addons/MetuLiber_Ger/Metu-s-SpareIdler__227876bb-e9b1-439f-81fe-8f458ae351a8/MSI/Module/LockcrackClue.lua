-- LockcrackClue.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

MSI.IsLockcrackActive = false

MSI.zosVars = {}
MSI.ChamberResolvedIconTooltips = {}
MSI.OnLockcrackChatStateWasMinimized = false

MSI.ChamberResolvedIcon = {
	[[EsoUI/Art/WorldMap/selectedquesthighlight.dds]],
}

MSI.zosVars.LOCKPICKS_LEFT  = ZO_LockcrackPanelInfoBarLockcracksLeft
MSI.zosVars.LOCKPICK = LOCK_PICK
MSI.zosVars.LOCKPICK_GP_SCENE = LOCK_PICK_GAMEPAD_SCENE

local zosVars = MSI.zosVars
local lockPicksLeftCtrl = zosVars.LOCKPICKS_LEFT
local lockPick = zosVars.LOCKPICK
local lockPickSprings = lockPick.springs
local numVars = MSI.numVars

local origChamberStressedSound = MSI.OrigChamberStressedSound
local chamberResolvedIcon = MSI.ChamberResolvedIcon

local showChamberResolvedIcon
local chamberResolvedSpringColor

local chamberResolvedUniqueName = MSI.Name.."LockcrackClueChamberResolvedCheck"
local LockcrackClue_chamberResolvedIcon
local chamberPinNotResolvedColor = ZO_ColorDef:New(1, 1, 1, 1)

local function texturePathToId(texturePath)
	if texturePath == nil then return end
	return ZO_IndexOfElementInNumericallyIndexedTable(chamberResolvedIcon, texturePath)
end

local function idToTexturePath(textureId)
	return chamberResolvedIcon[textureId]
end

local function checkAndRememberChatMinimizedState(gamePadMode, doNotMinimize)
	if gamePadMode == nil then gamePadMode = IsInGamepadPreferredMode() end
	doNotMinimize = doNotMinimize or false
	local chatSystem = ZO_GetChatSystem()
	if chatSystem == nil then
		return
	end
	local isChatMinimized = chatSystem:IsMinimized()
	MSI.OnLockcrackChatStateWasMinimized = isChatMinimized
	if not doNotMinimize and not gamePadMode and not isChatMinimized then chatSystem:Minimize() end
end

local function chatStateRestore(gamePadMode)
	if gamePadMode == nil then gamePadMode = IsInGamepadPreferredMode() end
	local chatSystem = ZO_GetChatSystem()
	if chatSystem == nil then
		return
	end

	local isChatMinimized = chatSystem:IsMinimized()
	if MSI.OnLockcrackChatStateWasMinimized == true then
		if not isChatMinimized then
			chatSystem:Minimize()
		end
	else
		if isChatMinimized then
			chatSystem:Maximize()
		end
    end
end

local function LockcrackClue_GetLockcrackInfoTextColor()
	local lockpicksLeft = GetNumLockpicksLeft()
	local newColor
    if lockpicksLeft <= 5 then
		newColor = {r = 1,g = 0,b = 0,a = 1,}
    elseif lockpicksLeft <= 10 then
		newColor = {r = 0,g = 1,b = 1,a = 1,}
    else
		newColor = {r = 0,g = 1,b = 0,a = 1,}
    end
    return newColor
end

local function LockcrackClue_UpdateLockcracksLeftText(lockpickTextCtrl)
    if not lockpickTextCtrl then
	    return
	else
		MSI.Print("c", MSI.Colorize(zo_strformat(GetString(MSI_MOD_UNBOLT_LOCKPICKS_LEFT)), MSI.Colorize(GetNumLockpicksLeft(), "FFFFFF")))
    end

	local newTextColor = LockcrackClue_GetLockcrackInfoTextColor()
    lockpickTextCtrl:SetColor(newTextColor.r, newTextColor.g, newTextColor.b, newTextColor.a)

	--fix for PerfectPixel
	if PP ~= nil and lockpickTextCtrl ~= nil then
		local parentCtrl = ZO_LockpickPanel
		if parentCtrl ~= nil then
			lockpickTextCtrl:ClearAnchors()
			lockpickTextCtrl:SetAnchor(TOP, parentCtrl, TOP, 0, 75)
			lockpickTextCtrl:SetHidden(false)
		end
	end
end

local function LockcrackClue_UpdateLockcrackChamberResolvedIcon()
	local chamberResolvedTexture = MSI.LockcrackClue_ChamberResolvedIconTexture
	if not chamberResolvedTexture then return end

	chamberResolvedTexture:SetAnchorFill()
	chamberResolvedTexture:SetTexture(MSI.IdToTexturePath(MSI.SVars.ChamberResolvedIcon))
	chamberResolvedTexture:SetColor(unpack(MSI.SVars.ChamberResolveIconColor))
	chamberResolvedTexture:SetDrawLayer(DL_OVERLAY)
	chamberResolvedTexture:SetDrawTier(DT_HIGH)
	chamberResolvedTexture:SetDrawLevel(5) --high level to overlay others
end

local function LockcrackClue_CreateChamberResolvedIcon()
	MSI.TopLevelChamberResolvedIcon = CreateTopLevelWindow(MSI.Name.."ChamberResolvedIcon", GuiRoot)
	local topLevelChamber = MSI.TopLevelChamberResolvedIcon
	topLevelChamber:SetDimensions(480, 480)
	topLevelChamber:SetHidden(true)
	topLevelChamber:SetAnchor(CENTER, GuiRoot, CENTER)
	topLevelChamber:SetDrawLayer(DL_OVERLAY)
	topLevelChamber:SetDrawTier(DT_HIGH)
	topLevelChamber:SetDrawLevel(5)--high level to overlay others

	MSI.LockcrackClue_ChamberResolvedIconTexture = CreateControl(MSI.Name.."ChamberResolvedIconTexture", topLevelChamber, CT_TEXTURE)

	MSI.LockcrackClue_chamberResolvedIcon = MSI.TopLevelChamberResolvedIcon
	LockcrackClue_chamberResolvedIcon = MSI.TopLevelChamberResolvedIcon

	LockcrackClue_UpdateLockcrackChamberResolvedIcon()
end

local function LockcrackClue_CheckChamberResolved()
	showChamberResolvedIcon = MSI.SVars.ShowChamberResolvedIcon
	local useColors = MSI.SVars.UseSpringResolveColor
	if not showChamberResolvedIcon and not useColors then return false end

	local chamberIndex = lockPick.settingChamberIndex
	local chamberStress = GetSettingChamberStress()
	local chamberSolved = IsChamberSolved(chamberIndex)

	local currentSpring = lockPickSprings[chamberIndex]
	if not currentSpring then return end
	local chamberWasResolved = (chamberStress > 0 and not chamberSolved) or false

	if showChamberResolvedIcon == true then
		LockcrackClue_chamberResolvedIcon:SetHidden(not chamberWasResolved)
	end

	if useColors == true then
		local currentSpringPin = currentSpring.pin
		if not currentSpringPin then return end
		local chamberPinColor = (chamberWasResolved == true and chamberResolvedSpringColor) or chamberPinNotResolvedColor
		currentSpringPin:SetColor(chamberPinColor:UnpackRGBA())
	end
end

local function LockcrackClue_Chamber_OnMouseDown()
	showChamberResolvedIcon = MSI.SVars.ShowChamberResolvedIcon
	if not showChamberResolvedIcon and not MSI.SVars.UseSpringResolveColor then return end
	if showChamberResolvedIcon and not LockcrackClue_chamberResolvedIcon then
    	LockcrackClue_CreateChamberResolvedIcon()
    end
	EVENT_MANAGER:RegisterForUpdate(chamberResolvedUniqueName, 15, LockcrackClue_CheckChamberResolved)
	return false
end

local function LockcrackClue_Chamber_OnMouseUp()
	EVENT_MANAGER:UnregisterForUpdate(chamberResolvedUniqueName)
	if showChamberResolvedIcon and LockcrackClue_chamberResolvedIcon then
		LockcrackClue_chamberResolvedIcon:SetHidden(true)
    end
	return false
end

local function LockcrackClue_OnEndLockcrack(...)
	EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_LockPick_Failed", EVENT_LOCKPICK_FAILED)
	EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_LockPick_Success", EVENT_LOCKPICK_SUCCESS)
	EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_LockPick_Broke", EVENT_LOCKPICK_BROKE)

    MSI.IsLockcrackActive = false
    --MSI.Print("d", "Lockcracking ended")

	showChamberResolvedIcon = MSI.SVars.ShowChamberResolvedIcon
	if LockcrackClue_chamberResolvedIcon ~= nil then
		LockcrackClue_chamberResolvedIcon:SetHidden(true)
		LockcrackClue_chamberResolvedIcon:SetDimensions(0, 0)
    end

	if MSI.SVars.UseSpringResolveColor == true then
        for i = 1, NUM_LOCKPICK_CHAMBERS, 1 do
			local lockPickSpringPin = lockPickSprings[i] and lockPickSprings[i].pin
            if lockPickSpringPin ~= nil then
                lockPickSpringPin:SetColor(chamberPinNotResolvedColor.r, chamberPinNotResolvedColor.g, chamberPinNotResolvedColor.b, chamberPinNotResolvedColor.a)
            end
        end
    end
	chatStateRestore(nil)
end

local function LockcrackClue_OnLockpickBroke(...)
    MSI.IsLockcrackActive = true
    MSI.Print("c", GetString(MSI_MOD_UNBOLT_LOCKPICK_BROKE))

	LockcrackClue_UpdateLockcracksLeftText(lockPicksLeftCtrl)
end

local function LockcrackClue_OnBeginLockcrack(...)
if not MSI.SVars.IsLockcrackClue then return end
	if showChamberResolvedIcon then
		if not LockcrackClue_chamberResolvedIcon then
			LockcrackClue_CreateChamberResolvedIcon()
		else
			LockcrackClue_chamberResolvedIcon:SetDimensions(480, 480)
		end
	end

	local gamePadMode = IsInGamepadPreferredMode()
	if not gamePadMode then
		checkAndRememberChatMinimizedState(gamePadMode)
	end

	MSI.IsLockcrackActive = true
	--MSI.Print("d", "Lockcracking started")

	LockcrackClue_UpdateLockcracksLeftText(lockPicksLeftCtrl)

	EVENT_MANAGER:RegisterForEvent(MSI.Name.."Event_LockPick_Failed", EVENT_LOCKPICK_FAILED, LockcrackClue_OnEndLockcrack)
	EVENT_MANAGER:RegisterForEvent(MSI.Name.."Event_LockPick_Success", EVENT_LOCKPICK_SUCCESS, LockcrackClue_OnEndLockcrack)
	EVENT_MANAGER:RegisterForEvent(MSI.Name.."Event_LockPick_Broke", EVENT_LOCKPICK_BROKE, LockcrackClue_OnLockpickBroke)
end

local function OnLockcrackClueSceneStateChange(oldState, newState)
	if newState == SCENE_SHOWING then
		local gamePadMode = IsInGamepadPreferredMode()
		if not gamePadMode then return end
		checkAndRememberChatMinimizedState(gamePadMode, nil)
	end
end

local hooksPerInputModeAdded = {
	[true] 	= false, --Gamepad mode
	[false] = false, --Keyboard mode
}

local function AddHooksBasedOnInputMode(isGamepadMode)
	if isGamepadMode == nil then isGamepadMode = IsInGamepadPreferredMode() end
	if not hooksPerInputModeAdded[isGamepadMode] then
		zosVars.LOCKPICK_GP_SCENE:RegisterCallback("StateChange", OnLockcrackClueSceneStateChange)
		ZO_PreHook(lockPick, "StartDepressingPin", LockcrackClue_Chamber_OnMouseDown)
		ZO_PreHook(lockPick, "EndDepressingPin", LockcrackClue_Chamber_OnMouseUp)

		hooksPerInputModeAdded[isGamepadMode] = true
		if hooksPerInputModeAdded[true] == true and hooksPerInputModeAdded[false] == true then
			MSI.Print("d", "UnregisterForEvent Event_Input_Type_Changed beendet!!")
			EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_Input_Type_Changed", EVENT_INPUT_TYPE_CHANGED)
		end
	end
end

local function OnEventInputTypeChanged(eventId, isGamepad)
	AddHooksBasedOnInputMode(isGamepad)
end

function MSI.TexturePathToId(texturePath)
    return texturePathToId(texturePath)
end

function MSI.IdToTexturePath(textureId)
    return idToTexturePath(textureId)
end

function MSI.InitModLockcrackClue()
	local function UnRegModuleEvents()
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_Input_Type_Changed", EVENT_INPUT_TYPE_CHANGED)
		EVENT_MANAGER:UnregisterForEvent(MSI.Name.."Event_AddOn_Loaded", EVENT_BEGIN_LOCKPICK)
	end
	local function RegModuleEvents()
		UnRegModuleEvents()
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."Event_Input_Type_Changed", EVENT_INPUT_TYPE_CHANGED, OnEventInputTypeChanged)
		EVENT_MANAGER:RegisterForEvent(MSI.Name.."Event_AddOn_Loaded", EVENT_BEGIN_LOCKPICK, LockcrackClue_OnBeginLockcrack)
	end
	if MSI.SVars.IsLockcrackClue and MSI.SVars.IsMSIActive then
		chamberResolvedSpringColor = ZO_ColorDef:New(unpack(MSI.SVars.SpringResolveColor))
		AddHooksBasedOnInputMode(nil)
		MSI.IsLockcrackActive = true
		RegModuleEvents()
		--MSI.Print("d", "Modul option change!! LockcrackClue Event registered")
	elseif not MSI.SVars.IsLockcrackClue or not MSI.SVars.IsMSIActive then
		UnRegModuleEvents()
		--MSI.Print("d", "Module disabled!! LockcrackClue Event unregistered")
	else
		UnRegModuleEvents()
		--MSI.Print("d", "MSI |c8B0000not|r Active!! LockcrackClue Event unregistered")
	end
end
--eof