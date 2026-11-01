-- Standalone estimated corpse display with console/gamepad settings.
-- AI-assisted development: OpenAI Codex. In-game verification is still required.
local NAME = "SiphonZahl"
local EM = EVENT_MANAGER
local saved, frame, label, fragment, backdrop, moveHint, settingsPanel
local diagnosticFrame, diagnosticLabel, diagnosticFragment
local previewUntil = 0
local moving = false
local moveFragment
local lastTick = 0
local defaults = { x=0, y=100, size=76, locked=true, combatOnly=false, debugEnabled=false,
    rangeEnabled=true, radiusMeters=8 }

local function Apply()
    frame:ClearAnchors()
    frame:SetAnchor(CENTER, GuiRoot, CENTER, saved.x, saved.y)
    frame:SetDimensions(saved.size * 5, saved.size * 1.7)
    label:SetFont("$(BOLD_FONT)|" .. saved.size .. "|soft-shadow-thick")
    frame:SetMouseEnabled(moving or not saved.locked)
    frame:SetMovable(moving or not saved.locked)
    if backdrop then backdrop:SetHidden(not moving) end
    if moveHint then moveHint:SetHidden(not moving) end
    if fragment then fragment:Refresh() end
end

local function SetMoving(value)
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
    if moving and GetGamepadRightStickX and GetGamepadRightStickY then
        local x,y=GetGamepadRightStickX(true),GetGamepadRightStickY(true)
        if math.abs(x)>0.15 or math.abs(y)>0.15 then
            saved.x=math.max(-GuiRoot:GetWidth()/2+40, math.min(GuiRoot:GetWidth()/2-40,saved.x+x*500*delta))
            saved.y=math.max(-GuiRoot:GetHeight()/2+40, math.min(GuiRoot:GetHeight()/2-40,saved.y-y*500*delta))
            Apply()
        end
    end
    if fragment then fragment:Refresh() end
    if moveFragment then moveFragment.fragment:Refresh() end
    if diagnosticFragment then
        diagnosticFragment:Refresh()
        if not diagnosticFrame:IsHidden() then
            diagnosticLabel:SetText(SiphonZahlCounter.GetDiagnosticsText())
        end
    end
    if frame:IsHidden() then return end
    if moving or GetFrameTimeSeconds() < previewUntil then
        label:SetText("3")
        label:SetColor(0.3, 1, 0.55, 1)
        return
    end
    local count = SiphonZahlCounter and SiphonZahlCounter.Snapshot()
    if type(count) ~= "table" or type(count.total) ~= "number"
        or count.total ~= count.total or count.total < 0 or count.total == math.huge then
        label:SetText("?")
        label:SetColor(1, 0.75, 0.2, 1)
        return
    end
    local total = math.floor(count.total)
    local ambiguous = count.uncertain == true
        or (type(count.minimum) == "number" and count.minimum < total)
    label:SetText(tostring(total) .. (ambiguous and "?" or ""))
    if ambiguous then label:SetColor(1, 0.75, 0.2, 1)
    elseif total == 0 then label:SetColor(1, 0.25, 0.25, 1)
    else label:SetColor(0.3, 1, 0.55, 1) end
end

local function RegisterSettings()
    local H = LibHarvensAddonSettings
    if not H then return end
    settingsPanel = H:AddAddon("Siphon Zahl", { allowRefresh=true })
    settingsPanel:AddSettings({
        { type=H.ST_LABEL, label="Eigene Leichenschaetzung: Blastbones, Schaedel, Banner und erkannte Geist-/Skelettbeschwoerungen. Keine Zaehlung aller NPC-Leichen. ? = Verbrauch unsicher." },
        { type=H.ST_BUTTON, label="Anzeige verschieben", buttonText="Move UI",
          tooltip="Blendet den Verschieberahmen ein. Zum Beenden den Schalter Move UI / Anzeige verschieben ausschalten.",
          clickHandler=function() SetMoving(true); Update() end },
        { type=H.ST_CHECKBOX, label="Move UI / Anzeige verschieben",
          tooltip="Zeigt Rahmen und Beispielzahl. Mit rechtem Stick verschieben, danach Move UI ausschalten. Auf PC auch mit der Maus.",
          getFunction=function() return moving end,
          setFunction=function(value) SetMoving(value); Update() end, default=false },
        { type=H.ST_SLIDER, label="Groesse der Zahl", min=24, max=180, step=2, format="%d",
          getFunction=function() return saved.size end,
          setFunction=function(value) saved.size=value; Apply(); Update() end, default=76 },
        { type=H.ST_SLIDER, label="Position horizontal", min=-math.floor(GuiRoot:GetWidth()/2)+40,
          max=math.floor(GuiRoot:GetWidth()/2)-40, step=4, format="%d",
          getFunction=function() return saved.x end,
          setFunction=function(value) saved.x=value; Apply() end, default=0 },
        { type=H.ST_SLIDER, label="Position vertikal", min=-math.floor(GuiRoot:GetHeight()/2)+40,
          max=math.floor(GuiRoot:GetHeight()/2)-40, step=4, format="%d",
          getFunction=function() return saved.y end,
          setFunction=function(value) saved.y=value; Apply() end, default=100 },
        { type=H.ST_CHECKBOX, label="Nur im Kampf anzeigen",
          getFunction=function() return saved.combatOnly end,
          setFunction=function(value) saved.combatOnly=value; Update() end, default=false },
        { type=H.ST_CHECKBOX, label="Nur Leichen im Radius zaehlen",
          tooltip="Zaehlt nur erfasste eigene Leichen mit bekannter Position im eingestellten Radius. Leichen mit unbekannter Position werden ausgelassen. Kein Sichtliniencheck.",
          getFunction=function() return saved.rangeEnabled end,
          setFunction=function(value) saved.rangeEnabled=value; Update() end, default=true },
        { type=H.ST_SLIDER, label="Radius um deinen Charakter (Meter)",min=1,max=28,step=1,format="%d",
          tooltip="Standard 8 Meter entsprechend dem Banner-Radius. Bei abweichendem Banner-Tooltip den Wert hier anpassen.",
          getFunction=function() return saved.radiusMeters end,
          setFunction=function(value) saved.radiusMeters=value; Update() end,default=8 },
        { type=H.ST_CHECKBOX, label="Debug-Aufzeichnung",
          tooltip="Zeigt links oben eine Diagnose fuer Konsolentests und speichert bis zu 300 Ereignisse ohne Spielernamen. Standard: aus.",
          getFunction=function() return saved.debugEnabled end,
          setFunction=function(value) saved.debugEnabled=value; SiphonZahlCounter.ConfigureDiagnostics(saved) end,
          default=false },
        { type=H.ST_BUTTON, label="Beispielzahl anzeigen", buttonText="Vorschau",
          clickHandler=function() previewUntil=GetFrameTimeSeconds()+10; SetMoving(true); Update() end,
          tooltip="Aktiviert Move UI mit einer Beispielzahl. Danach Move UI ausschalten." },
        { type=H.ST_BUTTON, label="Position zuruecksetzen", buttonText="Bildschirmmitte",
          clickHandler=function() saved.x=0; saved.y=100; Apply(); SetMoving(true); Update() end },
        { type=H.ST_BUTTON, label="Alle Anzeigeeinstellungen", buttonText="Zuruecksetzen",
          clickHandler=function()
              for key, value in pairs(defaults) do saved[key]=value end
              previewUntil=0; SetMoving(false); Apply(); Update()
          end },
    })
end

local function Initialize(_, addonName)
    if addonName ~= NAME then return end
    EM:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    saved = ZO_SavedVars:NewAccountWide("SiphonZahlSaved", 1, nil, defaults)
    for _, key in ipairs({"x", "y", "size", "radiusMeters"}) do
        if type(saved[key]) ~= "number" or saved[key] ~= saved[key]
            or math.abs(saved[key]) == math.huge then saved[key] = defaults[key] end
    end
    saved.size = math.floor(math.max(24, math.min(180, saved.size)))
    saved.radiusMeters=math.max(1,math.min(28,saved.radiusMeters))
    for _, key in ipairs({"locked", "combatOnly", "debugEnabled", "rangeEnabled"}) do
        if type(saved[key]) ~= "boolean" then saved[key] = defaults[key] end
    end
    frame = WINDOW_MANAGER:CreateTopLevelWindow(NAME .. "Window")
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)
    frame:SetHandler("OnMoveStop", function(self)
        saved.x = self:GetLeft() + self:GetWidth()/2 - GuiRoot:GetWidth()/2
        saved.y = self:GetTop() + self:GetHeight()/2 - GuiRoot:GetHeight()/2
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
    moveHint = WINDOW_MANAGER:CreateControl(NAME .. "MoveHint", frame, CT_LABEL)
    moveHint:SetAnchor(BOTTOM, frame, TOP, 0, -4)
    moveHint:SetFont("ZoFontGame")
    moveHint:SetText("Siphon Zahl - rechter Stick / Move UI ausschalten zum Sperren")
    moveHint:SetMouseEnabled(false)
    fragment = ZO_HUDFadeSceneFragment:New(frame)
    fragment:SetConditional(function()
        return moving or GetFrameTimeSeconds() < previewUntil or
            (not IsUnitDead("player") and (not saved.combatOnly or IsUnitInCombat("player")))
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    diagnosticFrame=WINDOW_MANAGER:CreateTopLevelWindow(NAME.."Diagnostics")
    diagnosticFrame:SetDimensions(math.min(900,GuiRoot:GetWidth()-40),180)
    diagnosticFrame:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,20,120)
    diagnosticFrame:SetClampedToScreen(true)
    diagnosticFrame:SetMouseEnabled(false)
    diagnosticFrame:SetHidden(true)
    diagnosticLabel=WINDOW_MANAGER:CreateControl(NAME.."DiagnosticText",diagnosticFrame,CT_LABEL)
    diagnosticLabel:SetAnchorFill(diagnosticFrame)
    diagnosticLabel:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
    diagnosticLabel:SetColor(1,0.85,0.3,1)
    diagnosticLabel:SetMouseEnabled(false)
    diagnosticFragment=ZO_HUDFadeSceneFragment:New(diagnosticFrame)
    diagnosticFragment:SetConditional(function() return saved.debugEnabled end)
    HUD_SCENE:AddFragment(diagnosticFragment)
    HUD_UI_SCENE:AddFragment(diagnosticFragment)
    Apply()
    SiphonZahlCounter.ConfigureDiagnostics(saved)
    SiphonZahlCounter.Initialize()
    RegisterSettings()
    EM:RegisterForUpdate(NAME, 33, Update)
    Update()
end

EM:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, Initialize)
