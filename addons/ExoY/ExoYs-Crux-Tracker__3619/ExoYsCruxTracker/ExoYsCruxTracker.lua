

--[[ --------------- ]]
--[[ -- Variables -- ]]
--[[ --------------- ]]

local EM = GetEventManager() 
local WM = GetWindowManager()
local SV 

local LibExoY = LibExoYsUtilities

local arcanistId = 117

local idECT = "ExoYsCruxTracker"
local nameECT = "|c00FF00ExoY|rs Crux Tracker"
local versionECT = "2.2.0"

local cruxId = 184220
local cruxDuration = GetAbilityDuration( cruxId )

local Gui = {}
local CruxTracker = {} 
local Update = {}

local uiIsUnlocked = false 
local addonIsSleeping = true 

local function Debug(str) 
  LibExoY.Debug(str, {"ECT", "green"}, SV.g.showDebug)  
end

--[[ ---------------- ]]
--[[ -- Visibility -- ]]
--[[ ---------------- ]]

local function HideGui( )
  Debug("HideGui") 
  Gui.symbolic.SetScenes( false ) 
  Gui.numeric.SetScenes( false ) 
  Gui.timer.SetScenes( false ) 
  Gui.spattering.SetScenes( false ) 
  Gui.fateRealigned.SetScenes( false ) 
end 


local function ShowGui( showAll )
  Debug("ShowGui") 
  Gui.symbolic.SetScenes( showAll or SV.p.symbolic.enabled ) 
  Gui.numeric.SetScenes( showAll or SV.p.numeric.enabled )
  Gui.timer.SetScenes( showAll or SV.p.timer.enabled)
  Gui.spattering.SetScenes( showAll or SV.p.spattering.enabled )
  Gui.fateRealigned.SetScenes( showAll or SV.p.fateRealigned.enabled )
end


local function SetDemoMode( runDemo ) 
  Gui.symbolic.SetDemoMode( runDemo ) 
  Gui.numeric.SetDemoMode( runDemo ) 
  Gui.timer.SetDemoMode( runDemo ) 
  Gui.spattering.SetDemoMode( runDemo ) 
  Gui.fateRealigned.SetDemoMode( runDemo ) 
end


function SetVisibility() 
  Debug("Set Visibility")
  if uiIsUnlocked then ShowGui( true ) return end 
  if addonIsSleeping then HideGui() return end 
  if CruxTracker.hasCrux then ShowGui() return end
  if LibExoY.IsInCombat() and SV.p.showAlwaysInCombat then ShowGui() return end 
  if not CruxTracker.hasCrux then 
    if SV.p.hideWhenNoCrux then 
      HideGui() 
      return 
    else 
      ShowGui()
      return
    end 
  end
end


--[[ ---------------- ]]
--[[ -- Audio Cues -- ]]
--[[ ---------------- ]]

local soundSelection = {
  [1] = "ABILITY_COMPANION_ULTIMATE_READY",
  [2] = "ABILITY_WEAPON_SWAP_FAIL",
  [3] = "ACTIVE_SKILL_UNMORPHED",
  [4] = "ALCHEMY_CLOSED", 
  [5] = "ALCHEMY_OPENED",
  [6] = "ANTIQUITIES_DIGGING_DIG_POWER_REFUND",
  [7] = "ANTIQUITIES_FANFARE_FRAGMENT_DISCOVERED_FINAL",
  [8] = "BATTLEGROUND_CAPTURE_AREA_CAPTURED_OTHER_TEAM",
  [9] = "BATTLEGROUND_COUNTDOWN_FINISH",
 [10] = "BATTLEGROUND_MURDERBALL_RETURNED",
 [11] = "COUNTDOWN_TICK",
}

local audioCueList = {
  [1] = {id = "oneCrux", name = ECT_AUDIO_CUE_ONE_CRUX, defaultSound = 1},
  [2] = {id = "twoCrux", name = ECT_AUDIO_CUE_TWO_CRUX, defaultSound = 2}, 
  [3] = {id = "threeCrux", name = ECT_AUDIO_CUE_THREE_CRUX, defaultSound = 3}, 
  [4] = {id = "wasteCrux", name = ECT_AUDIO_CUE_WASTE_CRUX, defaultSound = 4}, 
  --[5] = {id = "consumeCrux", name = ECT_AUDIO_CUE_ZERO_CRUX, defaultSound = 5}, 
}

local function GetAudioCueDefaults() 
  local defaults = {}
  local function GetCueDefault( defaultSound ) 
    return {
      enabled = false, 
      sound = defaultSound, 
      volume = 1
    }
  end
  for _, cueInfo in pairs(audioCueList) do 
    defaults[cueInfo.id] = GetCueDefault( cueInfo.defaultSound ) 
  end
  return defaults 
end

local function PlayAudioCue( cueId, overwrite ) 
  local setting = SV.p.audioCue[cueId] 
  if setting.enabled or overwrite then 
    for i = 1, setting.volume do 
      PlaySound(SOUNDS[soundSelection[setting.sound]])
    end
  end 
end


local function GetAudioCueMenuControls() 
  local controls = {} 
  for _, cueInfo in ipairs(audioCueList) do 
    table.insert(controls, {
      type = "header", 
      name = cueInfo.name,
    })
    table.insert( controls, {
      type = "checkbox", 
      name = ECT_SETTING_ENABLED, 
      getFunc = function() return SV.p.audioCue[cueInfo.id].enabled end, 
      setFunc = function(bool) 
        SV.p.audioCue[cueInfo.id].enabled = bool
      end,
    })
    table.insert(controls, {
      type = "dropdown",
      name = ECT_SETTING_SOUND, 
      choices = soundSelection, 
      getFunc = function() return soundSelection[SV.p.audioCue[cueInfo.id].sound] end, 
      setFunc = function(sound) 
        for idx, str in ipairs(soundSelection) do 
          if str == sound then 
            SV.p.audioCue[cueInfo.id].sound = idx
            PlayAudioCue( cueInfo.id, true )
            break
          end
        end  
      end, 
      width = "half", 
    })
    table.insert(controls, {
      type = "slider",
      name = ECT_SETTING_VOLUME,
      min = 1, 
      max = 10, 
      step = 1, 
      getFunc = function() return SV.p.audioCue[cueInfo.id].volume end, 
      setFunc = function(value) 
        SV.p.audioCue[cueInfo.id].volume = value  
        PlayAudioCue( cueInfo.id, true )
      end, 
      width = "half", 
    })
  end 
  return {
    type = "submenu", 
    name = LibExoY.AddIconToString(ECT_SETTING_AUDIO_CUE, "esoui/art/icons/achievement_u24_teaser_2.dds", 36, "front"), 
    controls = controls,
  }
end

--[[ ---------------------- ]]
--[[ -- Symbolic Tracker -- ]]
--[[ ---------------------- ]]

local function GetSymbolicTrackerSettingDefaults() 
  return {
    enabled = true, 
    posX = 600, 
    posY = 600,
    layout = 2, 
    spacing = 1, 
    size = 50,
  }
end

local function InitializeSymbolicTracker() 
  local name = idECT.."SymbolicTracker"

  local win = WM:CreateTopLevelWindow( name.."Window" )
  win:ClearAnchors() 
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.symbolic.posX, SV.p.symbolic.posY)
  win:SetMouseEnabled(false) 
  win:SetMovable(false)
  win:SetClampedToScreen(true) 
  win:SetHidden(true)  
  win:SetHandler( "OnMoveStop", function() 
    SV.p.symbolic.posX = win:GetLeft() 
    SV.p.symbolic.posY = win:GetTop()
  end)

  local demoBack = WM:CreateControl( name.."DemoBack", win, CT_BACKDROP )
  demoBack:ClearAnchors()
  demoBack:SetAnchor(CENTER, win, CENTER, 0, 0) 
  demoBack:SetHidden(true)
  demoBack:SetEdgeColor(0,0,0,1) 
  demoBack:SetEdgeTexture(0,2,2,2) 
  demoBack:SetCenterColor(0,0,0,0.25)

  local frag = ZO_HUDFadeSceneFragment:New( win ) 
  local isShowing = false
  local function SetScenes( showUi )
    if isShowing == showUi then return end 
    Debug("Symbolic Tracker - Scene Update")
    if showUi then 
      HUD_UI_SCENE:AddFragment( frag )
      HUD_SCENE:AddFragment( frag )
    else 
      HUD_UI_SCENE:RemoveFragment( frag )
      HUD_SCENE:RemoveFragment( frag )
    end
    isShowing = showUi
  end 

  local symbols = {}

  local function DefineSymbol(i) 

    local ctrl = WM:CreateControl(name.."_SymbolCtrl"..tostring(i), win, CT_CONTROL)

    local back  = WM:CreateControl(name.."_SymbolBack"..tostring(i), ctrl, CT_TEXTURE )
    back:ClearAnchors()
    back:SetAnchor( CENTER, ctrl, CENTER, 0, 0)
    back:SetAlpha(0.8)
    back:SetTexture( "esoui/art/champion/champion_center_bg.dds")

    local frame = WM:CreateControl(name.."_SymbolFrame"..tostring(i), ctrl, CT_TEXTURE )
    frame:ClearAnchors()
    frame:SetAnchor( CENTER, ctrl, CENTER, 0, 0)
    frame:SetTexture( "esoui/art/champion/actionbar/champion_bar_slot_frame_disabled.dds")

    local icon = WM:CreateControl( name.."_SymbolIcon"..tostring(i), ctrl, CT_TEXTURE )
    icon:ClearAnchors() 
    icon:SetAnchor( CENTER, ctrl, CENTER, 0, 0 ) 
    icon:SetDesaturation(0.1)
    icon:SetTexture("/art/fx/texture/arcanist_trianglerune_01.dds")

    local highlight  = WM:CreateControl(name.."_SymbolHighlight"..tostring(i), ctrl, CT_TEXTURE )
    highlight:ClearAnchors()
    highlight:SetAnchor( CENTER, ctrl, CENTER, 0, 0)
    highlight:SetDesaturation(0.4)
    highlight:SetTexture( "esoui/art/champion/actionbar/champion_bar_world_selection.dds")
    highlight:SetColor(0,1,0,0)


    local function Activate()
      icon:SetColor(0,1,0,1)    
      highlight:SetAlpha(0.8)    
    end

    local function Deactivate()
      icon:SetColor(1,1,1,0.2)
      highlight:SetAlpha(0)
    end

    local function ChangeSize(size)
      back:SetDimensions(size*0.85,size*0.85)  
      frame:SetDimensions(size,size)
      highlight:SetDimensions(size,size)
      icon:SetDimensions(size*0.75,size*0.75)
    end

    return {ctrl = ctrl, Activate = Activate, Deactivate = Deactivate, ChangeSize = ChangeSize}
  end

  for i =1,3 do 
    symbols[i] = DefineSymbol(i)
  end


  local function UpdateLayout()
    local layout = SV.p.symbolic.layout
    local size = SV.p.symbolic.size 
    local spacing = SV.p.symbolic.spacing
    local orientation = {
          [1] = {-1, 0},  -- left
          [2] = { 1, 0},   -- right 
          [3] = { 0,-1},    -- up
          [4] = { 0, 1},  -- down
        }
        local coef = orientation[layout]
    for i = 2,3 do 
      local symbol = symbols[i]
      local offsetX = coef[1]*(i-1)*(size+spacing)
      local offsetY = coef[2]*(i-1)*(size+spacing)
      symbol.ctrl:ClearAnchors() 
      symbol.ctrl:SetAnchor(CENTER, win, CENTER, offsetX, offsetY)      
    end
    for _, symbol in ipairs(symbols) do 
      symbol.ChangeSize( SV.p.symbolic.size ) 
    end
    win:SetDimensions( 1.2*SV.p.symbolic.size, 1.2*SV.p.symbolic.size )
    demoBack:SetDimensions( 1.2*SV.p.symbolic.size, 1.2*SV.p.symbolic.size ) 
  end

  local function UpdateCrux( crux )
    if crux == 0 then 
      for i = 1,3 do 
        symbols[i].Deactivate()
      end
    else 
      for i = 1,crux do 
        symbols[i].Activate()
      end
    end

  end

  local function SetDemoMode( runDemo ) 
    win:SetMouseEnabled( runDemo )
    win:SetMovable( runDemo ) 
    demoBack:SetHidden( not runDemo ) 
  end

  -- initialize current settings
  symbols[1].ctrl:ClearAnchors() 
  symbols[1].ctrl:SetAnchor(CENTER, win, CENTER, 0, 0) 
  UpdateLayout()

  return {UpdateLayout = UpdateLayout, UpdateCrux = UpdateCrux, SetScenes = SetScenes, SetDemoMode = SetDemoMode}
end -- of "InitializeSymbolicTracker"

local function GetSymbolicTrackerMenuControls()
  local controls = {} 
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.symbolic.enabled end, 
    setFunc = function(bool) 
      SV.p.symbolic.enabled = bool
      SetVisibility() 
    end,
  })
    table.insert( controls, {
    type = "header", 
    name = ECT_SETTING_DESIGN,
    width = "full", 
  })
  table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SIZE, 
    min = 20, 
    max = 200, 
    step = 5, 
    getFunc = function() return SV.p.symbolic.size end, 
    setFunc = function(value) 
      SV.p.symbolic.size = value
      Gui.symbolic.UpdateLayout()
    end
  })
    table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SPACING, 
    min = 0, 
    max = 100, 
    step = 2, 
    getFunc = function() return SV.p.symbolic.spacing end, 
    setFunc = function(value) 
      SV.p.symbolic.spacing = value
      Gui.symbolic.UpdateLayout()
    end
  })
  local symbolicLayoutChoices = {
    ECT_SETTING_LAYOUT_LEFT,
    ECT_SETTING_LAYOUT_RIGHT, 
    ECT_SETTING_LAYOUT_UP, 
    ECT_SETTING_LAYOUT_DOWN
  }
  ectGlobal = symbolicLayoutChoices
  table.insert( controls, {
    type = "dropdown", 
    name = ECT_SETTING_LAYOUT, 
    choices = symbolicLayoutChoices, 
    getFunc = function() return symbolicLayoutChoices[SV.p.symbolic.layout] end, 
    setFunc = function(layout)
      for idx, str in ipairs(symbolicLayoutChoices) do 
        if str == layout then 
          SV.p.symbolic.layout = idx
          Gui.symbolic.UpdateLayout()
          break
        end
      end
    end,
  })
  return {
    type = "submenu", 
    name = LibExoY.AddIconToString(ECT_SETTING_SYMBOLIC_TRACKER, "esoui/art/icons/class_buff_arcanist_crux.dds", 36, "front"),
    controls = controls, 
  }
end



--[[ --------------------- ]]
--[[ -- Numeric Tracker -- ]]
--[[ --------------------- ]]

local function GetNumericTrackerSettingDefaults() 
  return {
    enabled = true,
    posX = 620, 
    posY = 500, 
    color = {
      [1] = {0.8,0.05,0.05,1}, -- no crux 
      [2] = {0.9,0.5,0.1,1}, -- one crux 
      [3] = {1,1,0,1}, -- two crux
      [4] = {0,1,0,1,} -- three crux 
    },
    font = 1, 
    size = 30, 
    displayZero = true, 
    design = {
      iconEnabled = false, 
      iconAlpha = 0.3, 
      iconDesaturation = 0.5, 
      backgroundAlpha = 0.2, 
      coloredEdgeEnabled = false, 
      coloredEdgeSize = 4,  
    },
  }
end

local function InitializeNumericTracker() 
  local name = idECT.."NumericTracker"

  --- hardcoded dimensions 
  local edgeLine = 2

  local win = WM:CreateTopLevelWindow( name.."Window" )
  win:ClearAnchors() 
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.numeric.posX, SV.p.numeric.posY)
  win:SetMouseEnabled(false) 
  win:SetMovable(false)
  win:SetClampedToScreen(true) 
  win:SetDimensions( 50,50 )
  win:SetHidden(true)  
  win:SetHandler( "OnMoveStop", function() 
    SV.p.numeric.posX = win:GetLeft() 
    SV.p.numeric.posY = win:GetTop()
  end)

local frag = ZO_HUDFadeSceneFragment:New( win ) 
local isShowing = false
  local function SetScenes( showUi )
    if isShowing == showUi then return end 
    if showUi then 
      HUD_UI_SCENE:AddFragment( frag )
      HUD_SCENE:AddFragment( frag )
    else 
      HUD_UI_SCENE:RemoveFragment( frag )
      HUD_SCENE:RemoveFragment( frag )
    end
    isShowing = showUi
  end 

  local ctrl = WM:CreateControl( name.."_Ctrl", win, CT_CONTROL)
  ctrl:ClearAnchors() 
  ctrl:SetAnchor(CENTER, win, CENTER, 0, 0) 

  local coloredEdge = WM:CreateControl( name.."ColoredEdge", ctrl, CT_BACKDROP)
  coloredEdge:ClearAnchors() 
  coloredEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  coloredEdge:SetCenterColor(0,0,0,0)
  
  local outerEdge = WM:CreateControl( name.."OuterEdge", ctrl, CT_BACKDROP) 
  outerEdge:ClearAnchors() 
  outerEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  outerEdge:SetCenterColor(0,0,0,0)
  outerEdge:SetEdgeColor(0,0,0,1)

  local back = WM:CreateControl( name.."_Back", ctrl, CT_BACKDROP)
  back:ClearAnchors() 
  back:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  back:SetCenterColor(0,0,0)
  back:SetEdgeColor(0,0,0,1)
  back:SetEdgeTexture(nil, edgeLine, edgeLine, backgedgeLineroundEdge) 
  
  local icon = WM:CreateControl( name.."_Icon", ctrl, CT_TEXTURE) 
  icon:ClearAnchors()
  icon:SetAnchor(CENTER, ctrl, CENTER, 0, 0)
  icon:SetTexture( "esoui/art/icons/achievement_u46_class_meta_arcanist.dds") 
  icon:SetColor(1,1,1,0.2)
  icon:SetDesaturation(0.5) 

  local label = WM:CreateControl( name.."_Label", ctrl, CT_LABEL)   
  label:ClearAnchors() 
  label:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  label:SetVerticalAlignment( TEXT_ALIGN_CENTER )
  label:SetHorizontalAlignment( TEXT_ALIGN_CENTER )
  label:SetScale(2)


  local function UpdateDesign()
    --- size
    local iconSize = 2*SV.p.numeric.size
    local coloredEdgeSize = 2^SV.p.numeric.design.coloredEdgeSize
    local edgeSize = SV.p.numeric.design.coloredEdgeEnabled and coloredEdgeSize or 0
    local totalSize = iconSize + 2*edgeSize + 2*edgeLine
    
    win:SetDimensions( totalSize, totalSize )
    outerEdge:SetDimensions( totalSize, totalSize )
    coloredEdge:SetDimensions( totalSize, totalSize )
    back:SetDimensions( 2*edgeLine+iconSize, 2*edgeLine+iconSize )
    icon:SetDimensions(iconSize, iconSize) 
    
    --- label 
    local fontData = {
      font = LibExoY.GetFontList()[SV.p.numeric.font], 
      size = SV.p.numeric.size, 
      outline = 2, 
    }
    label:SetFont( LibExoY.GetFont(fontData) ) 

    --- background
    back:SetHidden(not SV.p.numeric.design.iconEnabled)
    back:SetAlpha( SV.p.numeric.design.backgroundAlpha ) 
    
    --- edge 
    outerEdge:SetHidden( not SV.p.numeric.design.coloredEdgeEnabled)
    coloredEdge:SetHidden( not SV.p.numeric.design.coloredEdgeEnabled)
    coloredEdge:SetEdgeTexture(nil,coloredEdgeSize,coloredEdgeSize,coloredEdgeSize)

    --- icon 
    icon:SetHidden( not SV.p.numeric.design.iconEnabled )
    icon:SetAlpha( SV.p.numeric.design.iconAlpha) 
    icon:SetDesaturation( SV.p.numeric.design.iconDesaturation)
  end 

  local function UpdateCrux(crux) 
    cruxStr = tostring(crux)
    if crux == 0 and not SV.p.numeric.displayZero then cruxStr = "" end 
    label:SetText( cruxStr )
    local r,g,b,a = unpack(SV.p.numeric.color[crux+1])
    label:SetColor( r,g,b,a )
    coloredEdge:SetEdgeColor(r,g,b,a)
  end


  local function SetDemoMode( demoMode ) 
    win:SetMouseEnabled( demoMode ) 
    win:SetMovable( demoMode )
  end

  UpdateDesign()
  return {UpdateDesign = UpdateDesign, UpdateCrux = UpdateCrux, SetScenes = SetScenes, SetDemoMode = SetDemoMode}
end


local function GetNumericTrackerMenuControls() 
  local controls = {}
  table.insert(controls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.numeric.enabled end, 
    setFunc = function(bool) 
      SV.p.numeric.enabled = bool
      SetVisibility()
    end
  })
  table.insert( controls, {
    type = "header", 
    name = ECT_SETTING_INDICATOR, 
    width = "full", 
  })
  table.insert( controls, {
    type = "dropdown", 
    name = ECT_SETTING_FONT, 
    choices = LibExoY.GetFontList(), 
    getFunc = function() return LibExoY.GetFontList()[SV.p.numeric.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(LibExoY.GetFontList() ) do 
        if selection == font then 
          SV.p.numeric.font = idx
          break 
        end
      end
      Gui.numeric.UpdateDesign() 
    end,
  })
  table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SIZE, 
    min = 10, 
    max = 80, 
    step = 2, 
    getFunc = function() return SV.p.numeric.size end, 
    setFunc = function( size ) 
      SV.p.numeric.size = size 
      Gui.numeric.UpdateDesign() 
    end
  })
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_DISPLAY_ZERO, 
    getFunc = function() return SV.p.numeric.displayZero end,
    setFunc = function(bool) 
      SV.p.numeric.displayZero = bool 
      Gui.numeric.UpdateCrux( CruxTracker.previousCrux )
    end,
    })
  table.insert(controls, {type = "divider"})
  labelList = {ECT_CRUX_ZERO, ECT_CRUX_ONE, ECT_CRUX_TWO, ECT_CRUX_THREE} 
  for idx, label in ipairs(labelList) do 
    table.insert( controls, {
      type = "colorpicker", 
      name = "Color "..label, 
      getFunc = function() return unpack(SV.p.numeric.color[idx]) end, 
      setFunc = function(r,g,b,a)
        SV.p.numeric.color[idx] = {r,g,b,a} 
      end, 
      width = "half", 
    })
  end

  local advancedDesignControls = {} 
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_ICON, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.numeric.design.iconEnabled end, 
    setFunc = function(bool)
      SV.p.numeric.design.iconEnabled = bool
      Gui.numeric.UpdateDesign()
    end, 
    width = "half"
  })

  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_BACK_ALPHA, 
    getFunc = function() return SV.p.numeric.design.backgroundAlpha end, 
    setFunc = function(value) 
      SV.p.numeric.design.backgroundAlpha = value
      Gui.numeric.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_DESA, 
    getFunc = function() return SV.p.numeric.design.iconDesaturation end, 
    setFunc = function(value) 
      SV.p.numeric.design.iconDesaturation = value
      Gui.numeric.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_ALPHA, 
    getFunc = function() return SV.p.numeric.design.iconAlpha end, 
    setFunc = function(value) 
      SV.p.numeric.design.iconAlpha = value
      Gui.numeric.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_COLORED_EDGE, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.numeric.design.coloredEdgeEnabled end, 
    setFunc = function(bool)
      SV.p.numeric.design.coloredEdgeEnabled = bool
      Gui.numeric.UpdateDesign()
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 1, 
    max = 4, 
    step = 1, 
    name = ECT_SETTING_SIZE, 
    getFunc = function() return SV.p.numeric.design.coloredEdgeSize end, 
    setFunc = function(value) 
      SV.p.numeric.design.coloredEdgeSize = value
      Gui.numeric.UpdateDesign() 
    end,
    width = "half", 
  })

  table.insert(controls, {
    type = "submenu", 
    name = ECT_SETTING_ADVANCED_DESIGN, 
    controls = advancedDesignControls,
  })
  return {
    type = "submenu", 
    name = LibExoY.AddIconToString(ECT_SETTING_NUMERIC_TRACKER, "esoui/art/icons/ability_arcanist_001_blue.dds", 36, "front"),
    controls = controls, 
  }
end

--[[ ---------------- ]]
--[[ -- Crux Timer -- ]]
--[[ ---------------- ]]

local function GetCruxTimerSettingsDefaults() 
  return {
    enabled = true, 
    threshold = 5, 
    posX = 700, 
    posY = 500, 
    font = 1, 
    size = 24, 
    displayZero = false, 
    colorLong = {0,1,0,1}, 
    design = {
      iconEnabled = true, 
      iconAlpha = 0.3, 
      iconDesaturation = 0.5, 
      backgroundAlpha = 0.2, 
      coloredEdgeEnabled = false, 
      coloredEdgeSize = 4,  
    },
  }
end


local function InitializeCruxTimer() 
  local name = idECT.."Timer" 

  --- hardcoded dimensions 
  local edgeLine = 2

  local win = WM:CreateTopLevelWindow( name.."Window" )
  win:ClearAnchors() 
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.timer.posX, SV.p.timer.posY)
  win:SetMouseEnabled(false) 
  win:SetMovable(false)
  win:SetClampedToScreen(true) 
  win:SetDimensions( 50,50 )
  win:SetHidden(true)  
  win:SetHandler( "OnMoveStop", function() 
    SV.p.timer.posX = win:GetLeft() 
    SV.p.timer.posY = win:GetTop()
  end)

local frag = ZO_HUDFadeSceneFragment:New( win ) 
local isShowing = false
  local function SetScenes( showUi )
    if isShowing == showUi then return end 
    if showUi then 
      HUD_UI_SCENE:AddFragment( frag )
      HUD_SCENE:AddFragment( frag )
    else 
      HUD_UI_SCENE:RemoveFragment( frag )
      HUD_SCENE:RemoveFragment( frag )
    end
    isShowing = showUi
  end 

  local ctrl = WM:CreateControl( name.."_Ctrl", win, CT_CONTROL)
  ctrl:ClearAnchors() 
  ctrl:SetAnchor(CENTER, win, CENTER, 0, 0) 

  local coloredEdge = WM:CreateControl( name.."ColoredEdge", ctrl, CT_BACKDROP)
  coloredEdge:ClearAnchors() 
  coloredEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  coloredEdge:SetCenterColor(0,0,0,0)
  
  local outerEdge = WM:CreateControl( name.."OuterEdge", ctrl, CT_BACKDROP) 
  outerEdge:ClearAnchors() 
  outerEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  outerEdge:SetCenterColor(0,0,0,0)
  outerEdge:SetEdgeColor(0,0,0,1)

  local back = WM:CreateControl( name.."_Back", ctrl, CT_BACKDROP)
  back:ClearAnchors() 
  back:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  back:SetCenterColor(0,0,0)
  back:SetEdgeColor(0,0,0,1)
  back:SetEdgeTexture(nil, edgeLine, edgeLine, backgedgeLineroundEdge) 
  
  local icon = WM:CreateControl( name.."_Icon", ctrl, CT_TEXTURE) 
  icon:ClearAnchors()
  icon:SetAnchor(CENTER, ctrl, CENTER, 0, 0)
  icon:SetTexture( "esoui/art/icons/u35_dun1_speed_challenge.dds") 
  icon:SetColor(1,1,1,0.2)
  icon:SetDesaturation(0.5) 

  local label = WM:CreateControl( name.."_Label", ctrl, CT_LABEL)   
  label:ClearAnchors() 
  label:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  label:SetVerticalAlignment( TEXT_ALIGN_CENTER )
  label:SetHorizontalAlignment( TEXT_ALIGN_CENTER )
  label:SetScale(2)


  local function UpdateDesign()
    --- size
    local iconSize = 3.2*SV.p.timer.size
    local coloredEdgeSize = 2^SV.p.timer.design.coloredEdgeSize
    local edgeSize = SV.p.timer.design.coloredEdgeEnabled and coloredEdgeSize or 0
    local totalSize = iconSize + 2*edgeSize + 2*edgeLine
    
    win:SetDimensions( totalSize, totalSize )
    outerEdge:SetDimensions( totalSize, totalSize )
    coloredEdge:SetDimensions( totalSize, totalSize )
    back:SetDimensions( 2*edgeLine+iconSize, 2*edgeLine+iconSize )
    icon:SetDimensions(iconSize, iconSize) 
    
    --- label 
    local fontData = {
      font = LibExoY.GetFontList()[SV.p.timer.font], 
      size = SV.p.timer.size, 
      outline = 2, 
    }
    label:SetFont( LibExoY.GetFont(fontData) ) 
    label:SetColor( unpack(SV.p.timer.colorLong) )

    --- background
    back:SetHidden(not SV.p.timer.design.iconEnabled)
    back:SetAlpha( SV.p.timer.design.backgroundAlpha ) 
    
    --- edge 
    outerEdge:SetHidden( not SV.p.timer.design.coloredEdgeEnabled)
    coloredEdge:SetHidden( not SV.p.timer.design.coloredEdgeEnabled)
    coloredEdge:SetEdgeTexture(nil,coloredEdgeSize,coloredEdgeSize,coloredEdgeSize)

    --- icon 
    icon:SetHidden( not SV.p.timer.design.iconEnabled )
    icon:SetAlpha( SV.p.timer.design.iconAlpha) 
    icon:SetDesaturation( SV.p.timer.design.iconDesaturation)
  end 

  local function UpdateTime() 
    local endTime = CruxTracker.endTime 
    local timeRemaining = endTime - GetGameTimeSeconds() 
    local str = SV.p.timer.displayZero and "0s" or ""
    if timeRemaining >= 0  then 
      str = LibExoY.GetCountdownString( timeRemaining, true, false, true)
    end
    label:SetText(str) 
  end


  local function SetDemoMode( demoMode ) 
    win:SetMouseEnabled( demoMode ) 
    win:SetMovable( demoMode )
  end

  UpdateDesign()
  return {UpdateDesign = UpdateDesign, UpdateTime = UpdateTime, SetScenes = SetScenes, SetDemoMode = SetDemoMode}
end


local function GetCruxTimerMenuControls() 
  local controls = {}
  table.insert(controls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.timer.enabled end, 
    setFunc = function(bool) 
      SV.p.timer.enabled = bool 
      if bool then 
        Update:AddToList("CruxTimer", Gui.timer.UpdateTime)
      else 
        Update:RemoveFromList("CruxTimer")
      end
      SetVisibility() 
    end, 
  }) 

  table.insert( controls, {
    type = "header", 
    name = ECT_SETTING_INDICATOR, 
    width = "full", 
  })
  table.insert( controls, {
    type = "dropdown", 
    name = ECT_SETTING_FONT, 
    choices = LibExoY.GetFontList(), 
    getFunc = function() return LibExoY.GetFontList()[SV.p.timer.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(LibExoY.GetFontList() ) do 
        if selection == font then 
          SV.p.timer.font = idx
          break 
        end
      end
      Gui.timer.UpdateDesign() 
    end,
  })
  table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SIZE, 
    min = 10, 
    max = 80, 
    step = 2, 
    getFunc = function() return SV.p.timer.size end, 
    setFunc = function( size ) 
      SV.p.timer.size = size 
      Gui.timer.UpdateDesign() 
    end
  })
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_DISPLAY_ZERO, 
    getFunc = function() return SV.p.timer.displayZero end,
    setFunc = function(bool) 
      SV.p.timer.displayZero = bool 
    end,
    })
    table.insert( controls, {
      type = "colorpicker", 
      name = ECT_SETTING_COLOR, 
      getFunc = function() return unpack(SV.p.timer.colorLong) end, 
      setFunc = function(r,g,b,a)
        SV.p.timer.colorLong = {r,g,b,a} 
      end, 
    })

  local advancedDesignControls = {} 
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_ICON, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.timer.design.iconEnabled end, 
    setFunc = function(bool)
      SV.p.timer.design.iconEnabled = bool
      Gui.timer.UpdateDesign()
    end, 
    width = "half"
  })

  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_BACK_ALPHA, 
    getFunc = function() return SV.p.timer.design.backgroundAlpha end, 
    setFunc = function(value) 
      SV.p.timer.design.backgroundAlpha = value
      Gui.timer.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_DESA, 
    getFunc = function() return SV.p.timer.design.iconDesaturation end, 
    setFunc = function(value) 
      SV.p.timer.design.iconDesaturation = value
      Gui.timer.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_ALPHA, 
    getFunc = function() return SV.p.timer.design.iconAlpha end, 
    setFunc = function(value) 
      SV.p.timer.design.iconAlpha = value
      Gui.timer.UpdateDesign() 
    end,
    width = "half", 
  })
  --[[
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_COLORED_EDGE, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.timer.design.coloredEdgeEnabled end, 
    setFunc = function(bool)
      SV.p.timer.design.coloredEdgeEnabled = bool
      Gui.timer.UpdateDesign()
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 1, 
    max = 4, 
    step = 1, 
    name = ECT_SETTING_SIZE, 
    getFunc = function() return SV.p.timer.design.coloredEdgeSize end, 
    setFunc = function(value) 
      SV.p.timer.design.coloredEdgeSize = value
      Gui.timer.UpdateDesign() 
    end,
    width = "half", 
  })
    ]]

  table.insert(controls, {
    type = "submenu", 
    name = ECT_SETTING_ADVANCED_DESIGN, 
    controls = advancedDesignControls,
  })

  return {
    type = "submenu", 
    name = LibExoY.AddIconToString(ECT_SETTING_CRUX_TIMER, "esoui/art/icons/u35_dun1_speed_challenge.dds", 36, "front"),
    controls = controls
  }
end


--[[ ---------------------------- ]]
--[[ -- Spattering Disjunction -- ]]
--[[ ---------------------------- ]]

local Spattering = {  
  setId = 775, 
  heraldSkillNames = {},
  endTime = 0, 
}

local function GetSpatteringTrackerSettingsDefaults() 
  return {
    enabled = false, 
    threshold = 5, --
    posX = 700, 
    posY = 500, 
    font = 1, 
    size = 24, 
    displayZero = false, 
    colorLong = {0,1,0,1}, 
    design = {
      iconEnabled = true, 
      iconAlpha = 0.3, 
      iconDesaturation = 0.5, 
      backgroundAlpha = 0.2, 
      coloredEdgeEnabled = false, 
      coloredEdgeSize = 4,  
    },
  }
end

local function UpdateHeraldDmgList() 
  Spattering.heraldSkillNames = {}
  for i = 1,6 do 
    local abilityId = GetSkillAbilityId(SKILL_TYPE_CLASS, 1, i) -- going through first skill tree of current class 
    local abilityName = GetAbilityName(abilityId) 
    Spattering.heraldSkillNames[abilityName] = true 
  end
end


local function InitializeSpatteringTracker() 
  local name = idECT.."Spattering" 

  --- hardcoded dimensions 
  local edgeLine = 2

  local win = WM:CreateTopLevelWindow( name.."Window" )
  win:ClearAnchors() 
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.spattering.posX, SV.p.spattering.posY)
  win:SetMouseEnabled(false) 
  win:SetMovable(false)
  win:SetClampedToScreen(true) 
  win:SetDimensions( 50,50 )
  win:SetHidden(true)  
  win:SetHandler( "OnMoveStop", function() 
    SV.p.spattering.posX = win:GetLeft() 
    SV.p.spattering.posY = win:GetTop()
  end)

local frag = ZO_HUDFadeSceneFragment:New( win ) 
local isShowing = false
  local function SetScenes( showUi )
    if isShowing == showUi then return end 
    if showUi then 
      HUD_UI_SCENE:AddFragment( frag )
      HUD_SCENE:AddFragment( frag )
    else 
      HUD_UI_SCENE:RemoveFragment( frag )
      HUD_SCENE:RemoveFragment( frag )
    end
    isShowing = showUi
  end 

  local ctrl = WM:CreateControl( name.."_Ctrl", win, CT_CONTROL)
  ctrl:ClearAnchors() 
  ctrl:SetAnchor(CENTER, win, CENTER, 0, 0) 

  local coloredEdge = WM:CreateControl( name.."ColoredEdge", ctrl, CT_BACKDROP)
  coloredEdge:ClearAnchors() 
  coloredEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  coloredEdge:SetCenterColor(0,0,0,0)
  
  local outerEdge = WM:CreateControl( name.."OuterEdge", ctrl, CT_BACKDROP) 
  outerEdge:ClearAnchors() 
  outerEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  outerEdge:SetCenterColor(0,0,0,0)
  outerEdge:SetEdgeColor(0,0,0,1)

  local back = WM:CreateControl( name.."_Back", ctrl, CT_BACKDROP)
  back:ClearAnchors() 
  back:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  back:SetCenterColor(0,0,0)
  back:SetEdgeColor(0,0,0,1)
  back:SetEdgeTexture(nil, edgeLine, edgeLine, backgedgeLineroundEdge) 
  
  local icon = WM:CreateControl( name.."_Icon", ctrl, CT_TEXTURE) 
  icon:ClearAnchors()
  icon:SetAnchor(CENTER, ctrl, CENTER, 0, 0)
  icon:SetTexture( "esoui/art/icons/ability_u45_dun2_b1_ricochet.dds") 
  icon:SetColor(1,1,1,0.2)
  icon:SetDesaturation(0.5) 

  local label = WM:CreateControl( name.."_Label", ctrl, CT_LABEL)   
  label:ClearAnchors() 
  label:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  label:SetVerticalAlignment( TEXT_ALIGN_CENTER )
  label:SetHorizontalAlignment( TEXT_ALIGN_CENTER )
  label:SetScale(2)

  --[[
  local labelName = WM:CreateControl( name.."_Name", ctrl, CT_LABEL) 
  labelName:ClearAnchors() 
  labelName:SetAnchor(BOTTOM, ctrl, TOP, 0, 0) 
  labelName:SetVerticalAlignment( TEXT_ALIGN_CENTER )
  labelName:SetHorizontalAlignment( TEXT_ALIGN_CENTER )
  labelName:SetFont(LibExoY.GetFont(10))
  labelName:SetText("CruxTracker\nSpattering (Beta)")
  labelName:SetDimensions
  labelName:SetScale(1)
  ]]

  local function UpdateDesign()
    --- size
    local iconSize = 3.2*SV.p.spattering.size
    local coloredEdgeSize = 2^SV.p.spattering.design.coloredEdgeSize
    local edgeSize = SV.p.spattering.design.coloredEdgeEnabled and coloredEdgeSize or 0
    local totalSize = iconSize + 2*edgeSize + 2*edgeLine
    
    win:SetDimensions( totalSize, totalSize )
    outerEdge:SetDimensions( totalSize, totalSize )
    coloredEdge:SetDimensions( totalSize, totalSize )
    back:SetDimensions( 2*edgeLine+iconSize, 2*edgeLine+iconSize )
    icon:SetDimensions(iconSize, iconSize) 
    
    --- label 
    local fontData = {
      font = LibExoY.GetFontList()[SV.p.spattering.font], 
      size = SV.p.spattering.size, 
      outline = 2, 
    }
    label:SetFont( LibExoY.GetFont(fontData) ) 
    label:SetColor( unpack(SV.p.spattering.colorLong) )

    --- background
    back:SetHidden(not SV.p.spattering.design.iconEnabled)
    back:SetAlpha( SV.p.spattering.design.backgroundAlpha ) 
    
    --- edge 
    outerEdge:SetHidden( not SV.p.spattering.design.coloredEdgeEnabled)
    coloredEdge:SetHidden( not SV.p.spattering.design.coloredEdgeEnabled)
    coloredEdge:SetEdgeTexture(nil,coloredEdgeSize,coloredEdgeSize,coloredEdgeSize)

    --- icon 
    icon:SetHidden( not SV.p.spattering.design.iconEnabled )
    icon:SetAlpha( SV.p.spattering.design.iconAlpha) 
    icon:SetDesaturation( SV.p.spattering.design.iconDesaturation)
  end 

  --local function UpdateTime() 
  --  local endTime = CruxTracker.endTime 
  --  local timeRemaining = endTime - GetGameTimeSeconds() 
  --  local str = SV.p.spattering.displayZero and "0s" or ""
  --  if timeRemaining >= 0  then 
  --    str = LibExoY.GetCountdownString( timeRemaining, true, false, true)
  --  end
  --  label:SetText(str) 
  --end


  local function SetDemoMode( demoMode ) 
    win:SetMouseEnabled( demoMode ) 
    win:SetMovable( demoMode )
  end

  UpdateDesign()
  return {UpdateDesign = UpdateDesign, SetScenes = SetScenes, SetDemoMode = SetDemoMode, label = label}
end


local dmgResults = {
      [ACTION_RESULT_DAMAGE] = true, 
      [ACTION_RESULT_CRITICAL_DAMAGE] = true, 
      [ACTION_RESULT_DOT_TICK] = true, 
      [ACTION_RESULT_DOT_TICK_CRITICAL] = true, 
    } 


local function OnHeraldDmg(event, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow) 
  local LSD = LibSetDetection -- as it is only beta for now, i dont want to incldue the dependency yet
  if LSD then
    if  LSD.IsSetActiveOnCurrentBar then 
      if not LSD.IsSetActiveOnCurrentBar( Spattering.setId ) then return end -- set is not active  
    end
  end
  if not dmgResults[result] then return end -- it wasnt dmg 

  --d( zo_strformat("Dmg Event: <<1>> (<<2>>) <<3>>", abilityName, abilityId, GetAbilityName(abilityId)) )  ---@debug
  --d( "DmgEvent: "..abilityName.."("..GetAbilityName(abilityId)..")")


  if Spattering.heraldSkillNames[abilityName] then 
    if Spattering.active and not Spattering.dmgCd then
      Spattering.dmgCd = true 
      Spattering.dmgCdEnd = GetGameTimeMilliseconds() + 1000 
      Spattering.endTime = Spattering.endTime - 500  
      --d("Reduced Spattering CD") --- @debug
    end
  end
end



local function OnSpatteringProc() 
  Spattering.endTime = GetGameTimeMilliseconds() + 7000 
  Spattering.active = true 
  Spattering.dmgCd = false
end


local function OnSpatteringUpdate() 
    --if not Spattering.active then return end
    local time = GetGameTimeMilliseconds()  

    if Spattering.dmgCd and Spattering.dmgCdEnd < time then 
      Spattering.dmgCd = false 
    end 

    local timeRemaining = math.floor((Spattering.endTime - time )/100) 
    local displayTime = zo_max(timeRemaining/10, 0) 
    local displayStr =  tostring(displayTime)
    if displayTime == 0 and not SV.p.spattering.displayZero then displayStr = "" end

    --Gui.spattering.label:SetText( SV.p.spattering.displayZero and tostring(zo_max(timeRemaining, 0) ) or "")
    Gui.spattering.label:SetText( displayStr ) 

    if Spattering.endTime < time then 
      Spattering.active = false 
    end
end

local function StartTrackingSpattering() 
  UpdateHeraldDmgList()
  EM:RegisterForEvent("CruxTracker_HoTSkills", EVENT_SKILLS_FULL_UPDATE, UpdateHeraldDmgList) 
  EM:RegisterForEvent("CruxTracker_Spattering", EVENT_COMBAT_EVENT, OnSpatteringProc) 
  EM:AddFilterForEvent("CruxTracker_Spattering", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, 227565) 
  EM:AddFilterForEvent("CruxTracker_Spattering", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE , COMBAT_UNIT_TYPE_PLAYER) 
  EM:RegisterForEvent("CruxTracker_HoTDmg", EVENT_COMBAT_EVENT, OnHeraldDmg) 
  Update:AddToList( "Spattering", OnSpatteringUpdate) 
end

local function StopTrackingSpattering() 
  EM:UnregisterForEvent("CruxTracker_HoTSkills", EVENT_SKILLS_FULL_UPDATE)
  EM:UnregisterForEvent("CruxTracker_Spattering", EVENT_COMBAT_EVENT) 
  EM:UnregisterForEvent("CruxTracker_HotDmg", EVENT_COMBAT_EVENT)
  Update:RemoveFromList("Spattering") 
end


local function GetSpatteringTrackerMenuControls() 
  local controls = {}
  table.insert(controls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.spattering.enabled end, 
    setFunc = function(bool) 
      SV.p.spattering.enabled = bool 
      SetVisibility() 
    end, 
  }) 

  table.insert( controls, {
    type = "header", 
    name = ECT_SETTING_INDICATOR, 
    width = "full", 
  })
  table.insert( controls, {
    type = "dropdown", 
    name = ECT_SETTING_FONT, 
    choices = LibExoY.GetFontList(), 
    getFunc = function() return LibExoY.GetFontList()[SV.p.spattering.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(LibExoY.GetFontList() ) do 
        if selection == font then 
          SV.p.spattering.font = idx
          break 
        end
      end
      Gui.spattering.UpdateDesign() 
    end,
  })
  table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SIZE, 
    min = 10, 
    max = 80, 
    step = 2, 
    getFunc = function() return SV.p.spattering.size end, 
    setFunc = function( size ) 
      SV.p.spattering.size = size 
      Gui.spattering.UpdateDesign() 
    end
  })
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_DISPLAY_ZERO, 
    getFunc = function() return SV.p.spattering.displayZero end,
    setFunc = function(bool) 
      SV.p.spattering.displayZero = bool 
    end,
    })
    table.insert( controls, {
      type = "colorpicker", 
      name = ECT_SETTING_COLOR, 
      getFunc = function() return unpack(SV.p.spattering.colorLong) end, 
      setFunc = function(r,g,b,a)
        SV.p.spattering.colorLong = {r,g,b,a} 
      end, 
    })

  local advancedDesignControls = {} 
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_ICON, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.spattering.design.iconEnabled end, 
    setFunc = function(bool)
      SV.p.spattering.design.iconEnabled = bool
      Gui.spattering.UpdateDesign()
    end, 
    width = "half"
  })

  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_BACK_ALPHA, 
    getFunc = function() return SV.p.spattering.design.backgroundAlpha end, 
    setFunc = function(value) 
      SV.p.spattering.design.backgroundAlpha = value
      Gui.spattering.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_DESA, 
    getFunc = function() return SV.p.spattering.design.iconDesaturation end, 
    setFunc = function(value) 
      SV.p.spattering.design.iconDesaturation = value
      Gui.spattering.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_ALPHA, 
    getFunc = function() return SV.p.spattering.design.iconAlpha end, 
    setFunc = function(value) 
      SV.p.spattering.design.iconAlpha = value
      Gui.spattering.UpdateDesign() 
    end,
    width = "half", 
  })
  --[[
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_COLORED_EDGE, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.timer.design.coloredEdgeEnabled end, 
    setFunc = function(bool)
      SV.p.timer.design.coloredEdgeEnabled = bool
      Gui.timer.UpdateDesign()
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 1, 
    max = 4, 
    step = 1, 
    name = ECT_SETTING_SIZE, 
    getFunc = function() return SV.p.timer.design.coloredEdgeSize end, 
    setFunc = function(value) 
      SV.p.timer.design.coloredEdgeSize = value
      Gui.timer.UpdateDesign() 
    end,
    width = "half", 
  })
    ]]

  table.insert(controls, {
    type = "submenu", 
    name = ECT_SETTING_ADVANCED_DESIGN, 
    controls = advancedDesignControls,
  })

  return {
    type = "submenu", 
    name = LibExoY.AddIconToString("Spattering Disjunction", "esoui/art/icons/ability_u45_dun2_b1_ricochet.dds", 36, "front"),
    controls = controls
  }
end

--[[ -------------------- ]]
--[[ -- Fate Realigned -- ]]
--[[ -------------------- ]]

local FateRealigned = {  
  procId = 263407, 
  buffId = 268372,
  endTime = 0, 
}

local function GetFateRealignedSettingsDefaults() 
  return {
    enabled = false, 
    threshold = 5, --
    posX = 800, 
    posY = 500, 
    font = 1, 
    size = 24, 
    displayZero = false, 
    colorLong = {0,1,0,1}, 
    design = {
      iconEnabled = true, 
      iconAlpha = 0.3, 
      iconDesaturation = 0.5, 
      backgroundAlpha = 0.2, 
      coloredEdgeEnabled = false, 
      coloredEdgeSize = 4,  
    },
  }
end


local function InitializeFateRealignedTracker() 
  local name = idECT.."FateRealigned" 

  --- hardcoded dimensions 
  local edgeLine = 2

  local win = WM:CreateTopLevelWindow( name.."Window" )
  win:ClearAnchors() 
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.fateRealigned.posX, SV.p.fateRealigned.posY)
  win:SetMouseEnabled(false) 
  win:SetMovable(false)
  win:SetClampedToScreen(true) 
  win:SetDimensions( 50,50 )
  win:SetHidden(true)  
  win:SetHandler( "OnMoveStop", function() 
    SV.p.fateRealigned.posX = win:GetLeft() 
    SV.p.fateRealigned.posY = win:GetTop()
  end)

local frag = ZO_HUDFadeSceneFragment:New( win ) 
local isShowing = false
  local function SetScenes( showUi )
    if isShowing == showUi then return end 
    if showUi then 
      HUD_UI_SCENE:AddFragment( frag )
      HUD_SCENE:AddFragment( frag )
    else 
      HUD_UI_SCENE:RemoveFragment( frag )
      HUD_SCENE:RemoveFragment( frag )
    end
    isShowing = showUi
  end 

  local ctrl = WM:CreateControl( name.."_Ctrl", win, CT_CONTROL)
  ctrl:ClearAnchors() 
  ctrl:SetAnchor(CENTER, win, CENTER, 0, 0) 

  local coloredEdge = WM:CreateControl( name.."ColoredEdge", ctrl, CT_BACKDROP)
  coloredEdge:ClearAnchors() 
  coloredEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  coloredEdge:SetCenterColor(0,0,0,0)
  
  local outerEdge = WM:CreateControl( name.."OuterEdge", ctrl, CT_BACKDROP) 
  outerEdge:ClearAnchors() 
  outerEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  outerEdge:SetCenterColor(0,0,0,0)
  outerEdge:SetEdgeColor(0,0,0,1)

  local back = WM:CreateControl( name.."_Back", ctrl, CT_BACKDROP)
  back:ClearAnchors() 
  back:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  back:SetCenterColor(0,0,0)
  back:SetEdgeColor(0,0,0,1)
  back:SetEdgeTexture(nil, edgeLine, edgeLine, backgedgeLineroundEdge) 
  
  local icon = WM:CreateControl( name.."_Icon", ctrl, CT_TEXTURE) 
  icon:ClearAnchors()
  icon:SetAnchor(CENTER, ctrl, CENTER, 0, 0)
  icon:SetTexture( "esoui/art/icons/passive_arcanist_08.dds") 
  icon:SetColor(1,1,1,0.2)
  icon:SetDesaturation(0.5) 

  local label = WM:CreateControl( name.."_Label", ctrl, CT_LABEL)   
  label:ClearAnchors() 
  label:SetAnchor(CENTER, ctrl, CENTER, 0, 0) 
  label:SetVerticalAlignment( TEXT_ALIGN_CENTER )
  label:SetHorizontalAlignment( TEXT_ALIGN_CENTER )
  label:SetScale(2)


  local function UpdateDesign()
    --- size
    local iconSize = 3.2*SV.p.fateRealigned.size
    local coloredEdgeSize = 2^SV.p.fateRealigned.design.coloredEdgeSize
    local edgeSize = SV.p.fateRealigned.design.coloredEdgeEnabled and coloredEdgeSize or 0
    local totalSize = iconSize + 2*edgeSize + 2*edgeLine
    
    win:SetDimensions( totalSize, totalSize )
    outerEdge:SetDimensions( totalSize, totalSize )
    coloredEdge:SetDimensions( totalSize, totalSize )
    back:SetDimensions( 2*edgeLine+iconSize, 2*edgeLine+iconSize )
    icon:SetDimensions(iconSize, iconSize) 
    
    --- label 
    local fontData = {
      font = LibExoY.GetFontList()[SV.p.fateRealigned.font], 
      size = SV.p.fateRealigned.size, 
      outline = 2, 
    }
    label:SetFont( LibExoY.GetFont(fontData) ) 
    label:SetColor( unpack(SV.p.fateRealigned.colorLong) )

    --- background
    back:SetHidden(not SV.p.fateRealigned.design.iconEnabled)
    back:SetAlpha( SV.p.fateRealigned.design.backgroundAlpha ) 
    
    --- edge 
    outerEdge:SetHidden( not SV.p.fateRealigned.design.coloredEdgeEnabled)
    coloredEdge:SetHidden( not SV.p.fateRealigned.design.coloredEdgeEnabled)
    coloredEdge:SetEdgeTexture(nil,coloredEdgeSize,coloredEdgeSize,coloredEdgeSize)

    --- icon 
    icon:SetHidden( not SV.p.fateRealigned.design.iconEnabled )
    icon:SetAlpha( SV.p.fateRealigned.design.iconAlpha) 
    icon:SetDesaturation( SV.p.fateRealigned.design.iconDesaturation)
  end 


  local function SetDemoMode( demoMode ) 
    win:SetMouseEnabled( demoMode ) 
    win:SetMovable( demoMode )
  end

  UpdateDesign()
  return {UpdateDesign = UpdateDesign, SetScenes = SetScenes, SetDemoMode = SetDemoMode, label = label}
end


local function OnFateRealignedProc()
  d("Crux Tracker - FateRealignedProc) ")
  FateRealigned.active = true 
  FateRealigned.endTime = GetGameTimeMilliseconds() + GetAbilityCooldown(FateRealigned.procId)
end

local function OnFateRealignedUpdate() 
    --if not Spattering.active then return end
    local time = GetGameTimeMilliseconds()  

    local timeRemaining = math.floor((FateRealigned.endTime - time )/100) 
    local displayTime = zo_max(timeRemaining/10, 0) 
    local displayStr =  tostring(displayTime)
    if displayTime == 0 and not SV.p.fateRealigned.displayZero then displayStr = "" end

    Gui.fateRealigned.label:SetText( displayStr ) 

    if FateRealigned.endTime < time then 
      FateRealigned.active = false 
    end
end

local function StartTrackingFateRealigned() 
  EM:RegisterForEvent("CruxTracker_FateRealigned", EVENT_COMBAT_EVENT, OnFateRealignedProc) 
  EM:AddFilterForEvent("CruxTracker_FateRealigned", EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, FateRealigned.procId) 
  EM:AddFilterForEvent("CruxTracker_FateRealigned", EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE , COMBAT_UNIT_TYPE_PLAYER) 
  EM:AddFilterForEvent("CruxTracker_FateRealigned", EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT , ACTION_RESULT_EFFECT_GAINED) 
  Update:AddToList( "FateRealigned", OnFateRealignedUpdate) 
end 


local function StopTrackingFateRealigned() 
  EM:UnregisterForEvent("CruxTracker_FateRealigned", EVENT_COMBAT_EVENT)
  Update:RemoveFromList("FateRealigned") 
end

local function GetFateRealignedTrackerMenuControls() 
  local controls = {}
  table.insert(controls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.fateRealigned.enabled end, 
    setFunc = function(bool) 
      SV.p.fateRealigned.enabled = bool 
      SetVisibility() 
    end, 
  }) 

  table.insert( controls, {
    type = "header", 
    name = ECT_SETTING_INDICATOR, 
    width = "full", 
  })
  table.insert( controls, {
    type = "dropdown", 
    name = ECT_SETTING_FONT, 
    choices = LibExoY.GetFontList(), 
    getFunc = function() return LibExoY.GetFontList()[SV.p.fateRealigned.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(LibExoY.GetFontList() ) do 
        if selection == font then 
          SV.p.fateRealigned.font = idx
          break 
        end
      end
      Gui.fateRealigned.UpdateDesign() 
    end,
  })
  table.insert( controls, {
    type = "slider", 
    name = ECT_SETTING_SIZE, 
    min = 10, 
    max = 80, 
    step = 2, 
    getFunc = function() return SV.p.fateRealigned.size end, 
    setFunc = function( size ) 
      SV.p.fateRealigned.size = size 
      Gui.fateRealigned.UpdateDesign() 
    end
  })
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_DISPLAY_ZERO, 
    getFunc = function() return SV.p.fateRealigned.displayZero end,
    setFunc = function(bool) 
      SV.p.fateRealigned.displayZero = bool 
    end,
    })
    table.insert( controls, {
      type = "colorpicker", 
      name = ECT_SETTING_COLOR, 
      getFunc = function() return unpack(SV.p.fateRealigned.colorLong) end, 
      setFunc = function(r,g,b,a)
        SV.p.fateRealigned.colorLong = {r,g,b,a} 
      end, 
    })

  local advancedDesignControls = {} 
  table.insert(advancedDesignControls, {
    type = "header", 
    name = ECT_SETTING_ICON, 
  })
  table.insert(advancedDesignControls, {
    type = "checkbox", 
    name = ECT_SETTING_ENABLED, 
    getFunc = function() return SV.p.fateRealigned.design.iconEnabled end, 
    setFunc = function(bool)
      SV.p.fateRealigned.design.iconEnabled = bool
      Gui.fateRealigned.UpdateDesign()
    end, 
    width = "half"
  })

  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_BACK_ALPHA, 
    getFunc = function() return SV.p.fateRealigned.design.backgroundAlpha end, 
    setFunc = function(value) 
      SV.p.fateRealigned.design.backgroundAlpha = value
      Gui.fateRealigned.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_DESA, 
    getFunc = function() return SV.p.fateRealigned.design.iconDesaturation end, 
    setFunc = function(value) 
      SV.p.fateRealigned.design.iconDesaturation = value
      Gui.fateRealigned.UpdateDesign() 
    end,
    width = "half", 
  })
  table.insert(advancedDesignControls, { 
    type = "slider", 
    min = 0, 
    max = 1, 
    step = 0.1, 
    name = ECT_SETTING_ICON_ALPHA, 
    getFunc = function() return SV.p.fateRealigned.design.iconAlpha end, 
    setFunc = function(value) 
      SV.p.fateRealigned.design.iconAlpha = value
      Gui.fateRealigned.UpdateDesign() 
    end,
    width = "half", 
  })

  table.insert(controls, {
    type = "submenu", 
    name = ECT_SETTING_ADVANCED_DESIGN, 
    controls = advancedDesignControls,
  })

  return {
    type = "submenu", 
    name = LibExoY.AddIconToString("Fate Realigned", "esoui/art/icons/passive_arcanist_08.dds", 36, "front"),
    controls = controls
  }
end

--[[ ------------------ ]]
--[[ -- Crux Tracker -- ]]
--[[ ------------------ ]]

CruxTracker.hasCrux = false
CruxTracker.previousCrux = 0

function CruxTracker:SetCruxInfo( currentCrux, endTimeCrux )

  if currentCrux == 0 then  --- crux consumed/expired 
    self.hasCrux = false 
    self.endTime = 0
    SetVisibility()
    --PlayAudioCue("consumeCrux")
    Gui.symbolic.UpdateCrux( currentCrux )
    Gui.numeric.UpdateCrux( currentCrux )


  elseif  currentCrux == self.previousCrux then   --- crux wasted
    self.endTime = endTimeCrux or GetGameTimeSeconds() + cruxDuration/1000
    PlayAudioCue("wasteCrux")
    -- @idea: visual warning (red flash)

  else  --- crux generated
    self.hasCrux = true
    self.endTime = endTimeCrux or GetGameTimeSeconds() + cruxDuration/1000
    Gui.symbolic.UpdateCrux( currentCrux )
    Gui.numeric.UpdateCrux( currentCrux ) 
    PlayAudioCue( audioCueList[currentCrux].id )
    if currentCrux == 1 then SetVisibility() end
  end

  self.previousCrux = currentCrux 
end


function CruxTracker:ReadCharacterInfo() 
  local hasCrux = false
  local cruxAmount = 0
  local cruxEndTIme = 0  
  for i=1,GetNumBuffs("player") do
    local _,_,endTime,_,stackCount,_,_,_,_,_,abilityId = GetUnitBuffInfo("player", i)
    if abilityId == cruxId then 
        cruxAmount = stackCount
        cruxEndTIme = endTime
      break 
    end 
  end  
  self:SetCruxInfo(cruxAmount, cruxEndTIme) 

end


--[[ ------------ ]]
--[[ -- Update -- ]]
--[[ ------------ ]]

Update.numCallbacks = 0
Update.isRunning = false
Update.callList = {}

local function OnUpdate()   
  for name, callback in pairs(Update.callList) do 
    callback()
  end
end


function Update:AddToList( name, callback ) 
  if self.callList[name] then return end -- entry already exists
  self.callList[name] = callback
  self.numCallbacks = self.numCallbacks + 1

  if self.numCallbacks == 1 then 
    self:Start() 
  end
end 


function Update:RemoveFromList( name ) 
  if not self.callList[name] then return end -- entry does not exist
  self.callList[name] = nil 
  self.numCallbacks = self.numCallbacks -1 

  if self.numCallbacks == 0 then 
    self:Stop() 
  end
end


function Update:Start() 
  if not self.isRunning then 
    EM:RegisterForUpdate(idECT.."Update", 100, OnUpdate) 
  end
  self.isRunning = true; 
end


function Update:Stop() 
  if self.isRunning then 
    EM:UnregisterForUpdate(idECT.."Update") 
  end 
  self.isRunning = false;
end

--[[ ------------------------------- ]]
--[[ -- Activate/Deactivate Addon -- ]]
--[[ --   based on Skill-Lines    -- ]]
--[[ ------------------------------- ]]


local function WakeUp() 
  if not addonIsSleeping then return end    -- cant get any more awake
  Debug("Sensing Hermaeus Mora's Aura (Waking up)")
  addonIsSleeping = false 
  CruxTracker:ReadCharacterInfo() 
  if SV.p.timer.enabled then Update:AddToList("CruxTimer", Gui.timer.UpdateTime) end
  SetVisibility()
end

local function GoToSleep() 
  if addonIsSleeping then return end  -- dont need to poke a sleeping bear
  Debug("There is no knowledge in the void (Going to sleep)")
  addonIsSleeping = true 
  SetVisibility()
  CruxTracker:SetCruxInfo(0,0)
  Update:Stop() 
  Update.callList = {} 
end


local function CheckSkillLines() 
  hasArcanistSkillLine = false 
  for i=1,3 do
		if SKILLS_DATA_MANAGER:GetActiveClassSkillLine(i):GetClassId() == arcanistId then hasArcanistSkillLine = true end 
	end

  if hasArcanistSkillLine then 
    WakeUp()
  else 
    GoToSleep() 
  end
end


--[[ --------------------------------------- ]]
--[[ -- Initialization, Profiles and Menu -- ]]
--[[ --------------------------------------- ]]

local function GetMenuControls() 
  local controls = {}
  table.insert(controls, {
    type = "checkbox", 
    name = ECT_SETTING_UNLOCK_UI,
    getFunc = function() return uiIsUnlocked end, 
    setFunc = function(bool) 
      uiIsUnlocked = bool 
      SetDemoMode( bool )
      SetVisibility()
    end, 
  })
  table.insert( controls, {
    type = "divider"
  })
  -- Visibility 
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_HIDE_WHEN_ZERO_CRUX,
    getFunc = function() return SV.p.hideWhenNoCrux end,
    setFunc = function(bool) 
        SV.p.hideWhenNoCrux = bool
        SetVisibility()
      end
  })
  table.insert( controls, {
    type = "checkbox", 
    name = ECT_SETTING_SHOW_ALWAYS_IN_COMBAT,
    getFunc = function() return SV.p.showAlwaysInCombat end,
    setFunc = function(bool) 
        SV.p.showAlwaysInCombat = bool
        SetVisibility()
      end
  })
  -- Submenus
  table.insert(controls, GetNumericTrackerMenuControls() )
  table.insert(controls, GetSymbolicTrackerMenuControls() ) 
  table.insert(controls, GetAudioCueMenuControls() )
  table.insert(controls, GetCruxTimerMenuControls() )
  
  local cruxCreatorSubmenu = {}
  table.insert(cruxCreatorSubmenu, GetSpatteringTrackerMenuControls() )
  table.insert(cruxCreatorSubmenu, GetFateRealignedTrackerMenuControls() )
  table.insert(controls, {type = "submenu", name = "CruxCreators (Beta)", controls = cruxCreatorSubmenu}

  )

  return controls 
end


local function OnProfilChange() 
  GoToSleep() 
  CheckSkillLines()
end


local function ProfileDefaults() 
  return {
    showAlwaysInCombat = true, 
    hideWhenNoCrux = false, 
    symbolic = GetSymbolicTrackerSettingDefaults(),
    audioCue = GetAudioCueDefaults(), 
    numeric = GetNumericTrackerSettingDefaults(),
    timer = GetCruxTimerSettingsDefaults(),
    spattering = GetSpatteringTrackerSettingsDefaults(),
    fateRealigned = GetFateRealignedSettingsDefaults(),
  }
end


local function Initialize()

  ---[[ Saved Variables ]]
  local SavedVariablesParameter = {
    svName = "ExoYsCruxTrackerSavedVariables", 
    version = 2, 
    globalDefaults = { showDebug = false }, 
    profileDefaults = ProfileDefaults(), 
    dialogTitle = "ExoYs Crux Tracker", 
    callbacks = { OnProfileChange }, 
  }
  local profileMenu = nil
  SV, GetProfileSubmenu = LibExoY.LoadSavedVariables( SavedVariablesParameter )   

  ---[[ Addon Menu ]]
  local SettingsMenuParameter = {
      name = idECT,
      displayName = nameECT,
      version = versionECT,
      esoui = "info3619-ExoYsCruxTracker.html",
      profiles = GetProfileSubmenu(), 
      controls = GetMenuControls(),  
  } 
  LibExoY.CreateSettingsMenu( SettingsMenuParameter ) 

  Gui.symbolic = InitializeSymbolicTracker() 
  Gui.numeric = InitializeNumericTracker() 
  Gui.timer = InitializeCruxTimer()
  Gui.spattering = InitializeSpatteringTracker()
  Gui.fateRealigned = InitializeFateRealignedTracker()

  ---@todo investigate, i got an error from LSD line 1529 "function expected instead of nil", i suspect that an LSD function called to early but it doesnt make a lot of sence to me. --> the optional dependency is missing 
  if GetUnitClassId("player") == arcanistId then 
    if SV.p.spattering.enabled then 
      StartTrackingSpattering()
    end
    if SV.p.fateRealigned.enabled then 
      StartTrackingFateRealigned()
    end
  end
  
  LibExoY.RegisterCombatStart( function() SetVisibility() end )
  LibExoY.RegisterCombatEnd( function() SetVisibility() end )
  EM:RegisterForEvent(idECT.."PlayerActivated", EVENT_PLAYER_ACTIVATED, function() 
      CheckSkillLines() 
      EM:UnregisterForEvent( idECT.."PlayerActivated", EVENT_PLAYER_ACTIVATED )
      EM:RegisterForEvent( idECT.."PlayerActivated", EVENT_PLAYER_ACTIVATED , function() 
        CruxTracker:ReadCharacterInfo() -- ensure sync when crux fade while in loading screen
      end)
    end )
  EM:RegisterForEvent(idECT.."SkillsUpdated", EVENT_SKILLS_FULL_UPDATE, CheckSkillLines)

  EM:RegisterForEvent(idECT, EVENT_EFFECT_CHANGED, function(_, changeType, _, _, unitTag, _, _, stackCount) 
    if changeType == EFFECT_RESULT_FADED then 
      CruxTracker:SetCruxInfo( 0 ) -- crux consumed/expired
    else 
      CruxTracker:SetCruxInfo( stackCount )  
    end
  end )
  EM:AddFilterForEvent(idECT, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, cruxId)
  EM:AddFilterForEvent(idECT, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  EM:AddFilterForEvent(idECT, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
end


local function OnAddonLoaded(_, addonName)
  if addonName == idECT then
    EM:UnregisterForEvent(idECT, EVENT_ADD_ON_LOADED)
    Initialize()
  end
end
EM:RegisterForEvent(idECT, EVENT_ADD_ON_LOADED, OnAddonLoaded)


SLASH_COMMANDS["/ectdebug"] = function( )
  SV.g.showDebug = not SV.g.showDebug
  local debugStr = zo_strformat("Debug > <<1>>ctivated < ", SV.g.showDebug and "A" or "De-a" ) 
  LibExoY.Debug(debugStr, {"ECT", "green"}) 
end

SLASH_COMMANDS["/ect"] = function( )
  d(Spattering.heraldSkillNames) 
end