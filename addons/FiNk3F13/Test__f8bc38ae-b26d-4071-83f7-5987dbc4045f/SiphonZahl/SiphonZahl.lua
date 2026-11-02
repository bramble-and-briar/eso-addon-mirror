-- Standalone estimated corpse display with console/gamepad settings.
-- AI-assisted development: OpenAI Codex. In-game verification is still required.
local NAME = "SiphonZahl"
local EM = EVENT_MANAGER
local saved, frame, label, fragment, backdrop, settingsPanel
local rangeHint
local moving = false
local moveFragment
local previousUIMode, previousCameraMode, lastMoveInput, dragging
local lastTick = 0
local defaults = { x=0, y=100, size=76, locked=true, combatOnly=false,
    colorR=0.3,colorG=1,colorB=0.55,colorA=1 }

local function ApplyNumberColor()
    label:SetColor(saved.colorR,saved.colorG,saved.colorB,saved.colorA)
end

local function FitNumber(text)
    frame:SetDimensions(math.max(label:GetStringWidth("00"),label:GetStringWidth(text))+12, saved.size*1.25+8)
end

local function SetNumberText(text)
    label:SetText(text)
    FitNumber(text)
end

local function Apply()
    frame:ClearAnchors()
    frame:SetAnchor(CENTER, GuiRoot, CENTER, saved.x, saved.y)
    label:SetFont("$(BOLD_FONT)|" .. saved.size .. "|soft-shadow-thick")
    FitNumber(label:GetText() or "00")
    frame:SetMouseEnabled(moving or not saved.locked)
    frame:SetMovable(moving or not saved.locked)
    if backdrop then backdrop:SetHidden(not moving) end
    if fragment then fragment:Refresh() end
end

local function SetMoving(value)
    if value == true and not moving then
        previousUIMode = SCENE_MANAGER.IsInUIMode and SCENE_MANAGER:IsInUIMode()
        previousCameraMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive()
        lastMoveInput = GetFrameTimeSeconds()
        if SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(true) end
        if SetGameCameraUIMode then SetGameCameraUIMode(true) end
    elseif value ~= true and moving then
        frame:StopMovingOrResizing()
        dragging=false
        if previousUIMode == false and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
        if previousCameraMode == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
        previousUIMode,previousCameraMode=nil,nil
    end
    moving = value == true
    saved.locked = not moving
    if moving then
        -- The ordinary HUD is hidden while the settings scene is open.
        -- A dedicated fragment makes the drag handle visible in that scene.
        local scene = SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
        if scene and scene ~= HUD_SCENE and scene ~= HUD_UI_SCENE then
            if moveFragment and moveFragment.scene ~= scene then
                moveFragment.scene:RemoveFragment(moveFragment.fragment)
                moveFragment = nil
            end
            if not moveFragment then
                local overlay = ZO_HUDFadeSceneFragment:New(frame)
                overlay:SetConditional(function() return moving end)
                scene:AddFragment(overlay)
                moveFragment = { scene=scene, fragment=overlay }
            end
        end
    elseif moveFragment then
        moveFragment.scene:RemoveFragment(moveFragment.fragment)
        moveFragment = nil
    end
    Apply()
    if moveFragment then moveFragment.fragment:Refresh() end
end

local function Update()
    local now=GetFrameTimeSeconds()
    local delta=math.min(0.1, math.max(0,now-lastTick));lastTick=now
    if moving then
        if SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(true) end
        if SetGameCameraUIMode then SetGameCameraUIMode(true) end
        local x=GetGamepadRightStickX and GetGamepadRightStickX(true) or 0
        local y=GetGamepadRightStickY and GetGamepadRightStickY(true) or 0
        if not dragging and (math.abs(x)>0.05 or math.abs(y)>0.05) then
            saved.x=math.max(-GuiRoot:GetWidth()/2+40, math.min(GuiRoot:GetWidth()/2-40,saved.x+x*500*delta))
            saved.y=math.max(-GuiRoot:GetHeight()/2+40, math.min(GuiRoot:GetHeight()/2-40,saved.y-y*500*delta))
            Apply()
            lastMoveInput=now
        end
        if dragging then lastMoveInput=now end
        if now-lastMoveInput>=3 then SetMoving(false) end
    end
    if fragment then fragment:Refresh() end
    if moveFragment then moveFragment.fragment:Refresh() end
    if frame:IsHidden() then return end
    rangeHint:SetHidden(true)
    if moving then
        SetNumberText("3")
        ApplyNumberColor()
        return
    end
    local count = SiphonZahlCounter and SiphonZahlCounter.Snapshot()
    if type(count) ~= "table" or type(count.total) ~= "number"
        or count.total ~= count.total or count.total < 0 or count.total == math.huge then
        SetNumberText("?")
        ApplyNumberColor()
        return
    end
    local total = math.floor(count.total)
    if count.directionUnknown then
        rangeHint:SetText("Blickrichtung unbekannt")
        rangeHint:SetHidden(false)
    elseif (count.rangeUnknown or 0)>0 then
        rangeHint:SetText(count.rangeFallback and "Entfernung unbekannt" or "Unbekannte Positionen ausgelassen")
        rangeHint:SetHidden(false)
    end
    local ambiguous = count.uncertain == true
        or (type(count.minimum) == "number" and count.minimum < total)
    SetNumberText(tostring(total) .. (ambiguous and "?" or ""))
    ApplyNumberColor()
end

local function RegisterSettings()
    local H = LibHarvensAddonSettings
    if not H then return end
    settingsPanel = H:AddAddon("Siphon Zahl", { allowRefresh=true })
    settingsPanel:AddSettings({
        { type=H.ST_LABEL, label="Ereigniszaehler eigener Sprengknochen-, Schaedel- und Skelett-Schuetzen-Leichen: identifizierte, tatsaechlich vorhandene tote Einheit und zugeordneter Siphon-Verbrauch. Kein angenommener Leichen-Timer. 90-Grad-Kegel, 11 Meter. Andere Quellen/Morphs und Gegnerleichen noch nicht bestaetigt. PC-Testdaten; PS5 noch zu pruefen." },
        { type=H.ST_BUTTON, label="Anzeige verschieben", buttonText="Move UI",
          tooltip="Mit rechtem Stick verschieben. Nach 3 Sekunden ohne Eingabe automatisch sperren.",
          clickHandler=function() SetMoving(not moving); Update() end },
        { type=H.ST_SLIDER, label="Groesse der Zahl", min=24, max=180, step=2, format="%d",
          getFunction=function() return saved.size end,
          setFunction=function(value) saved.size=value; Apply(); Update() end, default=76 },
        { type=H.ST_COLOR, label="Farbe der Zahl",
          getFunction=function() return saved.colorR,saved.colorG,saved.colorB,saved.colorA end,
          setFunction=function(r,g,b,a)
              saved.colorR=r;saved.colorG=g;saved.colorB=b;saved.colorA=a or 1
              Update()
          end,default={0.3,1,0.55,1} },
        { type=H.ST_CHECKBOX, label="Nur im Kampf anzeigen",
          getFunction=function() return saved.combatOnly end,
          setFunction=function(value) saved.combatOnly=value; Update() end, default=false },
        { type=H.ST_BUTTON, label="Position zuruecksetzen", buttonText="Bildschirmmitte",
          clickHandler=function() saved.x=0; saved.y=100; Apply(); SetMoving(true); Update() end },
        { type=H.ST_BUTTON, label="Alle Anzeigeeinstellungen", buttonText="Zuruecksetzen",
          clickHandler=function()
              for key, value in pairs(defaults) do saved[key]=value end
              SetMoving(false); Apply(); Update()
          end },
    })
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("SiphonZahlSaved", 1, nil, defaults)
    for _, key in ipairs({"x", "y", "size"}) do
        if type(saved[key]) ~= "number" or saved[key] ~= saved[key]
            or math.abs(saved[key]) == math.huge then saved[key] = defaults[key] end
    end
    saved.size = math.floor(math.max(24, math.min(180, saved.size)))
    for _,key in ipairs({"colorR","colorG","colorB","colorA"}) do
        if type(saved[key])~="number" or saved[key]~=saved[key]
            or saved[key]<0 or saved[key]>1 then saved[key]=defaults[key] end
    end
    for _, key in ipairs({"locked", "combatOnly"}) do
        if type(saved[key]) ~= "boolean" then saved[key] = defaults[key] end
    end
    saved.rangeEnabled=nil; saved.radiusMeters=nil; saved.estimateUnknown=nil
    saved.debugEnabled=nil; saved.debugLog=nil; saved.locked=true
    frame = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Window")
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)
    frame:SetHandler("OnMouseDown",function(self,button)
        if moving and button==MOUSE_BUTTON_INDEX_LEFT then
            dragging=true;lastMoveInput=GetFrameTimeSeconds();self:StartMoving()
        end
    end)
    frame:SetHandler("OnMouseUp",function(self,button)
        if dragging and button==MOUSE_BUTTON_INDEX_LEFT then
            self:StopMovingOrResizing();dragging=false;lastMoveInput=GetFrameTimeSeconds()
        end
    end)
    frame:SetHandler("OnMoveStop", function(self)
        saved.x = self:GetLeft() + self:GetWidth()/2 - GuiRoot:GetWidth()/2
        saved.y = self:GetTop() + self:GetHeight()/2 - GuiRoot:GetHeight()/2
        lastMoveInput=GetFrameTimeSeconds()
    end)
    label = WINDOW_MANAGER:CreateControl(NAME .. "Number", frame, CT_LABEL)
    label:SetAnchorFill(frame)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetMouseEnabled(false)
    backdrop = WINDOW_MANAGER:CreateControl(NAME .. "MoveFrame", frame, CT_BACKDROP)
    backdrop:SetAnchorFill(frame)
    backdrop:SetCenterColor(0.02, 0.06, 0.07, 0.65)
    backdrop:SetEdgeColor(0.3, 1, 0.55, 1)
    backdrop:SetEdgeTexture("", 1, 1, 2)
    backdrop:SetMouseEnabled(false)
    backdrop:SetDrawLevel(0)
    label:SetDrawLevel(2)
    rangeHint=WINDOW_MANAGER:CreateControl(NAME.."RangeHint",frame,CT_LABEL)
    rangeHint:SetAnchor(TOP,frame,BOTTOM,0,2)
    rangeHint:SetDimensions(420,32)
    rangeHint:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    rangeHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    rangeHint:SetColor(1,0.75,0.2,1)
    rangeHint:SetMouseEnabled(false)
    rangeHint:SetHidden(true)
    fragment = ZO_HUDFadeSceneFragment:New(frame)
    fragment:SetConditional(function()
        return moving or
            (not IsUnitDead("player") and (not saved.combatOnly or IsUnitInCombat("player")))
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    Apply()
    SiphonZahlCounter.Initialize()
    RegisterSettings()
    EM:RegisterForUpdate(NAME, 33, Update)
    Update()
end

EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
