

--[[ --------------- ]]
--[[ -- Variables -- ]]
--[[ --------------- ]]

local EM = GetEventManager() 
local WM = GetWindowManager()
local SV 

local ACTUtil = {}

local arcanistId = 117

local idECT = "AdvancedCruxTracker"
local nameECT = "Advanced Crux Tracker"
local versionECT = "2.1.0-console8"


-- Console position controls: gamepad users cannot drag HUD controls with a mouse.
local ECT_POSITION_WINDOWS = {
  { key = "numeric",    window = idECT.."NumericTrackerWindow" },
  { key = "timer",      window = idECT.."TimerWindow" },
  { key = "spattering", window = idECT.."SpatteringWindow" },
  { key = "fated",      window = idECT.."FatedFortuneWindow" },
}

local function ECT_SetWindowPosition(windowName, settings)
  local win = GetControl(windowName)
  if not win then return end
  win:ClearAnchors()
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.posX, settings.posY)
end

-- The Symbolic Tracker is the master anchor. Moving it moves every other tracker
-- by exactly the same delta while preserving each tracker's individual offset.
local function ECT_MoveSymbolicGroup(newX, newY)
  local oldX = SV.p.symbolic.posX or 0
  local oldY = SV.p.symbolic.posY or 0
  local dx, dy = newX - oldX, newY - oldY
  SV.p.symbolic.posX, SV.p.symbolic.posY = newX, newY
  ECT_SetWindowPosition(idECT.."SymbolicTrackerWindow", SV.p.symbolic)
  for _, item in ipairs(ECT_POSITION_WINDOWS) do
    local settings = SV.p[item.key]
    if settings then
      settings.posX = (settings.posX or oldX) + dx
      settings.posY = (settings.posY or oldY) + dy
      ECT_SetWindowPosition(item.window, settings)
    end
  end
end

local function ECT_UpdateWindowPosition(windowName, settings)
  if SV and settings == SV.p.symbolic then
    ECT_MoveSymbolicGroup(settings.posX, settings.posY)
  else
    ECT_SetWindowPosition(windowName, settings)
  end
end

local function ECT_AddPositionControls(controls, settings, windowName)
  local maxX = math.max(100, math.floor(GuiRoot:GetWidth()))
  local maxY = math.max(100, math.floor(GuiRoot:GetHeight()))
  table.insert(controls, { type = "header", name = "Position", width = "full" })
  table.insert(controls, {
    type = "slider", name = "Horizontal (X)", min = 0, max = maxX, step = 1,
    getFunc = function() return zo_clamp(settings.posX or 0, 0, maxX) end,
    setFunc = function(value) if SV and settings == SV.p.symbolic then ECT_MoveSymbolicGroup(value, settings.posY) else settings.posX = value; ECT_UpdateWindowPosition(windowName, settings) end end,
    width = "full",
  })
  table.insert(controls, {
    type = "slider", name = "Vertical (Y)", min = 0, max = maxY, step = 1,
    getFunc = function() return zo_clamp(settings.posY or 0, 0, maxY) end,
    setFunc = function(value) if SV and settings == SV.p.symbolic then ECT_MoveSymbolicGroup(settings.posX, value) else settings.posY = value; ECT_UpdateWindowPosition(windowName, settings) end end,
    width = "full",
  })
  table.insert(controls, {
    type = "button", name = "Center Position",
    func = function()
      local newX = math.floor(maxX / 2)
      local newY = math.floor(maxY / 2)
      if SV and settings == SV.p.symbolic then
        ECT_MoveSymbolicGroup(newX, newY)
      else
        settings.posX, settings.posY = newX, newY
        ECT_UpdateWindowPosition(windowName, settings)
      end
    end,
    width = "full",
  })
end

--[[ --------------------------------------------------------- ]]
--[[ -- Console/LAM compatibility    -- ]]
--[[ --------------------------------------------------------- ]]

local ECT_FONTS = {
  [1] = "Univers57", [2] = "Univers67", [3] = "ProseAntique", [4] = "Handwritten",
  [5] = "StoneTablet", [6] = "FuturaLight", [7] = "FuturaMedium", [8] = "FuturaBold",
}
local ECT_FONT_PATHS = {
  Univers57 = "EsoUI/Common/Fonts/Univers57.otf", Univers67 = "EsoUI/Common/Fonts/Univers67.otf",
  ProseAntique = "EsoUI/Common/Fonts/ProseAntiquePSMT.otf", Handwritten = "EsoUI/Common/Fonts/Handwritten_Bold.otf",
  StoneTablet = "EsoUI/Common/Fonts/TrajanPro-Regular.otf", FuturaLight = "EsoUI/Common/Fonts/FTN47.otf",
  FuturaMedium = "EsoUI/Common/Fonts/FTN57.otf", FuturaBold = "EsoUI/Common/Fonts/FTN87.otf",
}

function ACTUtil.GetFontList() return ZO_ShallowTableCopy(ECT_FONTS) end
function ACTUtil.GetFont(param)
  local data = { size = 18, font = ECT_FONTS[2], outline = "soft-shadow-thick" }
  if type(param) == "table" then data = param elseif type(param) == "number" then data.size = param end
  local path = ECT_FONT_PATHS[data.font] or ECT_FONT_PATHS.Univers67
  return string.format("%s|%d|%s", path, data.size or 18, data.outline or "soft-shadow-thick")
end
function ACTUtil.AddIconToString(str, icon, size, location)
  local iconStr = zo_strformat("|t<<2>>:<<2>>:<<1>>|t", icon, size or 36)
  if location == "back" then return zo_strformat("<<1>> <<2>>", str, iconStr) end
  return zo_strformat("<<1>> <<2>>", iconStr, str)
end
function ACTUtil.GetCountdownString(value, unit, decimal, notMilliseconds)
  local seconds = value * (notMilliseconds and 1 or 0.001)
  local digits = (seconds < 10 and decimal) and 1 or 0
  return string.format("%."..digits.."f%s", seconds, unit and "s" or "")
end
function ACTUtil.IsInCombat() return IsUnitInCombat("player") end
function ACTUtil.Debug(str, info, auth)
  if auth == false or type(str) ~= "string" or str == "" then return end
  local tag = info and info[1] or "ECT"
  d(zo_strformat("[<<1>>] <<2>>", tag, str))
end

local function ECT_CreateProfileSystem(par)
  local charId = tostring(GetCurrentCharacterId())
  local defaults = {
    globals = ZO_DeepTableCopy(par.globalDefaults or {}),
    profiles = { ZO_DeepTableCopy(par.profileDefaults or {}) },
    profileManager = { characterProfiles = {[charId] = 1}, profileNames = {"Default"}, profileNum = 1 },
  }
  local store = ZO_SavedVars:NewAccountWide(par.svName, par.version, nil, defaults)
  store.globals = store.globals or ZO_DeepTableCopy(par.globalDefaults or {})
  store.profiles = store.profiles or { ZO_DeepTableCopy(par.profileDefaults or {}) }
  store.profileManager = store.profileManager or { characterProfiles = {}, profileNames = {"Default"}, profileNum = 1 }
  local pm = store.profileManager
  pm.characterProfiles = pm.characterProfiles or {}
  pm.profileNames = pm.profileNames or {"Default"}
  pm.profileNum = #pm.profileNames
  if pm.profileNum < 1 then pm.profileNames={"Default"}; pm.profileNum=1; store.profiles={ZO_DeepTableCopy(par.profileDefaults)} end
  if not pm.characterProfiles[charId] or not store.profiles[pm.characterProfiles[charId]] then pm.characterProfiles[charId]=1 end
  local sv = {g=store.globals, p=store.profiles[pm.characterProfiles[charId]]}
  local editName = pm.profileNames[pm.characterProfiles[charId]]
  local function changed()
    if type(par.callbacks)=="table" then for _,cb in ipairs(par.callbacks) do if type(cb)=="function" then cb() end end end
  end
  local function setProfile(id)
    if not store.profiles[id] then return end
    pm.characterProfiles[charId]=id; sv.p=store.profiles[id]; editName=pm.profileNames[id]; changed()
  end
  local function currentId() return pm.characterProfiles[charId] or 1 end
  local function findName(name) for i,v in ipairs(pm.profileNames) do if v==name then return i end end end
  local function refreshChoices()
    local c=_G[par.svName.."_MENU_PROFILE_LIST"]; if c and c.UpdateChoices then c:UpdateChoices(pm.profileNames) end
  end
  local submenu = {
    type="submenu", name=function() return "Profiles: "..(pm.profileNames[currentId()] or "Default") end,
    controls={
      {type="dropdown", name="Select", choices=pm.profileNames, reference=par.svName.."_MENU_PROFILE_LIST",
       getFunc=function() return pm.profileNames[currentId()] end,
       setFunc=function(name) local id=findName(name); if id then setProfile(id) end end},
      {type="editbox", name="Profile name", getFunc=function() return editName or "" end, setFunc=function(v) editName=v end},
      {type="button", name="Rename current", func=function()
        if editName and editName~="" and not findName(editName) then pm.profileNames[currentId()]=editName; refreshChoices() end
      end},
      {type="button", name="Duplicate current", func=function()
        local n=#pm.profileNames+1; pm.profileNames[n]="Profile "..n; store.profiles[n]=ZO_DeepTableCopy(sv.p); pm.profileNum=n; refreshChoices(); setProfile(n)
      end},
      {type="button", name="New from defaults", func=function()
        local n=#pm.profileNames+1; pm.profileNames[n]="Profile "..n; store.profiles[n]=ZO_DeepTableCopy(par.profileDefaults); pm.profileNum=n; refreshChoices(); setProfile(n)
      end},
      {type="button", name="Delete current", isDangerous=true, warning="Delete the current profile?", func=function()
        local id=currentId()
        if #pm.profileNames<=1 then pm.profileNames[1]="Default"; store.profiles[1]=ZO_DeepTableCopy(par.profileDefaults); setProfile(1); return end
        table.remove(pm.profileNames,id); table.remove(store.profiles,id); pm.profileNum=#pm.profileNames
        for cid,pid in pairs(pm.characterProfiles) do if pid==id then pm.characterProfiles[cid]=1 elseif pid>id then pm.characterProfiles[cid]=pid-1 end end
        refreshChoices(); setProfile(1)
      end},
    }
  }
  return sv, function() return submenu end
end

function ACTUtil.LoadSavedVariables(par) return ECT_CreateProfileSystem(par) end
function ACTUtil.CreateSettingsMenu(param)
  local LAM = LibAddonMenu2
  if not LAM then d("[ECT] LibAddonMenu-2.0 is required."); return end
  local panel = {type="panel", name=param.displayName or param.name, displayName=param.displayName or param.name,
    author="ExoY (PC/EU), j.hhh", version=param.version.." Console-LAM v1", registerForRefresh=true, registerForUpdate=true}
  LAM:RegisterAddonPanel(param.name.."Menu", panel)
  local controls={}
  if param.profiles then table.insert(controls,param.profiles) end
  for _,v in ipairs(param.controls or {}) do table.insert(controls,v) end
  LAM:RegisterOptionControls(param.name.."Menu", controls)
end
function ACTUtil.RegisterCombatStart(callback)
  EM:RegisterForEvent(idECT.."CombatStart", EVENT_PLAYER_COMBAT_STATE, function(_,inCombat) if inCombat then callback() end end)
end
function ACTUtil.RegisterCombatEnd(callback)
  EM:RegisterForEvent(idECT.."CombatEnd", EVENT_PLAYER_COMBAT_STATE, function(_,inCombat) if not inCombat then callback() end end)
end


local cruxId = 184220
local cruxDuration = GetAbilityDuration( cruxId )

local Gui = {}
local CruxTracker = {} 
local Update = {}

local uiIsUnlocked = false 
local addonIsSleeping = true 

local function Debug(str) 
  ACTUtil.Debug(str, {"ECT", "green"}, SV.g.showDebug)  
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
  if Gui.fated then Gui.fated.SetScenes( false ) end
end 


local function ShowGui( showAll )
  Debug("ShowGui") 
  Gui.symbolic.SetScenes( showAll or SV.p.symbolic.enabled ) 
  Gui.numeric.SetScenes( showAll or SV.p.numeric.enabled )
  Gui.timer.SetScenes( showAll or SV.p.timer.enabled)
  Gui.spattering.SetScenes( showAll or SV.p.spattering.enabled )
  if Gui.fated then Gui.fated.SetScenes( showAll or SV.p.fated.enabled ) end
end


local function SetDemoMode( runDemo ) 
  Gui.symbolic.SetDemoMode( runDemo ) 
  Gui.numeric.SetDemoMode( runDemo ) 
  Gui.timer.SetDemoMode( runDemo ) 
  Gui.spattering.SetDemoMode( runDemo ) 
  if Gui.fated then Gui.fated.SetDemoMode( runDemo ) end
end


local function ECT_IsDisabledForCurrentCharacter()
  if not SV or not SV.g then return false end
  SV.g.disabledCharacters = SV.g.disabledCharacters or {}
  return SV.g.disabledCharacters[tostring(GetCurrentCharacterId())] == true
end

function SetVisibility() 
  Debug("Set Visibility")
  if ECT_IsDisabledForCurrentCharacter() then HideGui() return end
  if uiIsUnlocked then ShowGui( true ) return end 
  if addonIsSleeping then HideGui() return end 
  -- Console option: when enabled, the tracker is visible exclusively while in combat.
  -- This intentionally takes precedence over the zero-Crux visibility option.
  if SV.p.showAlwaysInCombat then
    if ACTUtil.IsInCombat() then ShowGui() else HideGui() end
    return
  end
  if CruxTracker.hasCrux then ShowGui() return end
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
    name = ACTUtil.AddIconToString(ECT_SETTING_AUDIO_CUE, "esoui/art/icons/achievement_u24_teaser_2.dds", 36, "front"), 
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
  ECT_AddPositionControls(controls, SV.p.symbolic, idECT.."SymbolicTrackerWindow") 
  table.insert(controls, { type = "description", text = "Master Position: Moving the Symbolic Tracker moves the Numeric Tracker, Crux Timer, Spattering Disjunction, and Fated Fortune by the same amount while preserving their individual offsets.", width = "full" })
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
    name = ACTUtil.AddIconToString(ECT_SETTING_SYMBOLIC_TRACKER, "esoui/art/icons/class_buff_arcanist_crux.dds", 36, "front"),
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
      font = ACTUtil.GetFontList()[SV.p.numeric.font], 
      size = SV.p.numeric.size, 
      outline = 2, 
    }
    label:SetFont( ACTUtil.GetFont(fontData) ) 

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
  ECT_AddPositionControls(controls, SV.p.numeric, idECT.."NumericTrackerWindow")
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
    choices = ACTUtil.GetFontList(), 
    getFunc = function() return ACTUtil.GetFontList()[SV.p.numeric.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(ACTUtil.GetFontList() ) do 
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
    name = ACTUtil.AddIconToString(ECT_SETTING_NUMERIC_TRACKER, "esoui/art/icons/ability_arcanist_001_blue.dds", 36, "front"),
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
      font = ACTUtil.GetFontList()[SV.p.timer.font], 
      size = SV.p.timer.size, 
      outline = 2, 
    }
    label:SetFont( ACTUtil.GetFont(fontData) ) 
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
      str = ACTUtil.GetCountdownString( timeRemaining, true, false, true)
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
  ECT_AddPositionControls(controls, SV.p.timer, idECT.."TimerWindow")
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
    choices = ACTUtil.GetFontList(), 
    getFunc = function() return ACTUtil.GetFontList()[SV.p.timer.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(ACTUtil.GetFontList() ) do 
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
    name = ACTUtil.AddIconToString(ECT_SETTING_CRUX_TIMER, "esoui/art/icons/u35_dun1_speed_challenge.dds", 36, "front"),
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
  labelName:SetFont(ACTUtil.GetFont(10))
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
      font = ACTUtil.GetFontList()[SV.p.spattering.font], 
      size = SV.p.spattering.size, 
      outline = 2, 
    }
    label:SetFont( ACTUtil.GetFont(fontData) ) 
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
  --    str = ACTUtil.GetCountdownString( timeRemaining, true, false, true)
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

  if Spattering.heraldSkillNames[abilityName] then 
    if Spattering.active and not Spattering.dmgCd then
      Spattering.dmgCd = true 
      Spattering.dmgCdEnd = GetGameTimeMilliseconds() + 1000 
      Spattering.endTime = Spattering.endTime - 500  
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
  ECT_AddPositionControls(controls, SV.p.spattering, idECT.."SpatteringWindow")
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
    choices = ACTUtil.GetFontList(), 
    getFunc = function() return ACTUtil.GetFontList()[SV.p.spattering.font] end, 
    setFunc = function( selection ) 
      for idx, font in ipairs(ACTUtil.GetFontList() ) do 
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
    name = ACTUtil.AddIconToString("Spattering Disjunction", "esoui/art/icons/ability_u45_dun2_b1_ricochet.dds", 36, "front"),
    controls = controls
  }
end



--[[ --------------------- ]]
--[[ -- Fated Fortune -- ]]
--[[ --------------------- ]]

local FatedFortune = { endTime = 0, active = false }
local FATED_FORTUNE_DURATION_MS = 7000

local function GetFatedFortuneSettingsDefaults()
  return {
    enabled = false,
    posX = 850,
    posY = 500,
    font = 1,
    size = 24,
    displayZero = false,
    colorLong = {0,1,0,1},
    design = {
      iconEnabled = true,
      iconAlpha = 0.3,
      iconDesaturation = 0.2,
      backgroundAlpha = 0.2,
      coloredEdgeEnabled = false,
      coloredEdgeSize = 4,
    },
  }
end

local function InitializeFatedFortuneTracker()
  local name = idECT.."FatedFortune"
  local edgeLine = 2
  local win = WM:CreateTopLevelWindow(name.."Window")
  win:ClearAnchors()
  win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.p.fated.posX, SV.p.fated.posY)
  win:SetMouseEnabled(false)
  win:SetMovable(false)
  win:SetClampedToScreen(true)
  win:SetDimensions(50,50)
  win:SetHidden(true)

  local frag = ZO_HUDFadeSceneFragment:New(win)
  local isShowing = false
  local function SetScenes(showUi)
    if isShowing == showUi then return end
    if showUi then HUD_UI_SCENE:AddFragment(frag); HUD_SCENE:AddFragment(frag)
    else HUD_UI_SCENE:RemoveFragment(frag); HUD_SCENE:RemoveFragment(frag) end
    isShowing = showUi
  end

  local ctrl = WM:CreateControl(name.."_Ctrl", win, CT_CONTROL)
  ctrl:SetAnchor(CENTER, win, CENTER, 0, 0)
  local coloredEdge = WM:CreateControl(name.."ColoredEdge", ctrl, CT_BACKDROP)
  coloredEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0); coloredEdge:SetCenterColor(0,0,0,0)
  local outerEdge = WM:CreateControl(name.."OuterEdge", ctrl, CT_BACKDROP)
  outerEdge:SetAnchor(CENTER, ctrl, CENTER, 0, 0); outerEdge:SetCenterColor(0,0,0,0); outerEdge:SetEdgeColor(0,0,0,1)
  local back = WM:CreateControl(name.."_Back", ctrl, CT_BACKDROP)
  back:SetAnchor(CENTER, ctrl, CENTER, 0, 0); back:SetCenterColor(0,0,0); back:SetEdgeColor(0,0,0,1); back:SetEdgeTexture(nil, edgeLine, edgeLine, edgeLine)
  local icon = WM:CreateControl(name.."_Icon", ctrl, CT_TEXTURE)
  icon:SetAnchor(CENTER, ctrl, CENTER, 0, 0)
  -- Fallback icon. The timer itself is driven by Crux generation/consumption, so it does not depend on an effect abilityId.
  icon:SetTexture("esoui/art/icons/class_buff_arcanist_crux.dds")
  local label = WM:CreateControl(name.."_Label", ctrl, CT_LABEL)
  label:SetAnchor(CENTER, ctrl, CENTER, 0, 0); label:SetVerticalAlignment(TEXT_ALIGN_CENTER); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER); label:SetScale(2)

  local function UpdateDesign()
    local iconSize = 3.2 * SV.p.fated.size
    local coloredEdgeSize = 2^SV.p.fated.design.coloredEdgeSize
    local edgeSize = SV.p.fated.design.coloredEdgeEnabled and coloredEdgeSize or 0
    local totalSize = iconSize + 2*edgeSize + 2*edgeLine
    win:SetDimensions(totalSize,totalSize); outerEdge:SetDimensions(totalSize,totalSize); coloredEdge:SetDimensions(totalSize,totalSize)
    back:SetDimensions(2*edgeLine+iconSize,2*edgeLine+iconSize); icon:SetDimensions(iconSize,iconSize)
    label:SetFont(ACTUtil.GetFont({font=ACTUtil.GetFontList()[SV.p.fated.font], size=SV.p.fated.size, outline=2}))
    label:SetColor(unpack(SV.p.fated.colorLong))
    back:SetHidden(not SV.p.fated.design.iconEnabled); back:SetAlpha(SV.p.fated.design.backgroundAlpha)
    outerEdge:SetHidden(not SV.p.fated.design.coloredEdgeEnabled); coloredEdge:SetHidden(not SV.p.fated.design.coloredEdgeEnabled)
    coloredEdge:SetEdgeTexture(nil,coloredEdgeSize,coloredEdgeSize,coloredEdgeSize)
    icon:SetHidden(not SV.p.fated.design.iconEnabled); icon:SetAlpha(SV.p.fated.design.iconAlpha); icon:SetDesaturation(SV.p.fated.design.iconDesaturation)
  end

  local function SetDemoMode(demoMode)
    win:SetMouseEnabled(demoMode); win:SetMovable(demoMode)
    if demoMode then label:SetText("7.0") end
  end
  UpdateDesign()
  return {UpdateDesign=UpdateDesign, SetScenes=SetScenes, SetDemoMode=SetDemoMode, label=label}
end

local function TriggerFatedFortune()
  if not SV or not SV.p.fated or not SV.p.fated.enabled then return end
  FatedFortune.endTime = GetGameTimeMilliseconds() + FATED_FORTUNE_DURATION_MS
  FatedFortune.active = true
  if Gui.fated then Gui.fated.SetScenes(true) end
end

local function OnFatedFortuneUpdate()
  local remaining = zo_max(FatedFortune.endTime - GetGameTimeMilliseconds(), 0)
  local displayTime = math.floor(remaining / 100) / 10
  local displayStr = tostring(displayTime)
  if displayTime == 0 and not SV.p.fated.displayZero then displayStr = "" end
  Gui.fated.label:SetText(displayStr)
  if remaining <= 0 then FatedFortune.active = false end
end

local function StartTrackingFatedFortune()
  Update:AddToList("FatedFortune", OnFatedFortuneUpdate)
end
local function StopTrackingFatedFortune()
  Update:RemoveFromList("FatedFortune")
  FatedFortune.active = false; FatedFortune.endTime = 0
  if Gui.fated then Gui.fated.label:SetText("") end
end

local function GetFatedFortuneMenuControls()
  local controls = {}
  ECT_AddPositionControls(controls, SV.p.fated, idECT.."FatedFortuneWindow")
  table.insert(controls, {type="checkbox", name=ECT_SETTING_ENABLED,
    getFunc=function() return SV.p.fated.enabled end,
    setFunc=function(bool) SV.p.fated.enabled=bool; if bool then StartTrackingFatedFortune() else StopTrackingFatedFortune() end; SetVisibility() end})
  table.insert(controls, {type="header", name=ECT_SETTING_INDICATOR, width="full"})
  table.insert(controls, {type="dropdown", name=ECT_SETTING_FONT, choices=ACTUtil.GetFontList(),
    getFunc=function() return ACTUtil.GetFontList()[SV.p.fated.font] end,
    setFunc=function(selection) for idx,font in ipairs(ACTUtil.GetFontList()) do if selection==font then SV.p.fated.font=idx; break end end; Gui.fated.UpdateDesign() end})
  table.insert(controls, {type="slider", name=ECT_SETTING_SIZE, min=10, max=80, step=2,
    getFunc=function() return SV.p.fated.size end, setFunc=function(v) SV.p.fated.size=v; Gui.fated.UpdateDesign() end})
  table.insert(controls, {type="checkbox", name=ECT_SETTING_DISPLAY_ZERO,
    getFunc=function() return SV.p.fated.displayZero end, setFunc=function(v) SV.p.fated.displayZero=v end})
  table.insert(controls, {type="colorpicker", name=ECT_SETTING_COLOR,
    getFunc=function() return unpack(SV.p.fated.colorLong) end, setFunc=function(r,g,b,a) SV.p.fated.colorLong={r,g,b,a}; Gui.fated.UpdateDesign() end})

  local adv = {}
  table.insert(adv, {type="header", name=ECT_SETTING_ICON})
  table.insert(adv, {type="checkbox", name=ECT_SETTING_ENABLED, width="half",
    getFunc=function() return SV.p.fated.design.iconEnabled end, setFunc=function(v) SV.p.fated.design.iconEnabled=v; Gui.fated.UpdateDesign() end})
  table.insert(adv, {type="slider", min=0,max=1,step=0.1,name=ECT_SETTING_BACK_ALPHA,width="half",
    getFunc=function() return SV.p.fated.design.backgroundAlpha end, setFunc=function(v) SV.p.fated.design.backgroundAlpha=v; Gui.fated.UpdateDesign() end})
  table.insert(adv, {type="slider", min=0,max=1,step=0.1,name=ECT_SETTING_ICON_DESA,width="half",
    getFunc=function() return SV.p.fated.design.iconDesaturation end, setFunc=function(v) SV.p.fated.design.iconDesaturation=v; Gui.fated.UpdateDesign() end})
  table.insert(adv, {type="slider", min=0,max=1,step=0.1,name=ECT_SETTING_ICON_ALPHA,width="half",
    getFunc=function() return SV.p.fated.design.iconAlpha end, setFunc=function(v) SV.p.fated.design.iconAlpha=v; Gui.fated.UpdateDesign() end})
  table.insert(controls, {type="submenu", name=ECT_SETTING_ADVANCED_DESIGN, controls=adv})
  return {type="submenu", name=ACTUtil.AddIconToString("Fated Fortune", "esoui/art/icons/class_buff_arcanist_crux.dds", 36, "front"), controls=controls}
end

--[[ ------------------ ]]
--[[ -- Crux Tracker -- ]]
--[[ ------------------ ]]

CruxTracker.hasCrux = false
CruxTracker.previousCrux = 0

function CruxTracker:SetCruxInfo( currentCrux, endTimeCrux )

  if currentCrux == 0 then  --- crux consumed/expired 
    local wasConsumed = self.previousCrux > 0 and self.endTime > (GetGameTimeSeconds() + 0.25)
    if wasConsumed then TriggerFatedFortune() end
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
    TriggerFatedFortune()
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
    name = "Disable addon for this character",
    tooltip = "Hides all Advanced Crux Tracker elements on the current character only. Other characters are not affected.",
    getFunc = function()
      SV.g.disabledCharacters = SV.g.disabledCharacters or {}
      return SV.g.disabledCharacters[tostring(GetCurrentCharacterId())] == true
    end,
    setFunc = function(bool)
      SV.g.disabledCharacters = SV.g.disabledCharacters or {}
      SV.g.disabledCharacters[tostring(GetCurrentCharacterId())] = bool or nil
      if bool then
        uiIsUnlocked = false
        SetDemoMode(false)
      end
      SetVisibility()
    end,
    width = "full",
  })
  table.insert(controls, { type = "divider" })
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
    fated = GetFatedFortuneSettingsDefaults(),
  }
end


local function Initialize()

  ---[[ Saved Variables ]]
  local SavedVariablesParameter = {
    svName = "AdvancedCruxTrackerSavedVariables", 
    version = 2, 
    globalDefaults = { showDebug = false, disabledCharacters = {} }, 
    profileDefaults = ProfileDefaults(), 
    dialogTitle = "Advanced Crux Tracker", 
    callbacks = { OnProfileChange }, 
  }
  SV, GetProfileSubmenu = ACTUtil.LoadSavedVariables( SavedVariablesParameter )   

  ---[[ Addon Menu ]]
  local SettingsMenuParameter = {
      name = idECT,
      displayName = nameECT,
      version = versionECT,
      controls = GetMenuControls(),  
  } 
  ACTUtil.CreateSettingsMenu( SettingsMenuParameter ) 

  Gui.symbolic = InitializeSymbolicTracker() 
  Gui.numeric = InitializeNumericTracker() 
  Gui.timer = InitializeCruxTimer()
  Gui.spattering = InitializeSpatteringTracker()
  Gui.fated = InitializeFatedFortuneTracker()

  if SV.p.spattering.enabled then 
    StartTrackingSpattering()
  end
  if SV.p.fated.enabled then
    StartTrackingFatedFortune()
  end
  
  ACTUtil.RegisterCombatStart( function() SetVisibility() end )
  ACTUtil.RegisterCombatEnd( function() SetVisibility() end )
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
  ACTUtil.Debug(debugStr, {"ECT", "green"}) 
end

SLASH_COMMANDS["/ect"] = function( )
  exoytestvar = Gui.spattering  ---@debug
end