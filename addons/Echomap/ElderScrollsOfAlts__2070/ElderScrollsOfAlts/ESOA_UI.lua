----------------------------------------
--[[ ESOA GUI / UI ]]-- 
-- ESOA GUI/UI Functions
----------------------------------------


------------------------------
-- SETUP: Colors
function ElderScrollsOfAlts.SetupDefaultColors()
	--ElderScrollsOfAlts.outputMsg("SetupDefaultColors: Called" )	
	if(ElderScrollsOfAlts.altData.accountdataonly) then
		ElderScrollsOfAlts.SetupDefaultColorsAccount()
	else
		ElderScrollsOfAlts.SetupDefaultColorsPercharacter()
	end
end
function ElderScrollsOfAlts.SetupDefaultColorsPercharacter()
	if(ElderScrollsOfAlts.savedVariables.colors==nil) then
		ElderScrollsOfAlts.savedVariables.colors = {}
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorTimerNear==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNear = {}
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer = {}
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer.r = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer.g = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer.b = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNearer.a = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorTimerDone==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorTimerDone = {}
		ElderScrollsOfAlts.savedVariables.colors.colorTimerDone.r = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorTimerDone.g = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorTimerDone.b = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorTimerDone.a = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorTimerNone==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNone = {}
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax = {}
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsMax.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax==nil) then
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax = {}
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.savedVariables.colors.colorSkillsNearMax.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
end
--  ElderScrollsOfAlts.altData.colors.colorTimerNone
--  ElderScrollsOfAlts.altData.colors.colorTimerX
--  were saved into ElderScrollsOfAlts.altData.defaults.colorX
function ElderScrollsOfAlts.SetupDefaultColorsAccount()
	if(ElderScrollsOfAlts.altData.colors==nil) then
		ElderScrollsOfAlts.altData.colors = {}
	end
	if(ElderScrollsOfAlts.altData.colors.colorTimerNear==nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNear = {}
		ElderScrollsOfAlts.altData.colors.colorTimerNear.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorTimerNear.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorTimerNear.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorTimerNear.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.altData.colors.colorTimerNearer==nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNearer = {}
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.r = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.g = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.b = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.a = ElderScrollsOfAlts.rgbaWhite.a
		end
	if(ElderScrollsOfAlts.altData.colors.colorTimerDone==nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerDone = {}
		ElderScrollsOfAlts.altData.colors.colorTimerDone.r = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorTimerDone.g = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorTimerDone.b = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorTimerDone.a = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.altData.colors.colorTimerNone==nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNone = {}
		ElderScrollsOfAlts.altData.colors.colorTimerNone.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorTimerNone.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorTimerNone.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorTimerNone.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.altData.colors.colorSkillsMax==nil) then
		ElderScrollsOfAlts.altData.colors.colorSkillsMax = {}
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	if(ElderScrollsOfAlts.altData.colors.colorSkillsNearMax==nil) then
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax = {}
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.r   = ElderScrollsOfAlts.rgbaWhite.r
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.g   = ElderScrollsOfAlts.rgbaWhite.g
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.b   = ElderScrollsOfAlts.rgbaWhite.b
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.a   = ElderScrollsOfAlts.rgbaWhite.a
	end
	--
	--were saved into ElderScrollsOfAlts.altData.defaults.colorX
	--
	--if( ElderScrollsOfAlts.altData.colorssetupfromSV==nil) then
	if(ElderScrollsOfAlts.altData.defaults.colorTimerNear~=nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNear.r   = ElderScrollsOfAlts.altData.defaults.colorTimerNear.r
		ElderScrollsOfAlts.altData.colors.colorTimerNear.g   = ElderScrollsOfAlts.altData.defaults.colorTimerNear.g
		ElderScrollsOfAlts.altData.colors.colorTimerNear.b   = ElderScrollsOfAlts.altData.defaults.colorTimerNear.b
		ElderScrollsOfAlts.altData.colors.colorTimerNear.a   = ElderScrollsOfAlts.altData.defaults.colorTimerNear.a
	end
	if(ElderScrollsOfAlts.altData.defaults.colorTimerNearer~=nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.r   = ElderScrollsOfAlts.altData.defaults.colorTimerNearer.r
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.g   = ElderScrollsOfAlts.altData.defaults.colorTimerNearer.g
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.b   = ElderScrollsOfAlts.altData.defaults.colorTimerNearer.b
		ElderScrollsOfAlts.altData.colors.colorTimerNearer.a   = ElderScrollsOfAlts.altData.defaults.colorTimerNearer.a
		end
	if(ElderScrollsOfAlts.altData.defaults.colorTimerDone~=nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerDone.r   = ElderScrollsOfAlts.altData.defaults.colorTimerDone.r
		ElderScrollsOfAlts.altData.colors.colorTimerDone.g   = ElderScrollsOfAlts.altData.defaults.colorTimerDone.g
		ElderScrollsOfAlts.altData.colors.colorTimerDone.b   = ElderScrollsOfAlts.altData.defaults.colorTimerDone.b
		ElderScrollsOfAlts.altData.colors.colorTimerDone.a   = ElderScrollsOfAlts.altData.defaults.colorTimerDone.a
	end
	if(ElderScrollsOfAlts.altData.defaults.colorTimerNone~=nil) then
		ElderScrollsOfAlts.altData.colors.colorTimerNone.r   = ElderScrollsOfAlts.altData.defaults.colorTimerNone.r
		ElderScrollsOfAlts.altData.colors.colorTimerNone.g   = ElderScrollsOfAlts.altData.defaults.colorTimerNone.g
		ElderScrollsOfAlts.altData.colors.colorTimerNone.b   = ElderScrollsOfAlts.altData.defaults.colorTimerNone.b
		ElderScrollsOfAlts.altData.colors.colorTimerNone.a   = ElderScrollsOfAlts.altData.defaults.colorTimerNone.a
	end
	if(ElderScrollsOfAlts.altData.defaults.colorSkillsMax~=nil) then
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.r   = ElderScrollsOfAlts.altData.defaults.colorSkillsMax.r
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.g   = ElderScrollsOfAlts.altData.defaults.colorSkillsMax.g
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.b   = ElderScrollsOfAlts.altData.defaults.colorSkillsMax.b
		ElderScrollsOfAlts.altData.colors.colorSkillsMax.a   = ElderScrollsOfAlts.altData.defaults.colorSkillsMax.a
	end
	if(ElderScrollsOfAlts.altData.colors.colorSkillsNearMax==nil) then
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.r   = ElderScrollsOfAlts.altData.defaults.colorSkillsNearMax.r
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.g   = ElderScrollsOfAlts.altData.defaults.colorSkillsNearMax.g
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.b   = ElderScrollsOfAlts.altData.defaults.colorSkillsNearMax.b
		ElderScrollsOfAlts.altData.colors.colorSkillsNearMax.a   = ElderScrollsOfAlts.altData.defaults.colorSkillsNearMax.a
	end
	--ElderScrollsOfAlts.altData.colorssetupfromSV=true
	--end
end
--[[
ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.r = 0.64 
ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.g = 0.224
ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.b = 0.208
ElderScrollsOfAlts.savedVariables.colors.colorTimerNear.a = ElderScrollsOfAlts.rgbaBase.a  
ElderScrollsOfAlts.savedVariables.colors.colorTimerNone = {}
ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.r = 0.178
ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.g = 0.48
ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.b = 0.96
ElderScrollsOfAlts.savedVariables.colors.colorTimerNone.a = 0.9
--]]

------------------------------
-- SETUP:
function ElderScrollsOfAlts:ResetUIViews(self)
	ElderScrollsOfAlts.outputMsg("ResetUIViews:"," Called!")
	local guiview = ElderScrollsOfAlts.CtrlGetGUIView()
    --ElderScrollsOfAlts.savedVariables.gui = {}
    -- Would, but lack of order
    --[[local guiTCopy = ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates)
    for viewIdx, guiLine in pairs(guiTCopy) do
      table.insert( ElderScrollsOfAlts.savedVariables.gui, guiLine )
    end--]]
	table.clear(guiview)
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Home"])     )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Pvp"])    )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Skills"])   )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Research"]) )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Crafting"])    )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Companions"])    )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Writs"])    )
    table.insert( guiview, ElderScrollsOfAlts:deepcopy(ElderScrollsOfAlts.view.guiTemplates["Equip"])    )
    --
    ElderScrollsOfAlts.savedVariables.currentView = nil
end
------------------------------

function ElderScrollsOfAlts:ResetPlayerOrder() --TODO Datastore
  local pServer   = GetWorldName()
  if(ElderScrollsOfAlts.altData.players~=nil) then
	  for i = 1, GetNumCharacters() do
		  local charName, _, _, _, _, _, charID = GetCharacterInfo(i)
		  local playerKey = charID.."_".. pServer:gsub(" ","_")
		  if(ElderScrollsOfAlts.altData.players[playerKey]~=nil) then
			ElderScrollsOfAlts.altData.players[playerKey].playerscreenorder = i
		  end
	  end
  end
  --TODO for esoadata
end
------------------------------
-- SETUP:
function ElderScrollsOfAlts.CheckUIData()
	ElderScrollsOfAlts.debugMsg("CheckUIData:"," Called!")
	--
	if(ElderScrollsOfAlts.savedVariables.fieldWidthForName==nil) then
		ElderScrollsOfAlts.savedVariables.fieldWidthForName=nil
	end
	--
	if(ElderScrollsOfAlts.altData.fieldWidthForName==nil) then
		ElderScrollsOfAlts.altData.fieldWidthForName = ElderScrollsOfAlts.defaultFieldWidthForName
	end
	if(ElderScrollsOfAlts.altData.fieldYOffset==nil) then
		ElderScrollsOfAlts.altData.fieldYOffset = ElderScrollsOfAlts.defaultFieldYOffset
	end
	--NEW 2024 10 06
	ElderScrollsOfAlts.altData.fieldYOffset = 0
	--
	ElderScrollsOfAlts.debugMsg("CheckUIData:"," Done!")
end

------------------------------
-- SETUP:
function ElderScrollsOfAlts.InitializeGui()
  ElderScrollsOfAlts.debugMsg("InitializeGui:"," Called!")
  ElderScrollsOfAlts.CheckInitialData()
  
  -- GUI Views Update
  if( not ElderScrollsOfAlts.CtrlIsGUIViewInitialized() ) then
    ElderScrollsOfAlts:ResetUIViews(self)
    --
  end
  -- GUI Views Update
  
  -- Setup Cat
  if(ElderScrollsOfAlts.savedVariables.selected.category==nil)then
    ElderScrollsOfAlts.savedVariables.selected.category = ElderScrollsOfAlts.CATEGORY_ALL
  end
  
  -- Initialize 
  ESOATooltip:SetParent(PopupTooltipTopLevel)
  --ESOACraftTooltip:SetParent(PopupTooltipTopLevel)
  --ESOAEquipTooltip:SetParent(PopupTooltipTopLevel)
  --ElderScrollsOfAlts:GuiSetupDropdownA()
  
  --Setup Base GUI
  local pName = GetUnitName("player")
  local sVal = zo_strformat("(<<C:1>>)", pName )
  ESOA_GUI2_Header_WhoAmI:SetText(sVal)
  
  local namewidth = 160
  if( ElderScrollsOfAlts.altData.fieldWidthForName~=nil ) then
	namewidth = ElderScrollsOfAlts.altData.fieldWidthForName
  end
  --Calc Upper Header Min Width
  local mainHdrMinWidth = 
    ESOA_GUI2_Header_Locked:GetWidth() + 
    ESOA_GUI2_Header_Label:GetWidth() + 
    ESOA_GUI2_Header_Hide:GetWidth() + 
    ESOA_GUI2_Header_Minimize:GetWidth() + 
    ESOA_GUI2_Header_CategorySelect:GetWidth() + 
    namewidth + --name width, was always=160
    ESOA_GUI2_Header_SortUp:GetWidth() + 
    ESOA_GUI2_Header_SortDown:GetWidth() + 
    ESOA_GUI2_Header_SortBy_Value:GetWidth() + 
    ESOA_GUI2_Header_SortBy_Label:GetWidth() + 
	ESOA_GUI2_Header_Dropdown_AccountName:GetWidth() + 
    ESOA_GUI2_Header_WhoAmI:GetWidth()
  --
  ElderScrollsOfAlts.debugMsg("mainHdrMinWidth=",tostring(mainHdrMinWidth))
  ElderScrollsOfAlts.view.headerWinWidth = mainHdrMinWidth
  ESOA_GUI2_Body_CharListHeader.headerWinWidth = mainHdrMinWidth
  
  --Setup Default Sort TODO
  --
  ESOA_GUI2_Body_ListHolder.defaultMaxLines = ElderScrollsOfAlts.defaultMaxLines
  
  --ElderScrollsOfAlts.savedVariables.selected.category
  ElderScrollsOfAlts:GuiSetupCategoryButton(self)  
  
  if(ElderScrollsOfAlts.savedVariables.viewmousehighlight==nil)then
    ElderScrollsOfAlts.savedVariables.viewmousehighlight = {}
	ElderScrollsOfAlts.CtrlSetShowMouseHighlight(true)
  end
  if(ElderScrollsOfAlts.savedVariables.uibutton==nil) then
    ElderScrollsOfAlts.savedVariables.uibutton = {}
  end
  if(ElderScrollsOfAlts.savedVariables.viewdropdown==nil) then
    ElderScrollsOfAlts.savedVariables.viewdropdown = {}
  end
  if(ElderScrollsOfAlts.savedVariables.cpactivebar1==nil) then
    ElderScrollsOfAlts.savedVariables.cpactivebar1 = {}
    ElderScrollsOfAlts.savedVariables.cpactivebar1.show = false
  end
  if(ElderScrollsOfAlts.savedVariables.cpactivebar2==nil) then
    ElderScrollsOfAlts.savedVariables.cpactivebar2 = {}
    ElderScrollsOfAlts.savedVariables.cpactivebar2.show = false
  end
  if(ElderScrollsOfAlts.savedVariables.hideinmenus==nil) then
    ElderScrollsOfAlts.savedVariables.hideinmenus = false
  end
  --TODO temp fix
  ElderScrollsOfAlts.savedVariables.hideinmenus = false
  
  --ESOA_GUI2_Header_SortUp / ESOA_GUI2_Header_SortDown
  --DoGuiSort(control, newSort, sortText)
  ESOA_GUI2_Header_SortUp:SetMouseEnabled(true)
  ESOA_GUI2_Header_SortUp:SetHandler('OnMouseUp',function(self)
        ElderScrollsOfAlts:DoGuiSort(self, true, nil)
        ElderScrollsOfAlts.RefreshViewableTable()
    end)
  ESOA_GUI2_Header_SortDown:SetMouseEnabled(true)
  ESOA_GUI2_Header_SortDown:SetHandler('OnMouseUp',function(self)
        ElderScrollsOfAlts:DoGuiSort(self, true, nil)
        ElderScrollsOfAlts.RefreshViewableTable()
    end)
  --
  local fragment1 = ZO_HUDFadeSceneFragment:New(ESOA_GUI2, nil, 0)
  ElderScrollsOfAlts.view.esoagui2fragment = fragment1
  if(ElderScrollsOfAlts.savedVariables.hideinmenus==true) then
    --local fragment1 = ZO_HUDFadeSceneFragment:New(ESOA_GUI2, nil, 0)
    HUD_SCENE:AddFragment(ElderScrollsOfAlts.view.esoagui2fragment)
    HUD_UI_SCENE:AddFragment(ElderScrollsOfAlts.view.esoagui2fragment)
  else
    fragment1 = ZO_HUDFadeSceneFragment:New(ESOA_GUI2, nil, 0)
    ElderScrollsOfAlts.view.esoagui2fragment = fragment1
    HUD_SCENE:RemoveFragment(ElderScrollsOfAlts.view.esoagui2fragment)
    HUD_UI_SCENE:RemoveFragment(ElderScrollsOfAlts.view.esoagui2fragment)
  end
  
  --Cache Colors
  --local cCD = ZO_ColorDef:New(colors.r, colors.g, colors.b, colors.a)
  --
  ElderScrollsOfAlts:SetupCPBar()
end

------------------------------
-- SETUP: Called from Delayed Start
function ElderScrollsOfAlts:RestoreUI()
  if ElderScrollsOfAlts.CtrlIsShowUiButton() then
    ElderScrollsOfAlts.ShowUIButton()
  else
    ElderScrollsOfAlts.HideUIButton()
  end
end


------------------------------
-- UI: View, Setup and Show
function ElderScrollsOfAlts:ShowGuiByChoice()
  ElderScrollsOfAlts.debugMsg("ShowGuiByChoice");
  if( ESOA_GUI2:IsHidden()) then
    ElderScrollsOfAlts:CreateGUI()
	ElderScrollsOfAlts.view.needToLoadGuiData = false
    ElderScrollsOfAlts:ShowSetView()
	ElderScrollsOfAlts.view.needToLoadGuiData = true
	--SCENE_MANAGER:ToggleTopLevel(ESOA_GUI2)???
  else
    ESOA_GUI2:SetHidden(true)
  end
  
  ElderScrollsOfAlts.view.playersexisting = {}
  local numchars = ZO_AddOnManager:GetNumCharacters()
  ElderScrollsOfAlts.debugMsg("ESOA, numchars: '", numchars , "'")
  ElderScrollsOfAlts.view.numchars = numchars
  -- not callable here??
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:HideAll()
  ElderScrollsOfAlts.HideUIButton()
  ESOA_GUI2:SetHidden(true)  
  ElderScrollsOfAlts:CloseNote(self)
end

------------------------------
-- UI: UIButton
function ElderScrollsOfAlts.ShowUIButton()
  ElderScrollsOfAlts.debugMsg("ShowUIButton");
  --d("ShowUIButton called. left="..tostring(ElderScrollsOfAlts.savedVariables.uibutton.left))
  if(ElderScrollsOfAlts.CtrlIsShowUiButton())then
    ESOA_ButtonFrame:SetHidden(false)
    ESOA_ButtonFrame:ClearAnchors()
    ESOA_ButtonFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 
      ElderScrollsOfAlts.savedVariables.uibutton.left, ElderScrollsOfAlts.savedVariables.uibutton.top)
  end
end

------------------------------
-- UI: UIButton
function ElderScrollsOfAlts.HideUIButton()
  ESOA_ButtonFrame:SetHidden(true)
end

------------------------------
-- UI: UIButton
function ElderScrollsOfAlts.DoUiButtonClicked()
  ElderScrollsOfAlts:ShowGuiByChoice()    
  --[[local isShown = ESOA_GUI2:IsHidden()
  if not isShown then
    ElderScrollsOfAlts:ShowGuiByChoice()    
  else
    ElderScrollsOfAlts:HideAll()
  end --]] 
end

------------------------------
-- UI: UIButton
function ElderScrollsOfAlts:ButtonFrameOnMoveStop(mySelf)
  ElderScrollsOfAlts.savedVariables.uibutton.top    = ESOA_ButtonFrameButton:GetTop()
  ElderScrollsOfAlts.savedVariables.uibutton.left   = ESOA_ButtonFrameButton:GetLeft()
  ElderScrollsOfAlts.debugMsg("ButtonFrameOnMoveStop: called. left="..tostring(ElderScrollsOfAlts.savedVariables.uibutton.left))
  ElderScrollsOfAlts.debugMsg("ButtonFrameOnMoveStop: called. top="..tostring(ElderScrollsOfAlts.savedVariables.uibutton.top))
end

------------------------------
-- VIEWS: 
function ElderScrollsOfAlts:getViewDataByName(viewNameFind)
  if(viewNameFind==nil) then
    return nil
  end
  local guiview = ElderScrollsOfAlts.CtrlGetGUIView()
  for viewIdx, guiLine in pairs(guiview) do
    local viewName = guiLine.name
    if(viewName==viewNameFind) then
      return guiLine
    end
  end
  return nil
end

------------------------------
-- VIEWS: 
function ElderScrollsOfAlts:ShowAndSetAccount(viewName, viewIdx, buttonCalled)
	local viewChanged = false
	if( ElderScrollsOfAlts.view.selectedAccount ~= viewName ) then
		viewChanged = true
	end
	ElderScrollsOfAlts.view.selectedAccount 	= viewName
	ElderScrollsOfAlts.view.selectedAccountIdx 	= viewIdx
	--
	ESOA_GUI2_Header_Dropdown_Views.comboBoxAccount = ESOA_GUI2_Header_Dropdown_AccountName.comboBox or ZO_ComboBox_ObjectFromContainer(ESOA_GUI2_Header_Dropdown_AccountName)
	local comboBoxAccount = ESOA_GUI2_Header_Dropdown_Views.comboBoxAccount
	--
	comboBoxAccount:SetSelected(ElderScrollsOfAlts.view.selectedAccount)
	--
	if(viewChanged == true) then
		ElderScrollsOfAlts:HideAll()
		ElderScrollsOfAlts:ShowGuiByChoice()
	end
	--ElderScrollsOfAlts:LoadPlayerDataForGui()
	--
end

------------------------------
-- VIEWS: 
function ElderScrollsOfAlts:ShowAndSetView(viewName, viewIdx, buttonCalled)
  ElderScrollsOfAlts.savedVariables.lastView       = ElderScrollsOfAlts.savedVariables.currentView
  ElderScrollsOfAlts.savedVariables.currentView    = viewName
  ElderScrollsOfAlts.savedVariables.currentViewIdx = viewIdx
  --ElderScrollsOfAlts.view.viewButtons
  for _, btnLine in pairs(ElderScrollsOfAlts.view.viewButtons) do
    --btnLine:SetFont(ZoFontGameLarge)--TODO
    btnLine:SetText( btnLine.viewName )
  end
  if(buttonCalled~=nil and buttonCalled.viewName~=nil )then
    --buttonCalled:SetFont(ZoFontGameLargeBold)--TODO
    buttonCalled:SetText( "<"..buttonCalled.viewName..">" )--TODO localize
  end
  ElderScrollsOfAlts:ShowSetView()
end

------------------------------
-- VIEWS: View, Setup and Show
function ElderScrollsOfAlts:ShowNextView()
  if(ElderScrollsOfAlts.view.viewButtons==nil)then
    return
  end
  if(ElderScrollsOfAlts.savedVariables.currentViewIdx==nil)then
    ElderScrollsOfAlts.savedVariables.currentViewIdx = 1
  end
  
  ElderScrollsOfAlts.savedVariables.currentViewIdx = ElderScrollsOfAlts.savedVariables.currentViewIdx + 1
  if(ElderScrollsOfAlts.savedVariables.currentViewIdx > #ElderScrollsOfAlts.view.viewButtons)then
    ElderScrollsOfAlts.savedVariables.currentViewIdx = 1
  end
  local viewButton = nil
  if(ElderScrollsOfAlts.view.viewButtons~=nil)then
    viewButton = ElderScrollsOfAlts.view.viewButtons[ElderScrollsOfAlts.savedVariables.currentViewIdx]
    if(viewButton~=nil)then
      ElderScrollsOfAlts.savedVariables.currentView = viewButton.viewName
    else
      ElderScrollsOfAlts.savedVariables.currentView    = ElderScrollsOfAlts.view.viewButtons[1]["viewName"]
      ElderScrollsOfAlts.savedVariables.currentViewIdx = 1
    end
  end  
      
  local viewIdx = ElderScrollsOfAlts.view.viewLookupIdxFromName[ElderScrollsOfAlts.savedVariables.currentView]
  ElderScrollsOfAlts:ShowAndSetView(ElderScrollsOfAlts.savedVariables.currentView, viewIdx, viewButton)
  --ElderScrollsOfAlts:RefreshView()
end

--[[
function ElderScrollsOfAlts:RefreshView()
  -- Setup common GUI
  ElderScrollsOfAlts.ShowGuiBase()
  --
  -- Setup Header 
  ElderScrollsOfAlts:SetupGuiHeaderListing() 
  
  --Setup Data lines
  --Show Viewable
  ElderScrollsOfAlts.RefreshViewableTable()
end
]]--

------------------------------
-- VIEWS: SETUP tttt
function ElderScrollsOfAlts:SetupAndShowViewButtons()
  local viewPred = ESOA_GUI2_Header_Label
  local vParent  = ESOA_GUI2_Header
  --dropdown ESOA_GUI2_Header_Dropdown_Views TODO
  ESOA_GUI2_Header_Dropdown_Views.comboBox = ESOA_GUI2_Header_Dropdown_Views.comboBox or ZO_ComboBox_ObjectFromContainer(ESOA_GUI2_Header_Dropdown_Views)
  local comboBox = ESOA_GUI2_Header_Dropdown_Views.comboBox
  comboBox:ClearItems()  
  comboBox:SetSortsItems(false)
  local function OnItemSelect1(_, choiceText, choice)
    --ElderScrollsOfAlts:debugMsg(" choiceText=" .. choiceText .. " choice=" .. tostring(choice) )    
    local viewIdx = ElderScrollsOfAlts.view.viewLookupIdxFromName[choiceText]
    ElderScrollsOfAlts:ShowAndSetView(choiceText,viewIdx,nil)
    PlaySound(SOUNDS.POSITIVE_CLICK)
  end
  local validChoices = {}
  --Setup View Buttons (ESOA_View_Template)
  -- IF ElderScrollsOfAlts.savedVariables.gui is large , make a dropdown instead
  if(ElderScrollsOfAlts.altData.maxViewButtons==nil)then
    ElderScrollsOfAlts.altData.maxViewButtons = ElderScrollsOfAlts.defaultMaxViewButtons
  end
  
  if(ElderScrollsOfAlts.view~=nil and ElderScrollsOfAlts.view.viewButtons~=nil)then
    for viewBtnIdx = 1, #ElderScrollsOfAlts.view.viewButtons do
      local btnLine = ElderScrollsOfAlts.view.viewButtons[viewBtnIdx]
      btnLine:SetHidden(true)
    end
  end
  
  ElderScrollsOfAlts.view.viewButtons = {}
  ElderScrollsOfAlts.view.viewLookupIdxFromName  = {}
  local viewCnt = 0
  local mhminWidth = ElderScrollsOfAlts.view.headerWinWidth
  if(not ElderScrollsOfAlts.CtrlIsGUIViewInitialized()) then
    ElderScrollsOfAlts.outputMsg("InitializeGui wasn't called first, calling now")
    ElderScrollsOfAlts.InitializeGui()
  end 
  local guiview = ElderScrollsOfAlts.CtrlGetGUIView()
  if( guiview==nill or #guiview==0) then
	ElderScrollsOfAlts.outputMsg("Error with SetupAndShowViewButtons guiview" )
  end
  ElderScrollsOfAlts.debugMsg("SetupAndShowViewButtons: guiview#=", #guiview )
  for viewIdx = 1, #guiview do
    local guiLine = guiview[viewIdx]
	if(guiLine~=nil) then
		local viewName = guiLine.name
		if(viewName==nil) then viewName = "FIXME"+math.random() end    
		table.insert(validChoices,  viewName )
		--
		local line = vParent:GetNamedChild('_ViewBtn_'..viewName )
		if(line==nil)then
		  line = WINDOW_MANAGER:CreateControlFromVirtual("ESOA_GUI2_Header_ViewBtn_"..viewName, vParent, "ESOA_View_Template")
		end
		--ElderScrollsOfAlts.outputMsg("InitializeGui: _ViewBtn_=", viewName )
		line:SetText( viewName ) --TODO get function to get display name
		
		if(ElderScrollsOfAlts.savedVariables.currentView==viewName)then
		  line:SetText( "<"..viewName..">" )--TODO localize
		end
		if(viewCnt<=ElderScrollsOfAlts.altData.maxViewButtons) then
		  line:SetHidden(false)
		else
		  line:SetHidden(true)
		end
		line.viewName = viewName
		line.viewIdx  = viewIdx
		ElderScrollsOfAlts.view.viewLookupIdxFromName[viewName] = viewIdx
		--line:SetDimensions(ElderScrollsOfAlts.GuiSortBarLookupDisplayWidth(entry,customWidths), ElderScrollsOfAlts.defaultFieldHeight)
		--line:SetAnchor(TOPLEFT, predecessor, TOPRIGHT, 0, 0)
		if(viewPred==nil)then
		  line:SetAnchor(TOPLEFT, vParent, TOPLEFT, 10, 24)    
		else
		  line:SetAnchor(TOPLEFT, viewPred, TOPRIGHT, 10, 0)    
		end
		-- add to min width
		table.insert(ElderScrollsOfAlts.view.viewButtons,line)      
		viewCnt = viewCnt+1
		local lw = line:GetWidth()
		if(lw==nil) then lw = 0 end
		if(mhminWidth==nil) then mhminWidth = 0 end
		mhminWidth = mhminWidth + lw
		viewPred = line		
	end
  end
  --Dropdown
  for i = 1, #validChoices do
    local entry = comboBox:CreateItemEntry(validChoices[i], OnItemSelect1)
    comboBox:AddItem(entry)
  end
  --
  -- Account DropDown (ZO_ScrollableComboBox)
  --
  ElderScrollsOfAlts:SetupAccountDropDown()
  --
  ESOA_GUI2_Body_CharListHeader.headerWinWidth = mhminWidth  
  --
end

------------------------------
-- VIEWS: SETUP tttt
function ElderScrollsOfAlts:SetupAccountDropDown()
	ESOA_GUI2_Header_Dropdown_Views.comboBoxAccount = ESOA_GUI2_Header_Dropdown_AccountName.comboBox or ZO_ComboBox_ObjectFromContainer(ESOA_GUI2_Header_Dropdown_AccountName)
	local comboBoxAccount = ESOA_GUI2_Header_Dropdown_Views.comboBoxAccount
	comboBoxAccount:ClearItems()  
	comboBoxAccount:SetSortsItems(false)
	local function OnItemSelectAccount(_, choiceText, choice)
		ElderScrollsOfAlts:debugMsg("AccountSelect: choiceText=" .. choiceText .. " choice=" .. tostring(choice) )
		--ElderScrollsOfAlts:dumpPrintTable(choice)
		local viewIdx = ElderScrollsOfAlts.view.accountLookupIdxFromName[choiceText]
		ElderScrollsOfAlts:ShowAndSetAccount(choiceText,viewIdx, true )
		PlaySound(SOUNDS.POSITIVE_CLICK)
	end
	local validChoicesAccount = {}
	ElderScrollsOfAlts.view.accountLookupIdxFromName = {}
	if(ESOADatastore~=nil) then
		local list = ESOADatastore.getAccountList()
		for account, serverdata in pairs(list) do
			--bar.account = dServer
			--bar.server  = dName
			table.insert(validChoicesAccount, account )
			ElderScrollsOfAlts.view.accountLookupIdxFromName[account] = i
		end
	else 
		table.insert(validChoicesAccount, GetDisplayName() )
		ElderScrollsOfAlts.view.accountLookupIdxFromName[GetDisplayName()] = 1
	end
	--
	if( ElderScrollsOfAlts.view.selectedAccount ==nil ) then
		ElderScrollsOfAlts.view.selectedAccount = ElderScrollsOfAlts.view.accountnamecurrrent
		--ElderScrollsOfAlts.view.selectedAccountIdx = i
	end 
	--
	ElderScrollsOfAlts.view.selectedAccountIdx = 1
	for i = 1, #validChoicesAccount do
		if( validChoicesAccount[i] == ElderScrollsOfAlts.view.selectedAccount ) then
			ElderScrollsOfAlts.view.selectedAccountIdx = i
		end		
		local entry = comboBoxAccount:CreateItemEntry(validChoicesAccount[i], OnItemSelectAccount)
		comboBoxAccount:AddItem(entry)
	end
	--
	comboBoxAccount:SetSelected(ElderScrollsOfAlts.view.selectedAccountIdx)
end

------------------------------
-- VIEWS: Setup tttt
-- Load/Save data, and setup views
function ElderScrollsOfAlts:CreateGUI()
  if(ElderScrollsOfAlts.savedVariables.currentView == nil) then
    ElderScrollsOfAlts.savedVariables.currentView = GetString(ESOA_VIEW_HOME)
  end
  ElderScrollsOfAlts.debugMsg("CreateGUI: currentSavedView=",ElderScrollsOfAlts.savedVariables.currentView)
  --
  ElderScrollsOfAlts.SavePlayerDataForGui(ElderScrollsOfAlts.manualload)
  
  --Setup Data
  if( ElderScrollsOfAlts.view.needToLoadGuiData ) then
    ElderScrollsOfAlts:LoadPlayerDataForGui()
  end
  
  --Setup Views
  ElderScrollsOfAlts:SetupAndShowViewButtons()
  
  --[[
  local hllineName = "ESOA_GUI2_Body_ListHolder_Highlight_Selected"  
  local hlline = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Highlight_Selected')  
  if(hlline==nil)then
    hlline = WINDOW_MANAGER:CreateControlFromVirtual(hllineName, ESOA_GUI2_Body_ListHolder, "ESOA_RowTemplate_Highlight2")
  end
  ESOA_GUI2_Body_ListHolder.hightlightSelected = hlline
  ESOA_GUI2_Body_ListHolder.hightlightSelected:SetHidden(true)
  --]]--
  --
  local hllineName2 = "ESOA_GUI2_Body_ListHolder_Highlight"
  local hlline2 = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Highlight')  
  if(hlline2==nil)then
    hlline2 = WINDOW_MANAGER:CreateControlFromVirtual(hllineName2, ESOA_GUI2_Body_ListHolder, "ESOA_RowTemplate_Highlight")
  end
  ESOA_GUI2_Body_ListHolder.mouseHighlight = hlline2
  ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(true)
  
  --Setup all PlayerData Lines (w/o data) 
  local parent     = nil
  ESOA_GUI2_Body_ListHolder.dataHolderLines = {}
  ElderScrollsOfAlts.debugMsg("CreateGUI: whoami=",tostring(ElderScrollsOfAlts.view.whoiamplayerKey) )
  --FOR EACH CHAR 
  local playerLines = ElderScrollsOfAlts.view.playerLines
  if(playerLines~=nil) then
  for k_entry, playerline in pairs(playerLines) do
    local charKey = k_entry	
	ElderScrollsOfAlts.debugMsg("CreateGUI: charKey=",tostring(charKey) )
    --local lineName = "ESOA_GUI2_Body_ListHolder_Line_"..viewName.."_" ..charKey  
    local lineName = "ESOA_GUI2_Body_ListHolder_Line_" ..charKey  
    --create the line holder
    local line = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Line_'..charKey)
    if(line==nil)then
      line = WINDOW_MANAGER:CreateControlFromVirtual(lineName, ESOA_GUI2_Body_ListHolder, "ESOA_RowTemplate")
    end
    line:SetHidden(true)
    --(AnchorPosition myPoint, object anchorTargetControl, AnchorPosition anchorControlsPoint, number offsetX, number offsetY) 
    if(parent==nil)then
      line:SetAnchor(TOPLEFT, ESOA_GUI2_Body_ListHolder, TOPLEFT, 0, 5)    
    else
      line:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, 0, 15)    
    end
	--
    line.charKey = charKey
    line.playerLine = playerline
    line:SetHandler("OnMouseEnter", function(self) ElderScrollsOfAlts:GuiLineOnMouseEnter(self) end )
    line:SetHandler("OnMouseExit", function(self) ElderScrollsOfAlts:GuiLineOnMouseExit(self) end )
    line:SetHandler("OnMouseDoubleClick", function(...) ElderScrollsOfAlts:GUILineDoubleClick(...) end )
    --
    --TODO is me? SetTexture? --ElderScrollsOfAlts.view.whoiamplayerKey
    --ElderScrollsOfAlts.debugMsg("CreateGUI: charKey='"..charKey.."' whoami='"..tostring(ElderScrollsOfAlts.view.whoiamplayerKey).."'" )
    ElderScrollsOfAlts.debugMsg("CreateGUI: charKey='",charKey,"' whoami='",tostring(ElderScrollsOfAlts.view.whoiamplayerKey),"'" )
    --if(ESOA_GUI2_Body_ListHolder.hightlightSelected==nil)then
    --  ElderScrollsOfAlts.debugMsg("CreateGUI: hightlightSelected is nil")
    --end
    ElderScrollsOfAlts.debugMsg("Check WhoamI: charKey=",charKey, "vs key=",ElderScrollsOfAlts.view.whoiamplayerKey )
    if(charKey == ElderScrollsOfAlts.view.whoiamplayerKey) then
      ElderScrollsOfAlts:ShowHightlight(line,true)
      ElderScrollsOfAlts.debugMsg("Selected current player to hightlight")
      ESOA_GUI2_Header_WhoAmI:SetHandler("OnMouseDoubleClick", function(...) 
		  --ElderScrollsOfAlts:GUILineDoubleClick(...)
		  local line2 = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Line_'..ElderScrollsOfAlts.view.whoiamplayerKey)
		  ElderScrollsOfAlts:ShowHightlight(line2)
      end )
	  ElderScrollsOfAlts:ShowHightlight(line)
      ESOA_GUI2_Header_WhoAmI:SetMouseEnabled(true)
    end
    --
    parent = line
    table.insert( ESOA_GUI2_Body_ListHolder.dataHolderLines, line )
      
    --NOTE no entries created here.
  end --FOR EACH CHAR 
  end
end--CreateGUI

------------------------------
-- VIEWS: Show the VIEW data for selected View
function ElderScrollsOfAlts:ShowSetView()
  if(ElderScrollsOfAlts.savedVariables.currentView == nil) then
    ElderScrollsOfAlts.savedVariables.currentView = GetString(ESOA_VIEW_HOME)
  end
  local currentView = ElderScrollsOfAlts.savedVariables.currentView
  ElderScrollsOfAlts.debugMsg("ShowSetView: currentSavedView=",currentView)
  
  --Setup Data
  if( ElderScrollsOfAlts.view.needToLoadGuiData ) then
    ElderScrollsOfAlts:LoadPlayerDataForGui()
  end
  
  --  
  local viewTemplateL = ElderScrollsOfAlts:getViewDataByName(ElderScrollsOfAlts.savedVariables.lastView)
  local viewTemplateC = ElderScrollsOfAlts:getViewDataByName(ElderScrollsOfAlts.savedVariables.currentView)
  if(viewTemplateC==nil)then
    --log error!
    ElderScrollsOfAlts.errorMsg("No view template for this View: " .. tostring(currentView) .." Resetting to last, or Default. Try again.")
    if(ElderScrollsOfAlts.savedVariables.lastView~=nil)then
      ElderScrollsOfAlts.savedVariables.currentView = ElderScrollsOfAlts.savedVariables.lastView
      ElderScrollsOfAlts.savedVariables.lastView    = nil
    else
      ElderScrollsOfAlts.savedVariables.currentView = GetString(ESOA_VIEW_HOME)
    end
    return
  end

  -- Setup common GUI
  ElderScrollsOfAlts.ShowGuiBase()
  --
  -- Setup Header 
  ElderScrollsOfAlts:SetupGuiHeaderListing(ElderScrollsOfAlts.savedVariables.currentView) 
  
  --Hide Body Items
  --ElderScrollsOfAlts.HideBodyItems()
  if(ESOA_GUI2_Body_ListHolder.displayedLines~=nil)then
    for k, dLine in pairs(ESOA_GUI2_Body_ListHolder.displayedLines) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("ShowSetView: Hid displayedLines=",dLine.charKey)
        dLine:SetHidden(true)
      end
    end  
  end
  if(ESOA_GUI2_Body_ListHolder.displayedEntries~=nil)then
    for k, dLine in pairs(ESOA_GUI2_Body_ListHolder.displayedEntries) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("ShowSetView: Hid displayedEntries=",dLine.entry)
        dLine:SetHidden(true)
      end
    end  
  end 
  if(ESOA_GUI2_Body_ListHolder.dataHolderLines~=nil)then
    for k, dLine in pairs(ESOA_GUI2_Body_ListHolder.dataHolderLines) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("ShowSetView: Hid dataHolderLines=",dLine.entry)
        dLine:SetHidden(true)
      end
    end  
  end
  if(ESOA_GUI2_Body_ListHolder.dataLines~=nil)then
    for k, dLine in pairs(ESOA_GUI2_Body_ListHolder.dataLines) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("ShowSetView: Hid dataLines=",dLine.entry)
        dLine:SetHidden(true)
      end
    end  
  end
  --
  --ESOA_GUI2_Body_ListHolder Defaults (TODO put in main file)
  ElderScrollsOfAlts.view.playerLineCount = #ESOA_GUI2_Body_ListHolder.dataHolderLines
  ESOA_GUI2_Body_ListHolder.dataLines = {}
  ESOA_GUI2_Body_ListHolder.rowHeight = 22
  ESOA_GUI2_Body_ListHolder.maxLines = ElderScrollsOfAlts.view.playerLineCount
  ESOA_GUI2_Body_ListHolder.dataOffset = 0
  if(ESOA_GUI2_Body_ListHolder.dataLines[1]~=nil) then
    local oldRowHeight = ESOA_GUI2_Body_ListHolder.rowHeight
    ESOA_GUI2_Body_ListHolder.rowHeight = ESOA_GUI2_Body_ListHolder.dataLines[1]:GetHeight(); --+ ElderScrollsOfAlts.altData.fieldYOffset
    --ElderScrollsOfAlts.debugMsg("(A)Reset lineH rowHeight from " .. tostring(oldRowHeight) .. " to ".. tostring( ESOA_GUI2_Body_ListHolder.rowHeight) )
  end
  local delDHL = {}
  --for category (from ESOA_GUI2_Body_ListHolder.dataHolderLines to ESOA_GUI2_Body_ListHolder.dataLines)
  local selCategory = ElderScrollsOfAlts.savedVariables.selected.category
  for dHL = 1, #ESOA_GUI2_Body_ListHolder.dataHolderLines do
	local dataHolderLine = ESOA_GUI2_Body_ListHolder.dataHolderLines[dHL] --ESOA_RowTemplate
    local charKey = dataHolderLine.charKey
	--ElderScrollsOfAlts.outputMsg("ShowSetView: charKey=",tostring(charKey) )
    local playerLine = ElderScrollsOfAlts.view.playerLines[charKey]
	-- Check that there are no invalid playerlines per bugs
	local playerLineT = type(playerLine)    
	if(playerLineT=='number') then
		ElderScrollsOfAlts.outputMsg("WARN: ShowSetView: charKey=",tostring(charKey), " playerLine=",tostring(playerLine), " type=",tostring(playerLineT))
		table.insert(delDHL,charKey)
	else
		local pCategory = playerLine.category
		local pServer   = playerLine.server
		if(pCategory==selCategory or ElderScrollsOfAlts.CATEGORY_ALL==selCategory )then
		  table.insert( ESOA_GUI2_Body_ListHolder.dataLines, dataHolderLine ) --ESOA_RowTemplate
		elseif( 
		  ElderScrollsOfAlts.starts_with(selCategory, ElderScrollsOfAlts.CATEGORY_US) and 
		  ElderScrollsOfAlts.starts_with(pServer, ElderScrollsOfAlts.CATEGORY_US)
		) then
		  table.insert( ESOA_GUI2_Body_ListHolder.dataLines, dataHolderLine ) --ESOA_RowTemplate
		elseif(
		  ElderScrollsOfAlts.starts_with(selCategory, ElderScrollsOfAlts.CATEGORY_EU) and 
		  ElderScrollsOfAlts.starts_with(pServer, ElderScrollsOfAlts.CATEGORY_EU) 
		) then
		  table.insert( ESOA_GUI2_Body_ListHolder.dataLines, dataHolderLine ) --ESOA_RowTemplate
		end
	end
    dataHolderLine:SetHidden(true)
  end
  --
  -- delete keys in table: delDHL  
  local cntDel = 0
  for rtK2,rtV2 in pairs(delDHL) do
	if(rtK2~=nil) then
		ElderScrollsOfAlts.debugMsg("Clean up of datalines: rtK2=",tostring(rtK2)," rtV2=",tostring(rtV2))
		--table.remove(ElderScrollsOfAlts.view.playerLines[rtV2])
		ElderScrollsOfAlts.view.playerLines[rtV2] = nil
		cntDel = cntDel+1
	end
  end
  if(cntDel>0)then
	ElderScrollsOfAlts.outputMsg("WARN: Had to clean up ",cntDel," datalines.")
  end
  --
  ElderScrollsOfAlts.view.playerLineCount = #ESOA_GUI2_Body_ListHolder.dataLines
  ElderScrollsOfAlts.debugMsg("ShowSetView: dataLinesCnt=" , tostring(ElderScrollsOfAlts.view.playerLineCount) )
  
  --Load Data/Entries
  local mainParentDH = nil
  for dHL = 1, #ESOA_GUI2_Body_ListHolder.dataLines do
    local dataHolderLine = ESOA_GUI2_Body_ListHolder.dataLines[dHL] --ESOA_RowTemplate
    local charKey = dataHolderLine.charKey
    local playerLine = ElderScrollsOfAlts.view.playerLines[charKey]
    ElderScrollsOfAlts.LoadDataEntriesForSetView(dataHolderLine,mainParentDH,playerLine) -- Populates the Lines with data for this view
    if(ElderScrollsOfAlts.view.builtWidth~=nil and ElderScrollsOfAlts.view.builtWidth>50) then
      dataHolderLine:SetWidth( ElderScrollsOfAlts.view.builtWidth )
      --Update Anchors for Lines TODO?
    end
    mainParentDH = dataHolderLine
  end
  
  --TODO?? ESOA_GUI2_Body_ListHolder.displayedLines   = {}
  --ESOA_GUI2_Body_ListHolder.displayedEntries = {}
  
  --Setup sort -- ESOA_GUI2_Body_ListHolder.dataLines
  ElderScrollsOfAlts:DoGuiSort(self)
  --Set max, and Hide lines out of the max display
  ElderScrollsOfAlts:GuiResizeScroll()
  --Show Viewable
  --ElderScrollsOfAlts.RefreshViewableTable()
  ----Setup max lines, and slider (calls RefreshViewableTable: create show lines based on offset)
	ElderScrollsOfAlts:UpdateDataScroll()
  --Set max, and Hide lines out of the max display
  --ElderScrollsOfAlts:GuiResizeScroll()
  --Show Viewable
  --ElderScrollsOfAlts.RefreshViewableTable()
  --ElderScrollsOfAlts:GuiResizeScroll()
	--ElderScrollsOfAlts:GuiOnScroll(ESOA_GUI2_Body_ListHolder, 1)
	ElderScrollsOfAlts:GuiOnScroll(ESOA_GUI2_Body_ListHolder, 1)
	
	ElderScrollsOfAlts:UpdateLineEntriesFont()
  --
end--ShowSetView

------------------------------
-- VIEWS: Hides offset rows, shows others
function ElderScrollsOfAlts.RefreshViewableTable()
  local lineParent = nil
  local parent     = nil
  
  --Hide Previously displayed Lines
  if(ESOA_GUI2_Body_ListHolder.displayedLines~=nil)then
    for k, dLine in pairs(ESOA_GUI2_Body_ListHolder.displayedLines) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("ShowSetView: Hid displayedLines=",dLine.charKey)
        dLine:SetHidden(true)
      end
    end  
  end
  ESOA_GUI2_Body_ListHolder.displayedLines = {}

  for dHL = 1, #ESOA_GUI2_Body_ListHolder.dataLines do
		local dataHolderLine = ESOA_GUI2_Body_ListHolder.dataLines[dHL]
    local charKey = dataHolderLine.charKey
    local playerLine = ElderScrollsOfAlts.view.playerLines[charKey]
    --Check OFFSET
    if( ESOA_GUI2_Body_ListHolder.dataOffset==nil or (dHL > ESOA_GUI2_Body_ListHolder.dataOffset) )then
      --Update Anchors for Lines
      if(lineParent==nil)then
        dataHolderLine:SetAnchor(TOPLEFT, ESOA_GUI2_Body_ListHolder, TOPLEFT, 0, 5)    
      else
        dataHolderLine:SetAnchor(TOPLEFT, lineParent, BOTTOMLEFT, 0, ElderScrollsOfAlts.altData.fieldYOffset)
		--TODO -10 is how it was, 0 makes the hightlight better, but makes it longer, so it effects resize/slider
      end
      table.insert( ESOA_GUI2_Body_ListHolder.displayedLines, dataHolderLine )
      --Check Max
      dataHolderLine:SetHidden(dHL > ESOA_GUI2_Body_ListHolder.maxLines)
      --ElderScrollsOfAlts.debugMsg("RefreshViewableTable: Hidden="..tostring(dHL > ESOA_GUI2_Body_ListHolder.maxLines))
      --dataHolderLine:SetHidden(false)
      lineParent = dataHolderLine
    else
      dataHolderLine:SetHidden(true)
    end
  end
  if(ESOA_GUI2_Body_ListHolder.dataLines[1]~=nil) then
    local oldRowHeight = ESOA_GUI2_Body_ListHolder.rowHeight
    ESOA_GUI2_Body_ListHolder.rowHeight = ESOA_GUI2_Body_ListHolder.dataLines[1]:GetHeight();-- + ElderScrollsOfAlts.altData.fieldYOffset
    --ElderScrollsOfAlts.debugMsg("(B)Reset lineH rowHeight from " .. tostring(oldRowHeight) .. " to ".. tostring( ESOA_GUI2_Body_ListHolder.rowHeight) )
  end
end

------------------------------
-- VIEWS: Populates the Lines with data for this view
function ElderScrollsOfAlts.LoadDataEntriesForSetView(dataLine, mainParentDH, playerLine) --ESOA_RowTemplate
  local viewNameS = ElderScrollsOfAlts.savedVariables.currentView
  local viewTemplateC = ElderScrollsOfAlts:getViewDataByName(ElderScrollsOfAlts.savedVariables.currentView)
  if(viewTemplateC==nil)then
    --log error!
    ElderScrollsOfAlts.errorMsg("No view template for this View: " .. viewNameS .. ", So view changed to default")
    ElderScrollsOfAlts.savedVariables.currentView = GetString(ESOA_VIEW_HOME)
    return
  end
 
  local builtWidth = 0
  local charKey = dataLine.charKey
  local builtWidthL = 0
    
  --Clear line Entries
  if(dataLine.displayedEntries~=nil)then
    for k, dLine in pairs(dataLine.displayedEntries) do
      if(dLine~=nil) then
        --ElderScrollsOfAlts.debugMsg("LoadDataEntriesForSetView: Hid item=",dLine.entry)
        dLine:SetHidden(true)
      end
    end  
  end
    
  --Setup Line
  ElderScrollsOfAlts.debugMsg("LoadDataEntriesForSetView: Setup line for charKey=",charKey)
  dataLine.displayedEntries = {}
  dataLine:SetHidden(false)
  if(mainParentDH==nil)then
    dataLine:SetAnchor(TOPLEFT, ESOA_GUI2_Body_ListHolder, TOPLEFT, 0, 5)    
  else
    dataLine:SetAnchor(TOPLEFT, mainParentDH, BOTTOMLEFT, 0, ElderScrollsOfAlts.altData.fieldYOffset)
  end
  --TODO is me? SetTexture? --ElderScrollsOfAlts.view.whoiamplayerKey
  if(charKey == ElderScrollsOfAlts.view.whoiamplayerKey)then
    --ESOA_GUI2_Body_ListHolder.hightlightSelected:SetAnchor(TOPLEFT, line, TOPLEFT, 0, 8) 
    --ESOA_GUI2_Body_ListHolder.hightlightSelected:SetAnchor(BOTTOMRIGHT, line, BOTTOMRIGHT, 0, -4) 
    --ESOA_GUI2_Body_ListHolder:SetHidden(false)
  end
  --
  --mainParent = dataLine
  local parent = dataLine
  --table.insert( ESOA_GUI2_Body_ListHolder.displayedLines, line)
    
  -- create the base name entry
  local entry = "Name"
  --ESOA_GUI2_Body_ListHolder_Line_<NAME>_Name
  local eline = parent:GetNamedChild('_'..entry )    
  local lineName = "ESOA_GUI2_Body_ListHolder_Line_" ..charKey  
  if(eline==nil)then
    eline = WINDOW_MANAGER:CreateControlFromVirtual(lineName.."_"..entry, parent, "ESOA_RowTemplate_Label")        
  end
  eline.linetype = 'name'
  eline:SetText( playerLine.name ) --TODO get function to get display name              
  eline:SetHidden(false) 
  eline:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
  --eline:SetDimensions(ElderScrollsOfAlts.GuiSortBarLookupDisplayWidth(entry,customWidths), ElderScrollsOfAlts.defaultFieldHeight)
  eline:SetDimensions(ElderScrollsOfAlts.altData.fieldWidthForName, ElderScrollsOfAlts.defaultFieldHeight)
  eline:SetMaxLineCount(ElderScrollsOfAlts.altData.fieldWidthForName)
  eline.tooltip = playerLine.name.."("..charKey..")"
  eline.entry   = entry
  eline.charKey = charKey
  eline:SetMouseEnabled(true)
  eline:SetHandler('OnMouseEnter',function(self)
      ElderScrollsOfAlts:TooltipEnter(self, self.entry)
  end)
  eline:SetHandler('OnMouseExit',function(self)
      ElderScrollsOfAlts:TooltipExit(self)
  end)

  eline:SetHandler('OnMouseExit',function(self)
      ElderScrollsOfAlts:TooltipExit(self)
  end)
  eline:SetHandler('OnClicked',function(self)
    PlaySound(SOUNDS.POSITIVE_CLICK)        
    --TODO show select?
    --[[
    if(ESOA_GUI2_Body_ListHolder.hightlightSelected ~=nil) then      
      --unselect ESOA_RowTemplate_Highlight
      ESOA_GUI2_Body_ListHolder.hightlightSelected:SetAnchor(TOPLEFT, eline, TOPLEFT, 0, 0) 
      ESOA_GUI2_Body_ListHolder.hightlightSelected:SetAnchor(BOTTOMRIGHT, eline, BOTTOMRIGHT, 0, 0) 
      ESOA_GUI2_Body_ListHolder.hightlightSelected:SetHidden(false)
      ElderScrollsOfAlts.debugMsg("Setting Hightlight Active")
    end 
    --]]--
  end)

  table.insert( dataLine.displayedEntries, eline)
  builtWidthL = builtWidthL + eline:GetWidth()
  --
  local customWidths = ElderScrollsOfAlts.CtrlGetViewCustomColWidthsParsed()

  --create the other entries
  local predecessor = eline
  --parent      = ESOA_GUI2_Body_ListHolder
  local viewName = viewTemplateC.name
  local viewData = viewTemplateC.view
  for i = 1, #viewData do
    entry = viewData[i]    
    eline = ElderScrollsOfAlts.GuiCharLineLookupDisplayType(viewName,entry,lineName,parent)
    if(eline==nil) then
      ElderScrollsOfAlts.outputMsg("Ack! Virtual control is nil?")
      --return
    else
      eline:SetHidden(false)
      eline:SetDimensions(ElderScrollsOfAlts.GuiSortBarLookupDisplayWidth(entry,customWidths),ElderScrollsOfAlts.defaultFieldHeight)
      eline:SetAnchor(TOPLEFT, predecessor, TOPRIGHT, 0, 0)
      eline:SetMouseEnabled(true)
      eline:SetHandler('OnMouseEnter',function(self)
          ElderScrollsOfAlts:TooltipEnter(self, self.entry)
      end)
      eline:SetHandler('OnMouseExit',function(self)
          ElderScrollsOfAlts:TooltipExit(self)
      end)
      --eline:SetHandler('OnClicked',function(self)
       --PlaySound(SOUNDS.POSITIVE_CLICK)        
        --ElderScrollsOfAlts:DoGuiSort(self, entry )
      --end)        
      ElderScrollsOfAlts.GuiCharLineLookupPopulateData(viewName,entry,eline,playerLine)
      eline.entry = entry
      eline.charKey=charKey
      table.insert( dataLine.displayedEntries, eline)
      --table.insert(ESOA_GUI2_Body_ListHolder.displayedEntries, eline)
      builtWidthL = builtWidthL + eline:GetWidth()
      predecessor = eline
    end
  end--for viewTemplate viewData
  if(builtWidthL>builtWidth) then builtWidth = builtWidthL end
  --if(line:GetWidth() > builtWidth)then
  --  builtWidth = line:GetWidth()
  --end
  --end-- offset
  --end --FOR EACH CHAR in category 
  
  builtWidth = builtWidth + 20 --PADDINGgui
  --debugMsg("builtWidth="..tostring(builtWidth) )
  --unless locked reset window width
  if( ESOA_GUI2_Header_Locked:IsHidden() ) then
    --Min Header Width too!!
    if(ESOA_GUI2_Body_CharListHeader.headerWinWidth~=nil and ESOA_GUI2_Body_CharListHeader.headerWinWidth > builtWidth) then
      ESOA_GUI2:SetWidth( ESOA_GUI2_Body_CharListHeader.headerWinWidth )
      ElderScrollsOfAlts.debugMsg("Reset width per header min as="..tostring(ESOA_GUI2_Body_CharListHeader.headerWinWidth))
    else
      ESOA_GUI2:SetWidth( builtWidth )
    end    
    ElderScrollsOfAlts.view.builtWidth = builtWidth
  end
  --TODO not working, need refresh??
  --Set max, and Hide lines out of the max display
  --ElderScrollsOfAlts:GuiResizeScroll()
  return dataLine
end --LoadDataEntriesForSetView

------------------------------
--Update Lines with FONT data
function ElderScrollsOfAlts:UpdateLineEntriesFont()
	ElderScrollsOfAlts.debugMsg("UpdateLineEntriesFont called")
	if(ElderScrollsOfAlts.savedVariables.selected.textFontSize~=nil) then
		-- TODO KB vs console!!
		ElderScrollsOfAlts.debugMsg("Selected font is set='"..tostring(ElderScrollsOfAlts.savedVariables.selected.textFontSize).."'")
		-- "$(KB_24)"
		local sz = string.format("$(KB_%s)", ElderScrollsOfAlts.savedVariables.selected.textFontSize )
		ElderScrollsOfAlts.debugMsg("Selected font is translated as='"..tostring(sz).."'")
		ElderScrollsOfAlts.esoaFontGame[ ElderScrollsOfAlts.FONT_SIZE ] = sz
	end
	local fontGame = ElderScrollsOfAlts:GetFontDescriptor( ElderScrollsOfAlts.esoaFontGame )
	ElderScrollsOfAlts.debugMsg("font fontGame='"..(fontGame).."'")
	if(ESOA_GUI2_Body_ListHolder.dataHolderLines) then
		for dHL = 1, #ESOA_GUI2_Body_ListHolder.dataHolderLines do
			local dataLine = ESOA_GUI2_Body_ListHolder.dataHolderLines[dHL] --ESOA_RowTemplate
			if(dataLine.displayedEntries~=nil)then
				for k, dLine in pairs(dataLine.displayedEntries) do
					if(dLine~=nil) then
						if(dLine.linetype=='label' or dLine.linetype=='name') then 					
							dLine:SetFont(fontGame)
							--d("font set dLine='"..tostring(dLine).."'")
						--else
							--d("font set dLine='"..tostring(dLine.linetype).."'")
						end
					end
				end  
			end
		end
	end
end

------------------------------
-- UI: ESOA_GUI2 was:ShowGui2
function ElderScrollsOfAlts.ShowGuiBase()
  if not ESOA_GUI2:IsHidden() then 
    --ESOA_GUI2:SetHidden(true)
    ElderScrollsOfAlts:CloseNote(self)
  else
    ESOA_GUI2:SetHidden(false)
    if ElderScrollsOfAlts.savedVariables.window.minimized then
      --TODO
      ElderScrollsOfAlts:GUI2Minimize(false)  
    end  
    if ElderScrollsOfAlts.savedVariables.window.justone then
      --ElderScrollsOfAlts:GUI2Iconify(false)
    end
    --TODO
    ESOA_GUI2_Body_CharListHeader:SetHidden(false)
    ESOA_GUI2_Body_ListHolder:SetHidden(false)  
  end

	--settings.hidden = true
  if ElderScrollsOfAlts.savedVariables.window.top ~= nil then
    local left = ElderScrollsOfAlts.savedVariables.window.left
    local top = ElderScrollsOfAlts.savedVariables.window.top
    ESOA_GUI2:ClearAnchors()
    ESOA_GUI2:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
    ESOA_GUI2:SetHeight(ElderScrollsOfAlts.savedVariables.window.height)
    ESOA_GUI2:SetWidth( ElderScrollsOfAlts.savedVariables.window.width )
  else 
    ElderScrollsOfAlts.savedVariables.window.justone = false  
    ElderScrollsOfAlts.savedVariables.window.top    = ESOA_GUI2:GetTop()
    ElderScrollsOfAlts.savedVariables.window.left   = ESOA_GUI2:GetLeft()
    ElderScrollsOfAlts.savedVariables.window.width  = ESOA_GUI2:GetWidth()
    ElderScrollsOfAlts.savedVariables.window.height = ESOA_GUI2:GetHeight()
  end
  
  --TODO view
  --ESOA_GUI2_Body_EquipListHeader:SetHidden(true)
  --ESOA_GUI2_Body_List_EQUIP:SetHidden(true)
  --ESOA_GUI2_Body_CharListHeader:SetHidden(bMin)
  --ESOA_GUI2_Body_CharList:SetHidden(bMin)
  --NEED TO CALL A VIEW before or after this!
end

------------------------------
-- VIEWS: 
function ElderScrollsOfAlts:SetupGuiHeaderListing(viewName)  
  local viewTemplateL = ElderScrollsOfAlts:getViewDataByName(ElderScrollsOfAlts.savedVariables.lastView)
  local viewTemplateC = ElderScrollsOfAlts:getViewDataByName(ElderScrollsOfAlts.savedVariables.currentView)
  ElderScrollsOfAlts.debugMsg("SetupGuiHeaderListing: viewTemplate=",viewTemplateC)
  
  if(viewTemplateC~=nil)then
    local predecessor = Enil--ESOA_GUI2_Body_CharListHeader_SortName
    local parent      = ESOA_GUI2_Body_CharListHeader    
      
    --Clean Entries
    if(ESOA_GUI2_Body_CharListHeader.headerLineItems~=nil)then
      for hi, hentry in pairs(ESOA_GUI2_Body_CharListHeader.headerLineItems) do
       if(hentry~=nil)then
          ElderScrollsOfAlts.debugMsg("SetupGuiHeaderListing: Hid item=",hentry.entry)
          hentry:SetHidden(true)
        end
      end
    end
    ESOA_GUI2_Body_CharListHeader.headerLineItems = {}    
    --NAME ENTRY
    local entry = "Name"
    local line = parent:GetNamedChild('_SortHdrBtn_Name' )
    if(line==nil)then
      line = WINDOW_MANAGER:CreateControlFromVirtual("ESOA_GUI2_Body_CharListHeader_SortHdrBtn_Name", parent, "ESOA_SortBar_SortButton")
    end
    line:SetText( ElderScrollsOfAlts.GuiSortBarLookupDisplayText(entry) )--TODO get function to get display name
    line:SetHidden(false)
    line:SetDimensions(ElderScrollsOfAlts.GuiSortBarLookupDisplayWidth(entry,customWidths),ElderScrollsOfAlts.defaultFieldHeight)
    --line:SetAnchor(TOPLEFT, predecessor, TOPRIGHT, 0, 0)
    if(predecessor==nil)then
      line:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)    
    else
      line:SetAnchor(TOPLEFT, predecessor, TOPRIGHT, 0, 0)    
    end
    line.entry = entry
    --TODO Perhaps a lookup for search params too/ = smithing->blacksmithing
    line.sortKey = ElderScrollsOfAlts.GuiSortBarLookupSortText(entry)
    line:SetHandler('OnMouseUp',function(self)
        ElderScrollsOfAlts:DoGuiSort(self,true,self.sortKey)
        ElderScrollsOfAlts.RefreshViewableTable()
    end)
    --line:SetHandler('OnClicked',function(self)
      --PlaySound(SOUNDS.POSITIVE_CLICK)        
      --ElderScrollsOfAlts:DoGuiSort(self, self.entry )
    --end)
    predecessor = line
    --    
    ESOA_GUI2_Body_CharListHeader.headerLineItems = {}
    local viewData = viewTemplateC.view
    for i = 1, #viewData do
      entry = viewData[i]    
      --ElderScrollsOfAlts.debugMsg("GUIShowViewHome:"," entry='", tostring(entry), "'")
      line = parent:GetNamedChild('_SortHdrBtn_'..i )
      if(line==nil)then
        line = WINDOW_MANAGER:CreateControlFromVirtual("ESOA_GUI2_Body_CharListHeader_SortHdrBtn_"..i, parent, "ESOA_SortBar_SortButton")
      end
      if(line==nil) then
        ElderScrollsOfAlts.outputMsg("Ack! Virtual control is nil?")
        --return
      else
        line:SetText( ElderScrollsOfAlts.GuiSortBarLookupDisplayText(entry) )--TODO get function to get display name
        line:SetHidden(false)
        line:SetDimensions(ElderScrollsOfAlts.GuiSortBarLookupDisplayWidth(entry,customWidths),ElderScrollsOfAlts.defaultFieldHeight)
        line:SetAnchor(TOPLEFT, predecessor, TOPRIGHT, 0, 0)
        --line:SetHandler('OnClicked',function(self)
          --PlaySound(SOUNDS.POSITIVE_CLICK)        
          --ElderScrollsOfAlts:DoGuiSort(self, self.entry )
        --end)
        line:SetHandler('OnMouseUp',function(self)
          ElderScrollsOfAlts:DoGuiSort(self,true,self.sortKey)
          ElderScrollsOfAlts.RefreshViewableTable()
        end)
        line.entry = entry
        line.sortKey = ElderScrollsOfAlts.GuiSortBarLookupSortText(entry)
        ElderScrollsOfAlts.debugMsg("SetupGuiHeaderListing: set entry='",entry,"' sortKey='",line.sortKey,"'")
        ElderScrollsOfAlts.debugMsg("SetupGuiHeaderListing: Showed item=",entry)
        --TODO Perhaps a lookup for search params too/ = mithing->blacksmithing
        table.insert(ESOA_GUI2_Body_CharListHeader.headerLineItems, line)
        predecessor = line
      end
    end
  end
end
  
--REMOVE?
--Called from : ElderScrollsOfAlts:DoGuiSort(control,newSort,sortText)
function ElderScrollsOfAlts:RefreshGuiCharListing(viewName)
end

------------------------------
-- SORT: 
function ElderScrollsOfAlts:DoGuiSort(control,newSort,sortText)
  ElderScrollsOfAlts.debugMsg("DoGuiSort: called w/sortText='", tostring(sortText), "'")
  if(ElderScrollsOfAlts.savedVariables.currentsort==nil)then
    ElderScrollsOfAlts.savedVariables.currentsort = {}
  end
  ElderScrollsOfAlts.debugMsg("DoGuiSort: called w/currentView='", tostring(ElderScrollsOfAlts.savedVariables.currentView), "'")
  if(sortText~=nil) then
    ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["sorttext"] = (sortText)
  elseif( ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView] ~= nil ) then
    sortText = ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["sorttext"]
  end
  
  --
  local sortKey = ElderScrollsOfAlts.GuiSortBarLookupSortText(sortText)
  ElderScrollsOfAlts.debugMsg("DoGuiSort: sortKey='", tostring(sortKey), "'")
  if(ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]==nil)then
    ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView] = {}
    ElderScrollsOfAlts.debugMsg("DoGuiSort: created struct for view=",ElderScrollsOfAlts.savedVariables.currentView)
  end
  
  --
  if(sortText~=nil and string.len(sortText) > 0 )then
    ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"] = (sortKey)
    ElderScrollsOfAlts.debugMsg("DoGuiSort: set per sortText/sortKey")
  end
  if(newSort~=nil and newSort) then
    ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["order"] = not ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["order"]
  end
  ElderScrollsOfAlts.debugMsg("DoGuiSort: current view=",ElderScrollsOfAlts.savedVariables.currentView )
  --ElderScrollsOfAlts.debugMsg("DoGuiSort: current key =", ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"] )
  if(ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"]==nil or string.len(ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"]) < 1 ) then
    ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"] = "name"
    ElderScrollsOfAlts.debugMsg("DoGuiSort: set key to default name")
  end
  
  --Easy vars
  local currentSortKey   = ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["key"]
  local currentSortOrder = ElderScrollsOfAlts.savedVariables.currentsort[ElderScrollsOfAlts.savedVariables.currentView]["order"]
  if(currentSortKey==nil or currentSortKey=="") then
    currentSortKey = "name"
    ElderScrollsOfAlts.outputMsg("Reset sort order to Name")
  end
  
  ElderScrollsOfAlts.view.currentSortKey   = currentSortKey
  ElderScrollsOfAlts.view.currentSortOrder = currentSortOrder
  ElderScrollsOfAlts.savedVariables.currentSortKey   = nil
  ElderScrollsOfAlts.savedVariables.currentSortOrder = nil
  ElderScrollsOfAlts.debugMsg("DoGuiSort: called w/currentSortKey='", ElderScrollsOfAlts.view.currentSortKey,"' currentSortOrder='", ElderScrollsOfAlts.view.currentSortOrder,"'")

  --setup function
  --1 normal
  --2 use Rank
  --3 use underscore replace spaces
  local gSearch = nil
  local gSearch1 = function (a,b)
    local aVal = a.playerLine[ElderScrollsOfAlts.view.currentSortKey]
    local bVal = b.playerLine[ElderScrollsOfAlts.view.currentSortKey]
    ElderScrollsOfAlts.debugMsg("ESOA: 1) aVal="..tostring(aVal).." bVal="..tostring(bVal), " aname:'", a.playerLine.name, "' bname:'",b.playerLine.name, "'")
    local value1Type = type(aVal)
    local value2Type = type(bVal)
    ElderScrollsOfAlts.debugMsg("ESOA: 1) value1Type="..tostring(value1Type).." value2Type="..tostring(value2Type) )
    if(aVal == nil) then 
        if(value1Type=="string") then
          aVal = "nil"
        else
          aVal = 0
        end
    end
    if(bVal == nil) then 
        if(value1Type=="string") then
          bVal = "nil"
        else
          bVal = 0
        end
    end
    ElderScrollsOfAlts.debugMsg("ESOA: 2) aVal="..tostring(aVal).." bVal="..tostring(bVal), " aname:'", a.playerLine.name, "' bname:'",b.playerLine.name, "'")
    --debugMsg("ESOA: a.name="..a.name.." b.name="..b.name)
    if(currentSortOrder) then
      return bVal > aVal or bVal == aVal and b.playerLine.name < a.playerLine.name
    else
      return aVal > bVal or aVal == bVal and a.playerLine.name < b.playerLine.name
    end
  end
  local gSearch2 = function (a,b)
    local skey = ElderScrollsOfAlts.view.currentSortKey.."_Rank"
    local aVal = a.playerLine[skey]
    local bVal = b.playerLine[skey]
    local value1Type = type(aVal)
    if(bVal == nil) then 
        if(value1Type=="string") then bVal = "nil"  end
    end
    --if(aVal == nil) then aVal = "nil" end
    --if(bVal == nil) then bVal = "nil" end    
    if(ElderScrollsOfAlts.view.currentSortOrder) then
      return bVal > aVal or bVal == aVal and b.playerLine.name < a.playerLine.name
    else
      return aVal > bVal or aVal == bVal and a.playerLine.name < b.playerLine.name
    end
  end
  local gSearch2b = function (a,b)
    local skey = ElderScrollsOfAlts.view.currentSortKey.."_rank"
    local aVal = a.playerLine[skey]
    local bVal = b.playerLine[skey]
    local value1Type = type(aVal)
    if(bVal == nil) then 
        if(value1Type=="string") then bVal = "nil"  end
    end
    --if(aVal == nil) then aVal = "nil" end
    --if(bVal == nil) then bVal = "nil" end    
    if(ElderScrollsOfAlts.view.currentSortOrder) then
      return bVal > aVal or bVal == aVal and b.playerLine.name < a.playerLine.name
    else
      return aVal > bVal or aVal == bVal and a.playerLine.name < b.playerLine.name
    end
  end
  local gSearch3 = function (a,b)
    local skey = ElderScrollsOfAlts.view.currentSortKey:gsub(" ","_")
    local aVal = a.playerLine[skey]
    local bVal = b.playerLine[skey]
    if(aVal == nil) then aVal = "nil" end
    if(bVal == nil) then bVal = "nil" end
    if(ElderScrollsOfAlts.view.currentSortOrder) then
      return bVal > aVal or bVal == aVal and b.playerLine.name < a.playerLine.name
    else
      return aVal > bVal or aVal == bVal and a.playerLine.name < b.playerLine.name
    end
  end
  
  --
  gSearch =  gSearch1
  ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch set to #1")
  if(ESOA_GUI2_Body_ListHolder.dataLines[1]==nil) then
    gSearch = nil
    ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch set to #0")
  else
    --[[
    setmetatable(t,{
      __index = function(t,k) return 0 end
    })
    --]]
    
    local testEntry1 = ESOA_GUI2_Body_ListHolder.dataLines[1].playerLine
	if(testEntry1~=nil) then
		ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch testEntry1 a='",testEntry1[ElderScrollsOfAlts.view.currentSortKey],"'")
		ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch testEntry1 b='",testEntry1[ElderScrollsOfAlts.view.currentSortKey.."_Rank"],"'")
		ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch testEntry1 c='",testEntry1[ElderScrollsOfAlts.view.currentSortKey.."_rank"],"'")
	end
    if(testEntry1==nil) then
      gSearch = nil
      ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch set to #0")
    elseif( testEntry1[ElderScrollsOfAlts.view.currentSortKey.."_Rank"] ~= nil ) then
      gSearch = gSearch2
      ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch set to #2")
    elseif( testEntry1[ElderScrollsOfAlts.view.currentSortKey.."_rank"] ~= nil ) then
      gSearch = gSearch2b
      ElderScrollsOfAlts.debugMsg("DoGuiSort: gSearch set to #2b")
    --elseif( testEntry1[ ElderScrollsOfAlts.view.currentSortKey:gsub(" ","_") ] ~=nil ) then
    --  gSearch = gSearch3
    end
  end
  
  --local sortedData = 
  table.sort( ESOA_GUI2_Body_ListHolder.dataLines, gSearch )
 
  ElderScrollsOfAlts.debugMsg("DoGuiSort: Table sorted, refresh...")
   
  if(newSort~=nil and newSort) then
    ElderScrollsOfAlts:RefreshGuiCharListing(ElderScrollsOfAlts.savedVariables.currentView)  
  end
  ElderScrollsOfAlts:GuiSetupCategoryButton(self)  
  
  --Sort Label
  local sVal = zo_strformat("<<C:1>>", ElderScrollsOfAlts.view.currentSortKey )
  ESOA_GUI2_Header_SortBy_Value:SetText( sVal )
  
  -- Sort Arrows
  if( not ElderScrollsOfAlts.view.currentSortOrder ) then
    ESOA_GUI2_Header_SortUp:SetHidden(false)
    ESOA_GUI2_Header_SortDown:SetHidden(true)
  else
    ESOA_GUI2_Header_SortUp:SetHidden(true)
    ESOA_GUI2_Header_SortDown:SetHidden(false)
  end
  
	--ESOA_GUI2_Body_ListHolder.dataOffset = 0
end--DOGUISORT

------------------------------
-- SORT: Set max, and Hide lines out of the max display
function ElderScrollsOfAlts:GuiResizeScroll()
	ElderScrollsOfAlts.debugMsg("GuiResizeScroll: Called")
	local regionHeight = ESOA_GUI2_Body_ListHolder:GetHeight()
	local rowHeight    = ESOA_GUI2_Body_ListHolder.rowHeight
	
	if(ESOA_GUI2_Body_ListHolder.dataLines[1]~=nil) then
		--local oldRowHeight = ESOA_GUI2_Body_ListHolder.rowHeight
		ESOA_GUI2_Body_ListHolder.rowHeight = ESOA_GUI2_Body_ListHolder.dataLines[1]:GetHeight(); --+ ElderScrollsOfAlts.altData.fieldYOffset
		rowHeight = ESOA_GUI2_Body_ListHolder.rowHeight
		--ElderScrollsOfAlts.debugMsg("(A)Reset lineH rowHeight from " .. tostring(oldRowHeight) .. " to ".. tostring( ESOA_GUI2_Body_ListHolder.rowHeight) )
	end
	if (ESOA_View_Template~=nil) then
		rowHeight = ESOA_View_Template:GetHeight()
	end
	local newLines = math.floor(regionHeight / rowHeight)
	ElderScrollsOfAlts.debugMsg("GuiResizeScroll: newLines=", tostring(newLines), " maxLines=",tostring(ESOA_GUI2_Body_ListHolder.maxLines) )
	if ESOA_GUI2_Body_ListHolder.maxLines == nil or ESOA_GUI2_Body_ListHolder.maxLines ~= newLines then
		ESOA_GUI2_Body_ListHolder.maxLines = newLines
	end    
	--Hide lines out of the max display
	ElderScrollsOfAlts:GuiResizeLines()
	--end
	ElderScrollsOfAlts.debugMsg("GuiResizeScroll: Done")
end

------------------------------
-- SORT: Hide lines out of the max display
function ElderScrollsOfAlts:GuiResizeLines()
  ElderScrollsOfAlts.debugMsg("GuiResizeLines: Called")
	--local lines
	if not ESOA_GUI2_Body_ListHolder.displayedLines then
    return
		--TODOlines = ElderScrollsOfAlts:CreateInventoryScroll()
	end
	--if ESOA_GUI2_Body_ListHolder.displayedLines ~= {} then
	--	lines = ESOA_GUI2_Body_ListHolder.lines
	--end

	for index, line in ipairs(ESOA_GUI2_Body_ListHolder.displayedLines) do
--		line.text:SetWidth(textwidth)
--		line:SetWidth(linewidth)
		line:SetHidden(index > ESOA_GUI2_Body_ListHolder.maxLines)
		ElderScrollsOfAlts.debugMsg("Hidden line index="..tostring(index > ESOA_GUI2_Body_ListHolder.maxLines))
	end
end

------------------------------
-- SORT: 
function ElderScrollsOfAlts:GuiOnScroll(control, delta)  
	if not delta then return end
	ElderScrollsOfAlts.debugMsg("GuiOnScroll: delta="..tostring(delta) )
	if delta == 0 then return end
	
	local slider = ESOA_GUI2_Body_ListHolder_Slider
	local sValue = slider:GetValue()
	ElderScrollsOfAlts.debugMsg("GuiOnScroll: delta="..tostring(delta) .. " sValue: " .. tostring(sValue)  )
	ElderScrollsOfAlts.debugMsg("GuiOnScroll: maxChars: " .. tostring(ElderScrollsOfAlts.view.playerLineCount) )
	
	local value  = (ESOA_GUI2_Body_ListHolder.dataOffset - delta)
	local total  = #ESOA_GUI2_Body_ListHolder.displayedLines - ESOA_GUI2_Body_ListHolder.maxLines
	--local total  = #ESOA_GUI2_Body_ListHolder.displayedLines - ElderScrollsOfAlts.view.playerLineCount
	ElderScrollsOfAlts.debugMsg("GuiOnScroll:  value="..tostring(value) .. " = dataOffset="..tostring(ESOA_GUI2_Body_ListHolder.dataOffset) .. " - delta=".. tostring(delta) )
	ElderScrollsOfAlts.debugMsg("GuiOnScroll:  total="..tostring(total) .." displayedLines=" .. tostring(#ESOA_GUI2_Body_ListHolder.displayedLines) .. " - maxLines=".. tostring(ESOA_GUI2_Body_ListHolder.maxLines) )
			
	local total2 = ESOA_GUI2_Body_ListHolder.maxLines + value
	ElderScrollsOfAlts.debugMsg("GuiOnScroll:  total2="..tostring(total2) )
	if(total2 > (#ESOA_GUI2_Body_ListHolder.displayedLines+value) ) then
		value = total2-ESOA_GUI2_Body_ListHolder.maxLines
		ElderScrollsOfAlts.debugMsg("GuiOnScroll: value=(B)" .. tostring(value) )
	end	
	if(total2 > ElderScrollsOfAlts.view.playerLineCount ) then
		value = value-1
		ElderScrollsOfAlts.debugMsg("GuiOnScroll: value=(C)" .. tostring(value) )
	end
	if value < 0 then 
		value = 0 
		ElderScrollsOfAlts.debugMsg("GuiOnScroll: value=0" )
	end
	if value > (total+2) then
		--value = total+2
		--ElderScrollsOfAlts.outputMsg("GuiOnScroll: value=(total+2)" .. tostring(value) )
	end
	--if value > sValue then value = sValue end
	ElderScrollsOfAlts.debugMsg("GuiOnScroll: value(fin)="..tostring(value) )
	ESOA_GUI2_Body_ListHolder.dataOffset = value
	ElderScrollsOfAlts.debugMsg("GuiOnScroll: set dataOffset="..tostring(value) )

	----Setup max lines, and slider (calls RefreshViewableTable: create show lines based on offset)
	ElderScrollsOfAlts:UpdateDataScroll()

	--Set max, and Hide lines out of the max display
	ElderScrollsOfAlts:GuiResizeScroll()

	slider:SetValue(ESOA_GUI2_Body_ListHolder.dataOffset)
	
	local hControl = ESOA_GUI2_Body_ListHolder.mouseHighlight.highlightedcontrol
	if( hControl and hControl:IsHidden() ) then
		ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(true)
	else
		ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(false)
	end
	--ElderScrollsOfAlts:GuiLineOnMouseEnter(moc())
end

------------------------------
-- SORT: 
function ElderScrollsOfAlts:GuiOnSliderUpdate(slider, value)
	ElderScrollsOfAlts.debugMsg("GuiOnSliderUpdate: Called, w/value="..tostring(value)  )
	--if not value or slider.locked then return end
	local relativeValue = math.floor(ESOA_GUI2_Body_ListHolder.dataOffset - value)
	ElderScrollsOfAlts.debugMsg("GuiOnSliderUpdate: relativeValue=" ..tostring(relativeValue) .. " value="..tostring(value) .. " offset="..tostring(ESOA_GUI2_Body_ListHolder.dataOffset)  )
	ElderScrollsOfAlts:GuiOnScroll(slider, relativeValue)
end

------------------------------
-- SORT: Setup max lines, and slider (calls RefreshViewableTable: create show lines based on offset)
function ElderScrollsOfAlts:UpdateDataScroll()
  local index = 0
	if ESOA_GUI2_Body_ListHolder.dataOffset < 0 then ESOA_GUI2_Body_ListHolder.dataOffset = 0 end
	if ESOA_GUI2_Body_ListHolder.maxLines == nil then
		ESOA_GUI2_Body_ListHolder.maxLines = ESOA_GUI2_Body_ListHolder.defaultMaxLines
	end
	--TODO SetDataLinesData()--Fill in data from datalines
	ElderScrollsOfAlts.RefreshViewableTable()

	local total = #ESOA_GUI2_Body_ListHolder.dataLines - ESOA_GUI2_Body_ListHolder.maxLines
	ElderScrollsOfAlts.debugMsg("ShowSetView: #dataLines=", tostring(#ESOA_GUI2_Body_ListHolder.dataLines), " maxLines=",tostring(ESOA_GUI2_Body_ListHolder.maxLines) )
	ElderScrollsOfAlts.debugMsg("ShowSetView: total=",total)
	ESOA_GUI2_Body_ListHolder_Slider:SetMinMax(0, total)
  
end

------------------------------
-- UI: ESOA_GUI2
function ElderScrollsOfAlts:onMoveStop()  
  ElderScrollsOfAlts.savedVariables.window.top    = ESOA_GUI2:GetTop()
  ElderScrollsOfAlts.savedVariables.window.left   = ESOA_GUI2:GetLeft()
  ElderScrollsOfAlts.debugMsg("Saved Moved top and left")
  if not ElderScrollsOfAlts.savedVariables.window.minimized and not ElderScrollsOfAlts.savedVariables.window.justone then
    ElderScrollsOfAlts.savedVariables.window.width  = ESOA_GUI2:GetWidth()
    ElderScrollsOfAlts.savedVariables.window.height = ESOA_GUI2:GetHeight()  
    ElderScrollsOfAlts.debugMsg("Saved Moved width and height")
  end
end

------------------------------
-- UI: ESOA_GUI2 (calls GuiResizeScroll and UpdateDataScroll)
function ElderScrollsOfAlts:onResizeStart() 
  	EVENT_MANAGER:RegisterForUpdate(ElderScrollsOfAlts.name.."OnWindowResize", 50,
      function() 
        --Setup max lines, and slider (calls RefreshViewableTable)
        ElderScrollsOfAlts:UpdateDataScroll()
        --Set max, and Hide lines out of the max display
        ElderScrollsOfAlts:GuiResizeScroll() 
      end
    )
end

------------------------------
-- UI: ESOA_GUI2
function ElderScrollsOfAlts:onResizeStop()
  
	-- if you resize the box, you need to resize the list to go with it
	-- local sceneName = :GetCurrentSceneName()
	EVENT_MANAGER:UnregisterForUpdate(ElderScrollsOfAlts.name.."OnWindowResize")
  --debugMsg("Resize start")
  --TODO ElderScrollsOfAlts:GuiResizeScroll()
  --TODO ElderScrollsOfAlts:UpdateDataScroll()
  if not ElderScrollsOfAlts.savedVariables.window.minimized and not ElderScrollsOfAlts.savedVariables.window.justone then
    ElderScrollsOfAlts.savedVariables.window.top    = ESOA_GUI2:GetTop()
    ElderScrollsOfAlts.savedVariables.window.left   = ESOA_GUI2:GetLeft()
    ElderScrollsOfAlts.savedVariables.window.width  = ESOA_GUI2:GetWidth()
    ElderScrollsOfAlts.savedVariables.window.height = ESOA_GUI2:GetHeight()
    ElderScrollsOfAlts.debugMsg("Saved resized width and height, top and left")
    --
    --TODO
    --update scroll height/width (has to be done manually?)
    --ESOA_GUI2_Body
    --<Anchor point="TOPLEFT"     relativeTo="$(parent)_Header" relativePoint="BOTTOMLEFT" />
    --<Anchor point="BOTTOMRIGHT" relativeTo="$(parent)" relativePoint="BOTTOMRIGHT" />
    --TODO ESOA_GUI2_Body:ClearAnchors()
    --ESOA_GUI2_Body:SetAnchor(TOPLEFT, "ESOA_GUI2_Header", TOPLEFT, 
    --  ElderScrollsOfAlts.savedVariables.window.left, ElderScrollsOfAlts.savedVariables.window.top)
    --TODO ESOA_GUI2_Body:SetAnchor(BOTTOMRIGHT, "ESOA_GUI2", BOTTOMRIGHT)    
    --ESOA_GUI2_Body_ListHolder
    
    --ESOA_GUI2_Body:SetAnchor(BOTTOMRIGHT, "$(parent)", BOTTOMRIGHT)    
    --ESOA_GUI2_Body_ListHolder:SetAnchor(BOTTOMRIGHT, "$(parent)", 0,200 )    
    
    ESOA_GUI2_Header:SetWidth( ESOA_GUI2:GetWidth() )
    --??ESOA_GUI2_Body_ListHolder:SetWidth( ESOA_GUI2:GetWidth() )   
    
    --ZO_ScrollList_SetHeight(ESOA_GUI2_Body_CharList, ESOA_GUI2_Body:GetHeight())
    --ZO_ScrollList_UpdateScroll(ESOA_GUI2_Body_CharList)
    --ZO_ScrollList_Commit(ESOA_GUI2_Body_CharList)  
    
    --Setup max lines, and slider (calls RefreshViewableTable)
    ElderScrollsOfAlts:UpdateDataScroll()
    --Set max, and Hide lines out of the max display
    ElderScrollsOfAlts:GuiResizeScroll()
    --Show Viewable
    ElderScrollsOfAlts.RefreshViewableTable()    
    --debugMsg("Resize done")
  end
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:ToggleGuiCharacterDetails(self)
  ElderScrollsOfAlts.debugMsg("ToggleGuiCharacterDetails:"," Called")
  if(ESOA_CharDetails:IsHidden())then
    ElderScrollsOfAlts:CloseGuiCharacterDetails(self)    
  else
    ElderScrollsOfAlts:ShowGuiCharacterDetails(self)
  end
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:CloseGuiCharacterDetails(self)
  ESOA_CharDetails:SetHidden(true)
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:ShowGuiCharacterDetails(self)
  ElderScrollsOfAlts.debugMsg("ShowGuiCharacterDetails:"," Called") 
   ESOA_CharDetails:SetHidden(false)
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:GUI2Lock(bLock)
  --debugMsg("GUI2Lock bLock: "..tostring(bLock) )
	ESOA_GUI2_Header_Locked:SetHidden(not bLock)
	ESOA_GUI2_Header_Unlocked:SetHidden(bLock)
	ESOA_GUI2:SetMovable(not bLock)

	if bLock then
		ESOA_GUI2:SetResizeHandleSize(0)
	else
		ESOA_GUI2:SetResizeHandleSize(10)
	end
end

------------------------------
-- UI: ESOA_GUI2 called from _Hide ??? TODO
function ElderScrollsOfAlts.HideGui2()
    ESOA_GUI2:SetHidden(true)
    ESOA_GUI2_Notes:SetHidden(true)
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:GUI2Minimize(bMin)
  ElderScrollsOfAlts.debugMsg("GUI2Minimize Called, bMin=",tostring(bMin) )
  ElderScrollsOfAlts.savedVariables.window.minimized = bMin
--[[  
  if ElderScrollsOfAlts.savedVariables.window.minlevel == nil then
    ElderScrollsOfAlts.savedVariables.window.minlevel = 0
  end
  if bMin then
    ElderScrollsOfAlts.savedVariables.window.minlevel = ElderScrollsOfAlts.savedVariables.window.minlevel + 1
  else
    ElderScrollsOfAlts.savedVariables.window.minlevel = ElderScrollsOfAlts.savedVariables.window.minlevel - 1
  end
  --d("MinLevel=" .. tostring(ElderScrollsOfAlts.savedVariables.window.minlevel) )
  
  if ElderScrollsOfAlts.savedVariables.window.minlevel == nil or ElderScrollsOfAlts.savedVariables.window.minlevel == 0 then
    --
  else
    --
  end 
--]]
  --Header
  ESOA_GUI2_Header_Minimize:SetHidden(bMin)
  ESOA_GUI2_Header_Maximize:SetHidden(not bMin)  
  --Body  
  ESOA_GUI2_Body_CharListHeader:SetHidden(bMin)
  ESOA_GUI2_Body_Divider:SetHidden(bMin)
  ESOA_GUI2_Body_ListHolder:SetHidden(bMin)
--[[
  --Sizing
  if bMin then
    --ElderScrollsOfAlts.savedVariables.window.restoreheight = ESOA_GUI2:GetHeight()
    ESOA_GUI2:SetHeight(20)
    --ElderScrollsOfAlts:HideGuiByChoice()
    --Hdr
    ESOA_GUI2_Body_CharListHeader:SetHidden(bMin)
    ESOA_GUI2_Body_EquipListHeader:SetHidden(bMin)
    ESOA_GUI2_Body_ResearchListHeader:SetHidden(bMin)
    ESOA_GUI2_Body_Misc2ListHeader:SetHidden(bMin)
    --Body  
    ESOA_GUI2_Body_CharList:SetHidden(bMin)
    ESOA_GUI2_Body_List_EQUIP:SetHidden(bMin)
    ESOA_GUI2_Body_List_Research:SetHidden(bMin)
    ESOA_GUI2_Body_List_Misc2:SetHidden(bMin)
  else
    ElderScrollsOfAlts.loadPlayerData() -- read data from game into addon
    ElderScrollsOfAlts:SetupGui2(self)  -- Setup Display of addon data   
    ElderScrollsOfAlts:Gui2SortRefresh()

    if(ElderScrollsOfAlts.savedVariables.currentView == "Research") then     
      ESOA_GUI2_Body_ResearchListHeader:SetHidden(bMin)
      ESOA_GUI2_Body_List_Research:SetHidden(bMin)
    elseif(ElderScrollsOfAlts.savedVariables.currentView == "Equip") then     
      ESOA_GUI2_Body_EquipListHeader:SetHidden(bMin)
      ESOA_GUI2_Body_List_EQUIP:SetHidden(bMin)
    elseif(ElderScrollsOfAlts.savedVariables.currentView == "Other1") then     
      ESOA_GUI2_Body_Misc2ListHeader:SetHidden(bMin)
      ESOA_GUI2_Body_List_Misc2:SetHidden(bMin)
    else
      ESOA_GUI2_Body_CharListHeader:SetHidden(bMin)
      ESOA_GUI2_Body_CharList:SetHidden(bMin)
    end
  
    --local rHt = ElderScrollsOfAlts.savedVariables.window.restoreheight
    --if rHt == nil then
    --  rHt = ElderScrollsOfAlts.savedVariables.window.height
    --end    
    ESOA_GUI2:SetHeight(ElderScrollsOfAlts.savedVariables.window.height)
    --ElderScrollsOfAlts:ShowGuiByChoice()
  end  
--]]
end


--Sort
local categorySortKeys =
  {
    ["MAIN"]          = { },
  }

------------------------------
-- UI: Sort
function ElderScrollsOfAlts.SortCategoriesData(a, b)
  return ZO_TableOrderingFunction( a.data, b.data, "MAIN", categorySortKeys, ZO_SORT_ORDER_DOWN )
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:ListOfCategories(forDisplayOnly)
	ElderScrollsOfAlts.debugMsg("ListOfCategories: Called" )
	local validChoices =  {}
	if(forDisplayOnly~=nil and forDisplayOnly==true)then
		table.insert(validChoices, ElderScrollsOfAlts.CATEGORY_ALL )
	end
	if(forDisplayOnly~=nil) then
		table.insert(validChoices, ElderScrollsOfAlts.CATEGORY_EU  )
		table.insert(validChoices, ElderScrollsOfAlts.CATEGORY_US  )
	end
	--
	local tCount = 0
	if(ElderScrollsOfAlts.altData.players~=nil) then
		for k, v in pairs(ElderScrollsOfAlts.altData.players) do
			if k ~= nil then
			  --debugMsg("List: players " .. k)
			  local catP = ElderScrollsOfAlts.altData.players[k].category
			  if ( catP~=nil and not ElderScrollsOfAlts:has_value(validChoices, catP) ) then 
				table.insert(validChoices, catP)
				ElderScrollsOfAlts.debugMsg("List: added cat=" .. catP)
				tCount = tCount+1
			  end
			end
		end
	end 
	if (ESOADatastore ~= nil ) then
		ElderScrollsOfAlts.debugMsg("Getting all chars for UI listing")
		local reval = EchoESOADatastore.getCharacterList()
		if(reval~=nil) then
			for index, tvalue in pairs(reval) do
				local customDataL = ESOADatastore.getCharcterCustomData(tvalue.id, "category")
				local catP = "A"
				if( customDataL ~= nil ) then
					catP = customDataL
					ElderScrollsOfAlts.debugMsg("ListCats: Cat From 'customDataL'=", catP )
				else
					ElderScrollsOfAlts.debugMsg("ListCats: Cat From DEFAULT")
					--ElderScrollsOfAlts:dumpPrintTable(tvalue)
				end	
				if ( not ElderScrollsOfAlts:has_value(validChoices, catP) ) then 
					table.insert(validChoices, catP)
					tCount = tCount+1
					ElderScrollsOfAlts.debugMsg("ListCats: add cat from, playerKey=" ,tostring(tvalue.playerKey), " catP=" , tostring(catP), " charkey=",tostring(tvalue.charKey) )
					--ElderScrollsOfAlts:dumpPrintTable(tvalue)
				end	
			end
		else
			EchoESOADatastore.outputMsg("No players listed in datastsore")
		end
	end
	--Default Values
	ElderScrollsOfAlts.debugMsg("List: tCount= " .. tCount)
	if(tCount==0)then
		table.insert(validChoices, "A")
		table.insert(validChoices, "B")
	end  
	--Sort
	--local validChoicesS = table.sort( validChoices,  ElderScrollsOfAlts.SortCategoriesData )  
	--Return
	return validChoices
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:GuiSetupCategoryButton(self)  
  local validChoices = ElderScrollsOfAlts:ListOfCategories(true)
  ESOA_GUI2_Header_CategorySelect:SetText( ElderScrollsOfAlts.CATEGORY_ALL )  
    --selected? --else all
  local categoryS = ElderScrollsOfAlts.savedVariables.selected.category
  if(categoryS==nil) then
    ElderScrollsOfAlts.savedVariables.selected.category = ElderScrollsOfAlts.CATEGORY_ALL
  end
  ESOA_GUI2_Header_CategorySelect:SetText(categoryS)  
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:SelectCategoryOnRotation(self) 
  local validChoices =  ElderScrollsOfAlts:ListOfCategories(true)
  local categoryS = ElderScrollsOfAlts.savedVariables.selected.category
  if(categoryS==nil)then
    categoryS = ElderScrollsOfAlts.CATEGORY_ALL
  end
  --ElderScrollsOfAlts.debugMsg
  ElderScrollsOfAlts.debugMsg("categoryS=",tostring(categoryS) )
  local foundC = false
  local nextC = false
  for i = 1, #validChoices do
		local entry = validChoices[i]
    ElderScrollsOfAlts.debugMsg("entry=",tostring(entry) )
    if(nextC)then
      ElderScrollsOfAlts.savedVariables.selected.category = entry
      ElderScrollsOfAlts.debugMsg("setting selected per nextC as ",entry )
      nextC = false
      break
    end
    if(entry==categoryS)then
      nextC  = true
      foundC = true
      ElderScrollsOfAlts.debugMsg("found categoryS")
    end
	end
  if(not foundC or nextC or categoryS==ElderScrollsOfAlts.savedVariables.selected.category) then
    ElderScrollsOfAlts.debugMsg("reset category to All")
    ElderScrollsOfAlts.savedVariables.selected.category = ElderScrollsOfAlts.CATEGORY_ALL
  end
  ElderScrollsOfAlts:GuiSetupCategoryButton(self)  
  ElderScrollsOfAlts:ShowSetView()
end

------------------------------
-- UI: TOOLTIPS: 
function ElderScrollsOfAlts:EquipShowTip(myLabel,equipName)
  local itemLink = myLabel.itemlink
  if(itemLink~=nil) then
    --debugMsg("EquipShowTip itemLink is set")
	--TODO can i add more info to this?
    ZO_PopupTooltip_SetLink(itemLink)
  else
    --debugMsg("EquipShowTip itemLink is nil")
  end
  --[[
  --Sends a link to chat
  --ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink)) 
  ]]
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:ShowHightlight(control, forced)
  ElderScrollsOfAlts.debugMsg("ShowHightlight: Called")
  --if(ESOA_GUI2_Body_ListHolder.mouseHighlight~=nil and ElderScrollsOfAlts.savedVariables.viewmousehighlight.shown == true ) then
  if(ESOA_GUI2_Body_ListHolder.mouseHighlight~=nil and (forced or ElderScrollsOfAlts.CtrlIsShowMouseHighlight()) ) then
    ElderScrollsOfAlts.debugMsg("ShowHightlight control=",tostring(control),   " offsest: ", tostring(ElderScrollsOfAlts.altData.fieldYOffset)  )
    ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0) 
    ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, ElderScrollsOfAlts.altData.fieldYOffset)
	--TODO changes if theline.setanchor does
	--
	ESOA_GUI2_Body_ListHolder.mouseHighlight.highlightedcontrol = control
	--
	if( control:IsHidden() ) then
		ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(true)
	else
		ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(false)
	end
  end  
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:GuiLineOnMouseEnter(control)
  if not control then return end
  --TODO Need to check if right kind of control?
  ElderScrollsOfAlts:ShowHightlight(control)
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:GuiLineOnMouseExit(self)
  --ClearTooltip(ESOATooltip)  
  --[[
  if(ESOA_GUI2_Body_ListHolder.mouseHighlight~=nil)then
    --d("GuiLineOnMouseExit")
    --ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0) 
    --ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0) 
    ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(true)
  end
  --]]--
end

------------------------------
-- UI: 
function ElderScrollsOfAlts:GUILineDoubleClick(button,buttonnum)
  --ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: Called")
  ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: Called"
    , " buttonnum:".. tostring(buttonnum)
    , " button:".. tostring(button)
    --, " line:".. tostring(line)
  )
  local charKey = button.charKey
  ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: charKey: " .. tostring(charKey) )
  
  if buttonnum == 1 then
	if button.itemLink~=nil and button.itemLink ~= "" then
      ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: show itemlink")
			ZO_ChatWindowTextEntryEditBox:SetText( ZO_ChatWindowTextEntryEditBox:GetText() .. zo_strformat(SI_TOOLTIP_ITEM_NAME, button.itemLink) )
    else
      local lineName = "ESOA_GUI2_Body_ListHolder_Line_" .. charKey  
      local line = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Line_'..charKey)
      ElderScrollsOfAlts:ShowHightlight(line)
      ElderScrollsOfAlts.debugMsg("Selected player to hightlight c")
	end
    --[[
    if(ESOA_GUI2_Body_ListHolder.mouseHighlight~=nil)then
      ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0) 
      ESOA_GUI2_Body_ListHolder.mouseHighlight:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0) 
      ESOA_GUI2_Body_ListHolder.mouseHighlight:SetHidden(false)
      --ElderScrollsOfAlts.debugMsg("Setting Mouse Hightlight Active")
    end--]]
    --TODO show select?
    if(ESOA_GUI2_Body_ListHolder.hightlightSelected ~=nil) then      
      --unselect ESOA_RowTemplate_Highlight
    end    
    --control:SetTexture(ESOA_RowTemplate_Highlight) TODO
    ESOA_GUI2_Body_ListHolder.selectedHighlight = button
  elseif buttonnum == 2 and button.charKey then
    ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: show rightclick")
    ElderScrollsOfAlts.savedVariables.selected.charactername = button.charKey
    ElderScrollsOfAlts.view.selectedPlayerRow = button
    ElderScrollsOfAlts:ShowCharacterNote(button)
  else
    ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: show else")
    local lineName = "ESOA_GUI2_Body_ListHolder_Line_" .. charKey  
    local line = ESOA_GUI2_Body_ListHolder:GetNamedChild('_Line_'..charKey)
    ElderScrollsOfAlts:ShowHightlight(line)
    ElderScrollsOfAlts.debugMsg("Selected player to hightlight c")
	end
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:ToolTipHeaderEnterSort(sender)
  local senderName = sender.entry 
  ElderScrollsOfAlts:Misc2HeaderTipEnter(sender,senderName)
end
------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:ToolTipHeaderExitSort(sender)
  ElderScrollsOfAlts:Misc2HeaderTipExit(sender)
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:Misc2HeaderTipEnter(sender,key)
  ElderScrollsOfAlts.debugMsg("Misc2HeaderTipEnter: sender='",sender,"'","key:'",key,"'")
  InitializeTooltip(ESOATooltip, sender, TOPLEFT, 5, -56, TOPRIGHT)
  ESOATooltip:AddLine(key, "ZoFontHeader3")
  --d("key="..tostring(key))
  local tt = sender[ string.lower(key).."_tooltip"]
  if(tt~=nil) then    
    ESOATooltip:AddLine(tt, "ZoFontGame")
  end
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:Misc2HeaderTipExit(sender)
  ClearTooltip(ESOATooltip)
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:ResearchTipEnter(myLabel,equipName)
  ElderScrollsOfAlts.debugMsg("ResearchTipEnter: equipName='",equipName,"' ","myLabel:'",myLabel,"'")
  local itemLink = myLabel.name
  --if( itemLink==nil and myLabel.tooltip==nil ) then
  --  return
  --end
  InitializeTooltip(InformationTooltip, myLabel, TOPLEFT, 5, -56, TOPRIGHT)
  if( itemLink==nil and myLabel.tooltip==nil ) then
    if( itemLink~=nil ) then
      InformationTooltip:AddLine(string.format("(%s)",itemLink), "ZoFontGame")
    end
  end
  ElderScrollsOfAlts.debugMsg("ResearchTipEnter: myLabel.traitType='",myLabel.traitType)
  ElderScrollsOfAlts.debugMsg("ResearchTipEnter: myLabel.tooltip='",myLabel.tooltip)
  if(myLabel.traitType~=nil) then
    InformationTooltip:AddLine(string.format("(%s)"     , myLabel.traitType), "ZoFontGame")
    InformationTooltip:AddLine(string.format("Trait: %s", myLabel.traitDesc), "ZoFontGame")
    --InformationTooltip:AddLine(string.format("(Known? %s)"     , tostring(myLabel.traitknown)), "ZoFontGame")
  elseif( myLabel.tooltip~=nil ) then
    InformationTooltip:AddLine(string.format("(%s)"     , myLabel.tooltip), "ZoFontGame")
  end
  --InformationTooltip:AddLine(string.format("(#Known: %s)"     , tostring(myLabel.NumTraitsKnown)), "ZoFontGame")
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:ResearchTipExit(myLabel)  
  ClearTooltip(InformationTooltip)
end

------------------------------
-- UI: TOOLTIPS ESOACraftTooltip EQUIP Tooltip TODO REMOVEME
function ElderScrollsOfAlts:EquipTipEnter(myLabel,equipName) 
  ElderScrollsOfAlts.debugMsg("EquipTipEnter: equipName='",equipName,"'","myLabel:'",myLabel,"'")
  local itemLink = myLabel.itemlink
  if(itemLink==nil) then
    return
  end
  --debugMsg("nVal=" .. tostring(nVal) .." equipName=" .. tostring(craftName))  
  local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
  local requiredLevel = GetItemLinkRequiredLevel(itemLink)
  local requiredCp    = GetItemLinkRequiredChampionPoints(itemLink)
  local hasCharges, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
  --hasAbility, abilityHeader, abilityDescription, cooldown, hasScaling, minLevel, maxLevel, isChampionPoints, remainingCooldown = GetItemLinkOnUseAbilityInfo(string itemLink)
  --hasAbility, abilityDescription, cooldown, hasScaling, minLevel, maxLevel, isChampionPoints  = GetItemLinkTraitOnUseAbilityInfo(string itemLink, number index)
  local hasSet, setName, numBonuses, numEquipped, maxEquipped, setId = GetItemLinkSetInfo(itemLink, true)
  --boolean hasSet, string setName, number numBonuses, number numEquipped, number maxEquipped, number setId  
  local flavorText  = GetItemLinkFlavorText(itemLink)

  InitializeTooltip(InformationTooltip, myLabel, TOPLEFT, 5, -56, TOPRIGHT)
  if( equipName ~= nil ) then
    InformationTooltip:AddLine(string.format("(%s)",equipName), "ZoFontGame")
  end
  --as equipName is the same in this context InformationTooltip:AddLine(itemLink, "ZoFontGame")
  if( traitType ~= nil) then
    local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
    InformationTooltip:AddLine(itemLink, "ZoFontGame")    
    if(requiredCp>0) then
      InformationTooltip:AddLine(string.format("Level: %s CP:%s",requiredLevel,requiredCp), "ZoFontGame")
    else
      InformationTooltip:AddLine(string.format("Requires: %s",requiredLevel,requiredCp), "ZoFontGame")
    end
    if(enchantHeader ~= nil and enchantDescription ~= nil) then
      InformationTooltip:AddLine(enchantHeader, "ZoFontGame")
      InformationTooltip:AddLine(enchantDescription, "ZoFontGameSmall")
    end
    InformationTooltip:AddLine(traitName, "ZoFontGame")
    InformationTooltip:AddLine(traitDescription, "ZoFontGame")
    InformationTooltip:AddLine(flavorText, "ZoFontGameSmall")
    if(hasSet) then
      InformationTooltip:AddLine(string.format("Part of the: %s set (%s/%s items)",setName,numEquipped,maxEquipped), "ZoFontGame")
    end    
  end
  --InformationTooltip:AddItemTags(itemLink)
end

------------------------------
-- UI: TOOLTIPS TODO REMOVEME
function ElderScrollsOfAlts:EquipTipExit(myLabel)  
  ClearTooltip(InformationTooltip)
end

------------------------------
-- UI: TOOLTIPS ESOACraftTooltip CRAFT Tooltip
function ElderScrollsOfAlts:CraftTipEnter(myLabel, craftName, playerLine)  
  ElderScrollsOfAlts.debugMsg("CraftTipEnter: myLabel='",myLabel," craftName='", tostring(craftName).."'")
  if( craftName == nil ) then 
    ElderScrollsOfAlts.debugMsg("CraftTipEnter: error, no craft name!")
    return 
  end 
  local nVal = tonumber(myLabel.data_sunk)
  if( nVal == nil ) then
    ElderScrollsOfAlts.debugMsg("CraftTipEnter: error, no sunk value for craftname ", craftName )
      return
  end 
  local nVal2 = nil  
  if( myLabel.data_sunk ~= nil ) then
    nVal2 = tonumber(myLabel.data_sunk2)
  end
  
  local tDesc = "Unknown"
  tDesc = ElderScrollsOfAlts:GetCraftSunkText(craftName, nVal)  
  if(tDesc == nil) then
   tDesc = "Unknown"  
  end
  
  local tDesc2 = nil
  local craftName2 = string.format("%s%s",craftName,"2")
  tDesc2 = ElderScrollsOfAlts:GetCraftSunkText(craftName2, nVal2)  
  if(tDesc2 == nil) then
   tDesc2 = "Unknown"  
  end
  --ElderScrollsOfAlts.debugMsg("tVal=" .. tostring(tVal) .." craftName=" .. tostring(craftName))  
  local hdrStr = string.format("%s (%s)", craftName, nVal)
  if( nVal2 ~= nil ) then
    hdrStr = string.format("%s (%s,%s)", craftName, nVal, nVal2)
  end
  
  InitializeTooltip(ESOATooltip, myLabel, TOPLEFT, 5, -66, TOPRIGHT)
  
    --Name? TODO
  if(playerLine~=nil)then
    ESOATooltip:AddLine(playerLine.name, "ZoFontGameLargeBold")
    --underscore??
  end

  ESOATooltip:AddLine(hdrStr, "ZoFontGameBold")
  ESOATooltip:AddLine(tDesc, "ZoFontGame")
  if( tDesc2 ~= nil ) then
    ESOATooltip:AddLine(tDesc2, "ZoFontGame")
  end    
  if( myLabel.data_subskills ~= nil ) then
    local sValSS = myLabel.data_subskills
    ESOATooltip:AddLine(string.char(10), "ZoFontGameSmall")
    ESOATooltip:AddLine(sValSS, "ZoFontGame")
  end

end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:CraftTipExit(myLabel)  
  ClearTooltip(ESOATooltip)
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:Misc2TipEnter(myLabel,equipName)
  ElderScrollsOfAlts.debugMsg("Misc2TipEnter: equipName='",equipName,"'","myLabel:'",myLabel,"'")
  local itemLink  = myLabel.name
  local hoverover = myLabel.hoverover 
  InitializeTooltip(InformationTooltip, myLabel, TOPLEFT, 5, -56, TOPRIGHT)  
  if(itemLink~=nil)then
    InformationTooltip:AddLine(string.format("(%s)",itemLink), "ZoFontGame")  
  end
  if(hoverover~=nil ) then
    InformationTooltip:AddLine(string.format("(%s)"     , myLabel.hoverover), "ZoFontGame")
    --InformationTooltip:AddLine(string.format("Trait: %s", myLabel.traitDesc), "ZoFontGame")
    --InformationTooltip:AddLine(string.format("(Known? %s)"     , tostring(myLabel.traitknown)), "ZoFontGame")
  end
  if(itemLink==nil and hoverover==nil ) then
    InformationTooltip:AddLine(string.format("(%s=%s)"   , equipName, myLabel:GetText() ), "ZoFontGame")
  end
  local tt = sender[ string.lower(equipName).."_tooltip"]
  if(tt~=nil) then    
    ESOATooltip:AddLine(tt, "ZoFontGame")
  end
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:Misc2TipExit(myLabel)  
  ClearTooltip(InformationTooltip)
end

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:TooltipEnter(mySelf,tooltipName,revdir)  
  ElderScrollsOfAlts.debugMsg("TooltipEnter: tooltipName='"..tostring(tooltipName).."'")
  if( tooltipName == nil ) then return end 
  local tooltipDesc  = nil
  local tooltipTitle = nil
  --
  if(mySelf.tooltipHdr~=nil)then
    tooltipTitle = mySelf.tooltipHdr
  end
  --  
  --if(tooltipName=="Alliance") then
  --  local nAliance = tonumber(mySelf.alliance)
  --  if( nAliance == nil ) then return end
  --  local aName = GetAllianceName(nAliance)
  --  tooltipDesc  = aName
    --tooltipTitle = ""
    --local hdrStr = string.format("%s (%s)", craftName, nVal)
  --[[elseif(tooltipName=="Special") then
    local nSpecial = tonumber(mySelf.special)
    --debugMsg("TooltipEnter: nSpecial='"..tostring(nSpecial).."'")
    if( nSpecial == nil or nSpecial == 0 ) then return end
    if( nSpecial == 1 ) then
      tooltipDesc  = "Werewolf"  
    elseif( nSpecial == 2 ) then
      tooltipDesc  = "Vampire"
    end--]]
  --
  --EQUIP
  if(mySelf.itemlink~=nil and mySelf.datatype == "Equip") then
    local itemLink = mySelf.itemlink
    --debugMsg("nVal=" .. tostring(nVal) .." equipName=" .. tostring(craftName))  
    local traitType, traitDescription = GetItemLinkTraitInfo(itemLink)
    local requiredLevel = GetItemLinkRequiredLevel(itemLink)
    local requiredCp    = GetItemLinkRequiredChampionPoints(itemLink)
    local hasCharges, enchantHeader, enchantDescription = GetItemLinkEnchantInfo(itemLink)
    --boolean hasSet, setName, number numBonuses, number numEquipped, number maxEquipped, number setId  
    local hasSet, setName, numBonuses, numEquipped, maxEquipped, setId = GetItemLinkSetInfo(itemLink, true)
    local flavorText  = GetItemLinkFlavorText(itemLink)
    InitializeTooltip(ESOATooltip, myLabel, TOPLEFT, 5, -56, TOPRIGHT)
    if( equipName ~= nil ) then
      ESOATooltip:AddLine(string.format("(%s)",equipName), "ZoFontGame")
    end
    --as equipName is the same in this context ESOATooltip:AddLine(itemLink, "ZoFontGame")
    if( traitType ~= nil) then
      local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
      ESOATooltip:AddLine(itemLink, "ZoFontGame")    
      if(requiredCp>0) then
        ESOATooltip:AddLine(string.format("Level: %s CP:%s",requiredLevel,requiredCp), "ZoFontGame")
      else
        ESOATooltip:AddLine(string.format("Requires: %s",requiredLevel,requiredCp), "ZoFontGame")
      end
      if(enchantHeader ~= nil and enchantDescription ~= nil) then
        ESOATooltip:AddLine(enchantHeader, "ZoFontGame")
        ESOATooltip:AddLine(enchantDescription, "ZoFontGameSmall")
      end
      ESOATooltip:AddLine(traitName, "ZoFontGame")
      ESOATooltip:AddLine(traitDescription, "ZoFontGame")
      ESOATooltip:AddLine(flavorText, "ZoFontGameSmall")
      if(hasSet) then
        ESOATooltip:AddLine(string.format("Part of the: %s set (%s/%s items)",setName,numEquipped,maxEquipped), "ZoFontGame")
      end    
    end
  --ESOATooltip:AddItemTags(itemLink)
  --EQUIP
  --
  else
    if(mySelf.tooltip~=nil)then
      tooltipDesc = mySelf.tooltip
    else
      --tooltipDesc = tooltipName
    end
  end
  
  --  
  --ElderScrollsOfAlts.debugMsg("TooltipEnter: tooltipDesc='"..tostring(tooltipDesc).."'"+" tooltipTitle='"..tostring(tooltipTitle).."')
  if( tooltipDesc ~= nil or tooltipTitle ~= nil) then
    if(revdir) then
      InitializeTooltip(ESOATooltip, mySelf, TOPRIGHT, 5, -76, TOPLEFT)
    else
      InitializeTooltip(ESOATooltip, mySelf, TOPLEFT, 5, -76, TOPRIGHT)
    end
    if tooltipTitle ~= nil then
      ESOATooltip:AddLine(tooltipTitle, "ZoFontGameBold")
    end
    if tooltipDesc ~= nil then
      ESOATooltip:AddLine(tooltipDesc, "ZoFontGame")
    end
  end
  --
  local ttkey = string.lower(tooltipName).."_tooltip"
  local ttval = mySelf[ ttkey ]
  --ElderScrollsOfAlts.debugMsg("TooltipEnter: ttkey='"..tostring(ttkey).."'")
  --ElderScrollsOfAlts.debugMsg("TooltipEnter: ttval='"..tostring(ttval).."'")
  if(ttval~=nil) then    
    --if( tooltipDesc == nil and tooltipTitle == nil) then
      InitializeTooltip(ESOATooltip, mySelf, TOPLEFT, 5, -76, TOPRIGHT)
    --end
    ESOATooltip:AddLine(ttval, "ZoFontGame")
  end
end--TooltipEnter

------------------------------
-- UI: TOOLTIPS
function ElderScrollsOfAlts:TooltipExit(myLabel,craftName)  
  ClearTooltip(ESOATooltip)
end

--------------
-- SORT
function ElderScrollsOfAlts:GuiSortChar(sender,keyname)
  --ElderScrollsOfAlts:GuiSortCharBase(keyname,false,sender)
end

--------------
-- SORT
function ElderScrollsOfAlts:GuiSort(keyname)
  --ElderScrollsOfAlts:GuiSortCharBase(keyname)
end

------------------------------
-- UI
function ElderScrollsOfAlts:RefreshTabs()
  --[[
  local myFpsLabelControl = WINDOW_MANAGER:GetControlByName("EchoExpDDExpOutput", "")
  if(myFpsLabelControl~=nil) then
    ElderScrollsOfAlts.UpdateUIExpTabs()
    ElderScrollsOfAlts.UpdateUILootTabs()
    ElderScrollsOfAlts.UpdateUIGuildTabs()
    ElderScrollsOfAlts.UpdateUIQuestTabs()
  else
    zo_callLater(ElderScrollsOfAlts.RefreshTabs, 12000)
  end 
  --]]
end


-- 
function ElderScrollsOfAlts:HideCPBar()
  --if( ElderScrollsOfAlts.view.cpbar1 ~= nil) then
  --  ElderScrollsOfAlts.view.cpbar1:SetHidden(true)
  --end
end

--
function ElderScrollsOfAlts:CreateObjectsCPBar()
  if( ElderScrollsOfAlts.view.cpbar1 == nil) then
    --d("setting up...")
    ElderScrollsOfAlts.view.cpbar1 = ESOA_ChampionAssignableActionBar
    ElderScrollsOfAlts.view.cpbar1.slots = {}
    ElderScrollsOfAlts.view.cpbar2 = ESOA_ChampionAssignableTextListBar
    ElderScrollsOfAlts.view.cpbar2.slots = {}
    ElderScrollsOfAlts.view.cpbar1:SetHidden(true)
    ElderScrollsOfAlts.view.cpbar2:SetHidden(true)
    ElderScrollsOfAlts.view.cpbar2.direction = true
    
    local fragment1 = ZO_HUDFadeSceneFragment:New(ElderScrollsOfAlts.view.cpbar1, nil, 0)
    ElderScrollsOfAlts.view.cpbarfragment1 = fragment1
    local fragment2 = ZO_HUDFadeSceneFragment:New(ElderScrollsOfAlts.view.cpbar2, nil, 0)
    ElderScrollsOfAlts.view.cpbarfragment2 = fragment2
    HUD_SCENE:AddFragment(ElderScrollsOfAlts.view.cpbarfragment1)
    HUD_UI_SCENE:AddFragment(ElderScrollsOfAlts.view.cpbarfragment1)
    HUD_SCENE:AddFragment(ElderScrollsOfAlts.view.cpbarfragment2)
    HUD_UI_SCENE:AddFragment(ElderScrollsOfAlts.view.cpbarfragment2)
    --
    local startSlotIndex, endSlotIndex = GetAssignableChampionBarStartAndEndSlots()
    local lastSlotControl, lastSlot, lastSlotControl2 = nil    
    for actionSlotIndex = startSlotIndex, endSlotIndex do  
      local slotControl1 = CreateControlFromVirtual("$(parent)Slot", ElderScrollsOfAlts.view.cpbar1, "ESOA_ChampionAssignableActionSlot", actionSlotIndex)
      slotControl1:SetHidden(true)
      ElderScrollsOfAlts.view.cpbar1.slots[actionSlotIndex] = slotControl1
      local backgroundTexture = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds"
      local icon = slotControl1:GetNamedChild("Icon")
      icon:SetTexture(backgroundTexture)
      --slotControl1:GetNamedChild("Star"):SetHidden(true)

      --2
      local slotControl2 = CreateControlFromVirtual("$(parent)Slot", ElderScrollsOfAlts.view.cpbar2, "ESOA_ChampionAssignableTextListBarSlot", actionSlotIndex)
      slotControl2:SetHidden(true)
      ElderScrollsOfAlts.view.cpbar2.slots[actionSlotIndex] = slotControl2
      local backgroundTexture2 = "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds"      
      local icon2 = slotControl2:GetNamedChild("Icon")
      icon2:SetTexture(backgroundTexture2)
      local icon2Rev = slotControl2:GetNamedChild("IconRev")
      icon2Rev:SetTexture(backgroundTexture2)

      --TODO GetRequiredChampionDisciplineIdForSlot
      if lastSlotControl then
          --[[if lastSlot:GetRequiredDisciplineId() ~= slot:GetRequiredDisciplineId() then
              slotControl:SetAnchor(LEFT, lastSlotControl, RIGHT, 58, 0)
              --self.firstSlotPerDiscipline[slot:GetRequiredDisciplineId()] = actionSlotIndex
          else
              slotControl:SetAnchor(LEFT, lastSlotControl, RIGHT, 13, 0)
          end--]]
          --fix temp
          slotControl1:SetAnchor(LEFT, lastSlotControl, RIGHT, -4, 0)
          slotControl2:SetAnchor(TOPLEFT, lastSlotControl2, BOTTOMLEFT, 0, 0)
      else
        slotControl1:SetAnchor(LEFT, ElderScrollsOfAlts.view.cpbar1, LEFT, 4, 2)
        --slotControl1:SetAnchor(LEFT, self.control, LEFT, 44, 0)
        --self.firstSlotPerDiscipline[slot:GetRequiredDisciplineId()] = actionSlotIndex
        slotControl2:SetAnchor(TOPLEFT, ElderScrollsOfAlts.view.cpbar2, TOPLEFT, 10, 10)
      end
      lastSlotControl  = slotControl1
      lastSlotControl2 = slotControl2
      --lastSlot = slot
    end--for
  end--if
  --d("ElderScrollsOfAlts:SetupCPBar().");
end

-- SLOTTED PASSIVE CP BAR
function ElderScrollsOfAlts:SetupCPBar()  --TODO Datastore
end

function ElderScrollsOfAlts:SetupCPBar2()  --TODO Datastore
  --d("ElderScrollsOfAlts:SetupCPBar()...");
  --SETUP
  if( ElderScrollsOfAlts.view.cpbar1 == nil) then
    ElderScrollsOfAlts:CreateObjectsCPBar()
  end
  
  -- POPULATE
  local pID       = GetCurrentCharacterId()
  local pServer   = GetWorldName()
  local playerKey =  zo_strformat("<<1>>_<<2>>", pID, pServer:gsub(" ","_") ) --pID.."_".. pServer:gsub(" ","_")
  local startSlotIndex, endSlotIndex = GetAssignableChampionBarStartAndEndSlots()
  if(ElderScrollsOfAlts.altData.players[playerKey].championpointsactive ~= nil) then
    for actionSlotIndex = startSlotIndex, endSlotIndex do  
      local slotControl = ElderScrollsOfAlts.view.cpbar1.slots[actionSlotIndex]
      slotControl.id   = nil
      slotControl.name = nil
      slotControl.numspentpoints = nil
      slotControl.val2 = nil
      local icon = slotControl:GetNamedChild("Icon")
      local lbl  = slotControl:GetNamedChild("Label")
      --local lblR = slotControl:GetNamedChild("LabelRev")
    
      local slotControl2 = ElderScrollsOfAlts.view.cpbar2.slots[actionSlotIndex]
      slotControl2.id   = nil
      slotControl2.name = nil
      slotControl2.numspentpoints = nil
      slotControl2.val2 = nil
      local icon2    = slotControl2:GetNamedChild("Icon")
      local icon2Rev = slotControl2:GetNamedChild("IconRev")
      local lbl2     = slotControl2:GetNamedChild("Label")
      local lbl2R    = slotControl2:GetNamedChild("LabelRev")

      local slotDisciplineId  = GetRequiredChampionDisciplineIdForSlot(actionSlotIndex, HOTBAR_CATEGORY_CHAMPION)
      --d("slotDisciplineId:" .. tostring(slotDisciplineId) )
      backgroundTexture = GetChampionDisciplineZoomedInBackground(slotDisciplineId)--changed in api35??
      icon.tooltip = "none"
      lbl:SetText( "" )
      --lblR:SetText( "" )
      
      backgroundTexture2 = GetChampionDisciplineZoomedInBackground(slotDisciplineId) --changed in api35??
      icon2.tooltip    = "none"
      icon2Rev.tooltip = "none"
      lbl2:SetText( "" )
      lbl2R:SetText( "" )

      local ca = ElderScrollsOfAlts.altData.players[playerKey].championpointsactive[actionSlotIndex]
      if(ca and ca.disciplineid) then
        backgroundTexture = GetChampionDisciplineZoomedInBackground(ca.disciplineid)--changed in api35??
        local sVal1 = zo_strformat("(<<1>>) <<2>>", ca.name , GetChampionSkillCurrentBonusText(ca.id,ca.numspentpoints) )
        local sVal2 = zo_strformat("(<<1>>) <<2>>", ca.name , GetChampionSkillDescription(ca.id,ca.numspentpoints) )
        ElderScrollsOfAlts.debugMsg("tooltip1: " , tostring(sVal1) , "tooltip2: " , tostring(sVal2) )
        icon.tooltip = sVal1
        --lbl:SetText( GetChampionSkillCurrentBonusText(ca.id,ca.numspentpoints) )
        lbl:SetText( ElderScrollsOfAlts:XlateChampionNameToShort(ca.id) )
        --lblR:SetText( ElderScrollsOfAlts:XlateChampionNameToShort(ca.id) )
        --
        icon2.tooltip    = sVal2
        icon2Rev.tooltip = sVal2
        lbl2:SetText( ca.name ) -- ElderScrollsOfAlts:XlateChampionNameToShort(ca.id) )
        lbl2R:SetText( ca.name )
        --
        slotControl.id    = ca.id
        slotControl.name  = ca.name
        slotControl.val2  = sVal2
        slotControl.numspentpoints = ca.numspentpoints
        slotControl2.id   = ca.id
        slotControl2.name = ca.name
        slotControl2.val2 = sVal2
        slotControl2.numspentpoints = ca.numspentpoints
      end
      if(backgroundTexture~=nil) then
        icon:SetTexture(backgroundTexture)
        icon2:SetTexture(backgroundTexture)
        icon2Rev:SetTexture(backgroundTexture)
      end
    end --for each slot
  end
    
  --SHOW/HIDE
  --1
  if(ElderScrollsOfAlts.savedVariables.cpactivebar1.show) then
    if(ElderScrollsOfAlts.savedVariables.cpactivebar1.x) then
      ElderScrollsOfAlts.view.cpbar1:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ElderScrollsOfAlts.savedVariables.cpactivebar1.x, ElderScrollsOfAlts.savedVariables.cpactivebar1.y)
    end
    ElderScrollsOfAlts.view.cpbarfragment1:Show()
    ElderScrollsOfAlts.view.cpbar1:SetMouseEnabled(true)
    ElderScrollsOfAlts.view.cpbar1:SetHidden(false)    
    ElderScrollsOfAlts.view.cpbar1:GetNamedChild("Backdrop"):SetHidden(false)
    if( ElderScrollsOfAlts.view.cpbar1.slots ~= nil) then
      for kkiT = 1, #ElderScrollsOfAlts.view.cpbar1.slots do
        ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:SetHidden(false) 
        ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:GetNamedChild("Icon"):SetHidden(false)
        if(ElderScrollsOfAlts.view.cpbar1.slots[kkiT].id ~= nil ) then       
          ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:GetNamedChild("Label"):SetHidden(false)          
        end
      end
    end
  else
    ElderScrollsOfAlts.view.cpbarfragment1:Hide()
    ElderScrollsOfAlts.view.cpbar1:SetMouseEnabled(false)
    ElderScrollsOfAlts.view.cpbar1:SetHidden(true)
    ElderScrollsOfAlts.view.cpbar1:GetNamedChild("Backdrop"):SetHidden(true)
    if( ElderScrollsOfAlts.view.cpbar1.slots ~= nil) then
      for kkiT = 1, #ElderScrollsOfAlts.view.cpbar1.slots do
        ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:SetHidden(true)
        ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:GetNamedChild("Label"):SetHidden(true)
        ElderScrollsOfAlts.view.cpbar1.slots[kkiT]:GetNamedChild("Icon"):SetHidden(true)
      end
    end
  end
  --2
  if(ElderScrollsOfAlts.savedVariables.cpactivebar2.show) then
    --ElderScrollsOfAlts.view.cpbarfragment2:Show()
    if(ElderScrollsOfAlts.savedVariables.cpactivebar2.x) then
      ElderScrollsOfAlts.view.cpbar2:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ElderScrollsOfAlts.savedVariables.cpactivebar2.x, ElderScrollsOfAlts.savedVariables.cpactivebar2.y)
    end
    ElderScrollsOfAlts.view.cpbar2:SetHidden(false)
    --ElderScrollsOfAlts.view.cpbar2:GetNamedChild("Backdrop"):SetHidden(false)
    ElderScrollsOfAlts:DoChampionAssignedTextBar_Expand()
    ElderScrollsOfAlts.view.cpbar2:SetMouseEnabled(true)
    ElderScrollsOfAlts.view.cpbar2:SetMovable(true)
  else
    ElderScrollsOfAlts.view.cpbar2:SetHidden(true)
    --ElderScrollsOfAlts.view.cpbar2:GetNamedChild("Backdrop"):SetHidden(true)
    ElderScrollsOfAlts:DoChampionAssignedTextBar_Collapse(true)
    --ElderScrollsOfAlts.view.cpbar2:SetMouseEnabled(false)
  end
  --xxx
  if( ElderScrollsOfAlts.savedVariables.cpactivebar1.show or ElderScrollsOfAlts.savedVariables.cpactivebar2.show ) then
    ElderScrollsOfAlts.debugMsg("CPBar(s) refreshed")
  end
end

--xxx
function ElderScrollsOfAlts:DoCAAB_MouseUp(control, button, upInside, ctrl, alt, shift, command)
  --ElderScrollsOfAlts.debugMsg("GUILineDoubleClick: Called")
  ElderScrollsOfAlts.debugMsg("DoCAAB_MouseUp: Called"
    , " control:".. tostring(control)
    , " button:".. tostring(button)
    , " upInside:".. tostring(upInside)
    , " ctrl:".. tostring(ctrl)    
    , " shift:".. tostring(shift)
    , " command:".. tostring(command)
  )
  --local charKey = button.charKey
  --ElderScrollsOfAlts.debugMsg("DoCAAB_MouseUp: charKey: " .. tostring(charKey) )
  
  if button == 1 then
    --
  elseif button == 2 then  
    --ElderScrollsOfAlts.debugMsg("val: " ..  tostring(slotControl2.val2) )
    --TODO do some stuff here!
  else
    
  end
end

-- 
function ElderScrollsOfAlts:SavePosition_CAAB()
  ElderScrollsOfAlts.savedVariables.cpactivebar1.x = ElderScrollsOfAlts.view.cpbar1:GetLeft()
  ElderScrollsOfAlts.savedVariables.cpactivebar1.y = ElderScrollsOfAlts.view.cpbar1:GetTop()
end

-- 
function ElderScrollsOfAlts:SavePosition_CATLB()
  ElderScrollsOfAlts.savedVariables.cpactivebar2.x = ElderScrollsOfAlts.view.cpbar2:GetLeft()
  ElderScrollsOfAlts.savedVariables.cpactivebar2.y = ElderScrollsOfAlts.view.cpbar2:GetTop()
end

--[[
function ElderScrollsOfAlts:SavePosition_CATLBSub()
  d("trying to move via sub item")
  --ElderScrollsOfAlts.savedVariables.cpactivebar2.x = self:GetLeft()
  --ElderScrollsOfAlts.savedVariables.cpactivebar2.y = self:GetTop()
end--]]

-- 
function ElderScrollsOfAlts:SavePosition_CATLB2()
  d("trying to move via slot ")
  ElderScrollsOfAlts.savedVariables.cpactivebar2.x = ElderScrollsOfAlts.view.cpbar2:GetLeft()
  ElderScrollsOfAlts.savedVariables.cpactivebar2.y = ElderScrollsOfAlts.view.cpbar2:GetTop()
end


-- 
function ElderScrollsOfAlts:RestorePosition_CATLB()
  --d("RestorePosition_CATLB: show? " .. tostring( ElderScrollsOfAlts.savedVariables.cpactivebar1.show) )
  --if( ElderScrollsOfAlts.savedVariables.cpactivebar1.show ) then
  --    ElderScrollsOfAlts.view.cpbar1:SetHidden(true)
  --end
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_Close()
  ElderScrollsOfAlts.view.cpbar2:SetHidden(true)
  --ElderScrollsOfAlts.DoChampionAssignedTextBar_MenuClose()
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_Show()
  ElderScrollsOfAlts.view.cpbar2:SetHidden(false)
  ElderScrollsOfAlts.DoChampionAssignedTextBar_MenuClose()
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_Collapse(fullhide)  
  if( ElderScrollsOfAlts.view.cpbar2.slots ~= nil) then
    for kkiT = 1, #ElderScrollsOfAlts.view.cpbar2.slots do
      ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Label"):SetHidden(true)
      ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("LabelRev"):SetHidden(true)
      ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Backdrop"):SetHidden(true)
      if(fullhide) then
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Icon"):SetHidden(true)
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("IconRev"):SetHidden(true)
        --ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Label"):GetNamedChild("Backdrop"):SetHidden(true)
        --ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("LabelRev"):GetNamedChild("Backdrop"):SetHidden(true)
      end
    end
  end
  --ElderScrollsOfAlts.view.cpbar2:SetDimensions(30,230)
  ElderScrollsOfAlts.DoChampionAssignedTextBar_MenuClose()
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_Expand()
  if( ElderScrollsOfAlts.view.cpbar2.slots ~= nil) then
    for kkiT = 1, #ElderScrollsOfAlts.view.cpbar2.slots do
      ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:SetHidden(false)
      ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Backdrop"):SetHidden(false)
      --d("direction:" .. tostring(ElderScrollsOfAlts.view.cpbar2.direction) )      
      if( ElderScrollsOfAlts.view.cpbar2.direction ) then -- Forward
        if(ElderScrollsOfAlts.view.cpbar2.slots[kkiT].id ~= nil ) then
          ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Label"):SetHidden(false)
          ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("LabelRev"):SetHidden(true)
        end
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Icon"):SetHidden(false)
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("IconRev"):SetHidden(true)
      else -- Reverse
        --d("show reverse" )
        if(ElderScrollsOfAlts.view.cpbar2.slots[kkiT].id ~= nil ) then
          ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Label"):SetHidden(true)
          ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("LabelRev"):SetHidden(false)
        end
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("Icon"):SetHidden(true)
        ElderScrollsOfAlts.view.cpbar2.slots[kkiT]:GetNamedChild("IconRev"):SetHidden(false)   
      end
    end -- for each slot
  end-- if slots
  --ElderScrollsOfAlts.view.cpbar2:SetDimensions(170,230)
  ElderScrollsOfAlts.DoChampionAssignedTextBar_MenuClose()
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_ReverseText()
  ElderScrollsOfAlts.view.cpbar2.direction = not ElderScrollsOfAlts.view.cpbar2.direction
  ElderScrollsOfAlts:SetupCPBar()  
end


-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_MenuClose()
  ESOA_ChampionAssignableTextListMenuBar:SetHidden(true)
end

-- 
function ElderScrollsOfAlts:DoChampionAssignedTextBar_MenuShow(control, button, upInside, ctrl, alt, shift, command)
   ElderScrollsOfAlts.debugMsg("DoCATB_MouseUp: Called"
     , " control:".. tostring(control)
    , " button:".. tostring(button)
    , " upInside:".. tostring(upInside)
    , " ctrl:".. tostring(ctrl)    
    , " shift:".. tostring(shift)
    , " command:".. tostring(command)
  )  
  if button == 1 then
    -- move?
  elseif button == 2 then  
    --
    if(control==nil) then
      ESOA_ChampionAssignableTextListMenuBar:SetAnchor(TOPLEFT, ElderScrollsOfAlts.view.cpbar2, TOPLEFT, 6, 2)
    else
      ESOA_ChampionAssignableTextListMenuBar:SetAnchor(TOPLEFT, control, TOPLEFT, 6, 6)
    end
    ESOA_ChampionAssignableTextListMenuBar:SetHidden(false)
  end--button side
end

------------------------------
-- EOF