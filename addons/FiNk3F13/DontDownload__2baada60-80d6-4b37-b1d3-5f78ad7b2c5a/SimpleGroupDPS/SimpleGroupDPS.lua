local L = SimpleGroupDPS_Translate or function(text) return text end
local ADDON_NAME = "SimpleGroupDPS"
local ADDON_VERSION = "1.9.21"
local UPDATE_INTERVAL_MS = 300
local wm = WINDOW_MANAGER
local meter, bridge, panel = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls, SimpleGroupDPS_DPSPanel
local defaults = {
    showGroup = true, showTanks = true, showHealers = true, showPersonal = true,
    posX = 720, posY = 300, scale = 1,
    dpsWidth = 400, dpsFontSize = 22, dpsRowSpacing = 8, lastSummary = {},
    lingerSeconds = 60,
}
local settings, window, personalWindow, moveHint, moveOverlay
local personalPanel = SimpleGroupDPS_PersonalDPSPanel
local moveWindow
local settingsPanel
local moveMode = false
local moveLastInputAt, moveLastX, moveLastY
local moveDragging = false
local previousUIMode, previousCameraMode
local updateUI, tick
local lastResultAt
local lastTickAt, tickCount = nil, 0

local function retentionSeconds(value)
    return math.max(60, math.min(300, math.ceil((tonumber(value) or 60) / 60) * 60))
end

local function hudVisible()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetCurrentScene then return true end
    local scene = SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene:GetName()
    return name == "hud" or name == "hudui"
end

-- Follow Harvens' selected panel/section; preview never starts movement or combat.
local function settingsPreview()
    local lib = LibHarvensAddonSettings
    if not settingsPanel or not settingsPanel.selected then return false, false end
    if lib.scene then
        if not SCENE_MANAGER or SCENE_MANAGER:GetCurrentScene() ~= lib.scene then return false, false end
        local section = lib.list and lib.list.currentSection
        local label = section and section.labelText
        return label == L("DPS-HUD") or label == L("Allgemein"),
            label == L("Gruppenanteil-HUD") or label == L("Allgemein")
    end
    if lib.container and lib.container.IsHidden and not lib.container:IsHidden() then return true, true end
    return false, false
end

local function savePosition(control)
    control = control or window
    local xKey = control == personalWindow and "personalPosX" or "posX"
    local yKey = control == personalWindow and "personalPosY" or "posY"
    settings[xKey] = math.floor(control:GetLeft() + 0.5)
    settings[yKey] = math.floor(control:GetTop() + 0.5)
end

local function refreshAnchor(control)
    control = control or window
    local x = control == personalWindow and settings.personalPosX or settings.posX
    local y = control == personalWindow and settings.personalPosY or settings.posY
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

local function refreshUpdateLoop()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."UI")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."UI", UPDATE_INTERVAL_MS, tick)
end

local function setMoveMode(enabled, requestedWindow)
    enabled = enabled and true or false
    if enabled and moveMode and requestedWindow and requestedWindow ~= moveWindow then setMoveMode(false) end
    local target = (enabled and requestedWindow) or moveWindow or window
    local xKey = target == personalWindow and "personalPosX" or "posX"
    local yKey = target == personalWindow and "personalPosY" or "posY"
    if moveMode == enabled then
        if enabled then moveLastInputAt = GetGameTimeMilliseconds() end
        return
    end
    moveMode = enabled
    moveWindow = enabled and target or nil
    target:SetMovable(enabled)
    target:SetMouseEnabled(enabled)
    moveHint:SetHidden(not enabled)
    moveOverlay:SetHidden(not enabled)
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."Move")
    if enabled then
        moveLastInputAt = GetGameTimeMilliseconds()
        moveLastX, moveLastY = target:GetLeft(), target:GetTop()
        moveDragging = false
        if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode then
            previousUIMode = SCENE_MANAGER:IsInUIMode()
            SCENE_MANAGER:SetInUIMode(true)
        end
        if SetGameCameraUIMode then
            previousCameraMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive() or false
            SetGameCameraUIMode(true)
        end
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."Move", 16, function()
            local now = GetGameTimeMilliseconds()
            local left, top = target:GetLeft(), target:GetTop()
            if moveDragging or left ~= moveLastX or top ~= moveLastY then
                moveLastInputAt = now
                savePosition(target)
            end
            if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode and not SCENE_MANAGER:IsInUIMode() then
                SCENE_MANAGER:SetInUIMode(true)
            end
            if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then
                SetGameCameraUIMode(true)
            end
            local x = GetGamepadRightStickX and GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE) or 0
            local y = GetGamepadRightStickY and GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
            if not moveDragging and (math.abs(x) >= 0.05 or math.abs(y) >= 0.05) then
                settings[xKey] = math.max(0, math.min(math.max(0, GuiRoot:GetWidth() - target:GetWidth()), left + x * 22))
                settings[yKey] = math.max(0, math.min(math.max(0, GuiRoot:GetHeight() - target:GetHeight()), top - y * 22))
                refreshAnchor(target)
                savePosition(target)
                moveLastInputAt = now
            end
            moveLastX, moveLastY = target:GetLeft(), target:GetTop()
            if now - moveLastInputAt >= 3000 then setMoveMode(false) end
        end)
    else
        target:StopMovingOrResizing()
        savePosition(target)
        moveDragging = false
        if previousUIMode == false and SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
        if previousCameraMode == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
        previousUIMode, previousCameraMode = nil, nil
    end
    if not meter:IsActive() then refreshUpdateLoop() end
    updateUI()
end

updateUI = function(sceneVisible, snapshot)
    if type(sceneVisible) ~= "boolean" then sceneVisible = hudVisible() end
    local retentionMS = retentionSeconds(settings.lingerSeconds) * 1000
    if not meter:IsActive() then
        if lastResultAt and GetGameTimeMilliseconds() - lastResultAt >= retentionMS then
            meter:ClearResult()
            settings.lastSummary = {}
            lastResultAt, snapshot = nil, nil
        end
        bridge:Expire(retentionMS)
    end
    local stats = snapshot or meter:GetStats()
    local groupPreview, personalPreview = settingsPreview()
    local personalMoving = moveMode and moveWindow == personalWindow
    local groupMoving = moveMode and moveWindow == window
    personalPanel:Render(personalWindow, stats, personalMoving or (personalPreview and settings.showPersonal ~= false)
        or (settings.showPersonal ~= false and sceneVisible and (meter:IsActive() or stats.total > 0)))
    if not groupMoving and not groupPreview and not sceneVisible then window:SetHidden(true); return end
    local rows = settings.showGroup and bridge:GetRows() or {}
    if groupMoving or groupPreview or meter:IsActive() or stats.total > 0 or (stats.rawHealingTotal or 0) > 0 or #rows > 0 then
        rows[#rows + 1] = {
            name = GetUnitDisplayName("player"), dps = stats.dps,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, isPlayer = true,
            rawHPS = stats.rawHPS, effectiveHPS = stats.effectiveHPS,
            role = GetSelectedLFGRole and GetSelectedLFGRole(),
            -- Same automatic classification as BattleScrolls' classifyData.
            messageType = (stats.rawHPS or 0) > (stats.dps or 0) and "healing" or "damage",
            classId = GetUnitClassId and GetUnitClassId("player"),
        }
    end
    -- Role filters affect only the rendered rows, never the meter or sender.
    -- Move UI keeps a preview available even if every current role is hidden.
    if not groupMoving then
        local visibleRows = {}
        for _, member in ipairs(rows) do
            local tank = LFG_ROLE_TANK ~= nil and member.role == LFG_ROLE_TANK
            local healer = LFG_ROLE_HEAL ~= nil and member.role == LFG_ROLE_HEAL
            local knownDamageRole = tank or (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS)
            if not knownDamageRole and (member.displayType or member.messageType) == "healing" then healer = true end
            if not (tank and settings.showTanks == false) and not (healer and settings.showHealers == false) then
                visibleRows[#visibleRows + 1] = member
            end
        end
        rows = visibleRows
    end
    -- Shared DPS packets do not identify the sender's encounter.
    local bossFight = stats.bossDPS ~= nil
    local height = panel:Render(window, rows, bossFight, stats.durationMS, settings, stats)
    window:SetDimensions(panel:GetWidth(settings), math.max(40, height))
    window:SetHidden(not groupMoving and #rows == 0)
end

tick = function()
    lastTickAt = GetGameTimeMilliseconds()
    tickCount = tickCount + 1
    -- Receiving must also connect while idle, without waiting for our first attack.
    bridge:Connect()
    -- Display and share the same independently measured snapshot.
    local stats = meter:GetStats()
    if meter:IsActive() then bridge:SendMetrics(stats, false) end
    SimpleGroupDPS_MeasurementComparison:Capture(false)
    updateUI(nil, stats)
end

local function configureMovement(control)
    control:SetHandler("OnMouseDown", function(control, button)
        if moveMode and moveWindow == control and button == MOUSE_BUTTON_INDEX_LEFT then
            moveDragging = true
            moveLastInputAt = GetGameTimeMilliseconds()
            control:StartMoving()
        end
    end)
    control:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
            moveDragging = false
            moveLastInputAt = GetGameTimeMilliseconds()
            savePosition(control)
        end
    end)
    control:SetHandler("OnMoveStop", function()
        moveDragging = false
        moveLastInputAt = GetGameTimeMilliseconds()
        savePosition(control)
    end)
end

local function createUI()
    window = wm:CreateTopLevelWindow(ADDON_NAME.."Window")
    window:SetDimensions(panel:GetWidth(settings), 100)
    window:SetScale(settings.scale)
    window:SetClampedToScreen(true)
    window:SetHidden(true)
    window:SetMovable(false)
    window:SetMouseEnabled(false)
    refreshAnchor()
    configureMovement(window)
    personalWindow = personalPanel:Create()
    personalWindow:SetScale(settings.personalScale)
    settings.personalPosX = tonumber(settings.personalPosX) or 32
    settings.personalPosY = tonumber(settings.personalPosY) or math.max(0, GuiRoot:GetHeight() - personalWindow:GetHeight() - 80)
    refreshAnchor(personalWindow)
    configureMovement(personalWindow)
    moveOverlay = wm:CreateTopLevelWindow(ADDON_NAME.."MoveOverlay")
    moveOverlay:SetAnchorFill(GuiRoot)
    moveOverlay:SetMouseEnabled(false)
    moveOverlay:SetDrawLayer(DL_OVERLAY)
    moveOverlay:SetDrawTier(DT_HIGH)
    moveOverlay:SetHidden(true)
    local dim = wm:CreateControl(nil, moveOverlay, CT_BACKDROP)
    dim:SetAnchorFill(moveOverlay)
    dim:SetCenterColor(0, 0, 0, 0.10)
    dim:SetEdgeColor(0, 0, 0, 0)
    for _, offset in ipairs({ -220, 0, 220 }) do
        for _, horizontal in ipairs({ true, false }) do
            local line = wm:CreateControl(nil, moveOverlay, CT_BACKDROP)
            line:SetAnchor(CENTER, moveOverlay, CENTER, horizontal and 0 or offset, horizontal and offset or 0)
            line:SetDimensions(horizontal and GuiRoot:GetWidth() or (offset == 0 and 2 or 1),
                horizontal and (offset == 0 and 2 or 1) or GuiRoot:GetHeight())
            line:SetCenterColor(1, 1, 1, offset == 0 and 0.45 or 0.18)
            line:SetEdgeColor(0, 0, 0, 0)
        end
    end
    moveHint = wm:CreateTopLevelWindow(ADDON_NAME.."MoveHint")
    moveHint:SetDimensions(700, 50)
    moveHint:SetAnchor(TOP, GuiRoot, TOP, 0, 70)
    moveHint:SetDrawLayer(DL_OVERLAY)
    moveHint:SetMouseEnabled(false)
    moveHint:SetHidden(true)
    local label = wm:CreateControl(nil, moveHint, CT_LABEL)
    label:SetAnchorFill(moveHint)
    label:SetFont("$(BOLD_FONT)|24|soft-shadow-thick")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(L("SimpleGroupDPS: mit Maus oder rechtem Stick verschieben\nSpeichert nach 3 Sekunden ohne Bewegung"))
end

local function resetPosition(target)
    if moveMode and moveWindow == target then setMoveMode(false) end
    local personal = target == personalWindow
    local xKey, yKey = personal and "personalPosX" or "posX", personal and "personalPosY" or "posY"
    local maxX = math.max(0, GuiRoot:GetWidth() - target:GetWidth())
    local maxY = math.max(0, GuiRoot:GetHeight() - target:GetHeight())
    settings[xKey] = math.min(personal and 32 or defaults.posX, maxX)
    settings[yKey] = personal and math.max(0, maxY - 80) or math.min(defaults.posY, maxY)
    refreshAnchor(target)
    updateUI()
end

local function initSettings()
    local LHAS = LibHarvensAddonSettings
    local addon = LHAS:AddAddon(ADDON_NAME, { allowRefresh = true })
    addon.version = ADDON_VERSION
    settingsPanel = addon
    local retentionItems = {}
    for minutes = 1, 5 do
        retentionItems[minutes] = {name = minutes == 1 and L("1 Minute") or (minutes .. L(" Minuten")), data = minutes * 60}
    end
    addon:AddSettings({
        { type = LHAS.ST_LABEL, label = L("Autor: FiNk3--F13--") },
        { type = LHAS.ST_SECTION, label = L("DPS-HUD") },
        { type = LHAS.ST_BUTTON, label = "Move UI", buttonText = L("DPS-Anzeige verschieben"),
          tooltip = L("Mit Maus oder rechtem Stick verschieben. Speichert und endet nach 3 Sekunden ohne Bewegung."),
          clickHandler = function() setMoveMode(true, window) end },
        { type = LHAS.ST_BUTTON, label = L("DPS-HUD-Position zurücksetzen"), buttonText = L("Position zurücksetzen"),
          tooltip = L("Setzt nur die Position dieses HUDs zurück. Größe und Darstellung bleiben erhalten."),
          clickHandler = function() resetPosition(window) end },
        { type = LHAS.ST_SLIDER, label = L("HUD-Gesamtgröße"), min = 50, max = 150, step = 5,
          tooltip = L("Skaliert das gesamte HUD gemeinsam: Namen, Zahlen, Balken, Fensterbreite und Abstände. Kleinere Werte machen die Anzeige kleiner und enger."),
          getFunction = function() return math.floor(settings.scale * 100 + 0.5) end,
          setFunction = function(value)
              settings.scale = math.max(0.5, math.min(1.5, (tonumber(value) or 100) / 100))
              window:SetScale(settings.scale)
              refreshAnchor()
              updateUI()
          end },
        { type = LHAS.ST_SLIDER, label = L("DPS-Zahlengröße"), min = 14, max = 32, step = 1,
          tooltip = L("Verändert die DPS-Zahlen und die Summe. Namen und Gesamtskalierung bleiben gleich. Größere Zahlen erhalten bei Bedarf mehr Zeilenhöhe. Für lange Boss-/Gesamtwerte die Fensterbreite erhöhen."),
          getFunction = function() return panel:GetValueFontSize(settings) end,
          setFunction = function(value) settings.dpsValueFontSize = value; updateUI() end },
        { type = LHAS.ST_SLIDER, label = L("Fensterbreite"), min = 280, max = 400, step = 10,
          tooltip = L("Kleinere Werte ziehen Namen und DPS enger zusammen. Lange Namen werden gekürzt; zu breite Zahlen passend verkleinert."),
          getFunction = function() return settings.dpsWidth end,
          setFunction = function(value) settings.dpsWidth = panel:GetWidth({dpsWidth = value}); updateUI() end },
        { type = LHAS.ST_SLIDER, label = L("Zeilenabstand"), min = 0, max = 16, step = 1,
          tooltip = L("Kleinere Werte rücken die Spielerzeilen näher zusammen. Die Schrift bleibt gleich groß."),
          getFunction = function() return settings.dpsRowSpacing end,
          setFunction = function(value) settings.dpsRowSpacing = value; updateUI() end },
        { type = LHAS.ST_CHECKBOX, label = L("Tanks anzeigen"),
          tooltip = L("Zeigt Spieler mit Tankrolle an, einschließlich dir selbst. Messung und Empfang laufen auch ausgeblendet weiter. Die lokal gemessene Gruppensumme bleibt vollständig."),
          getFunction = function() return settings.showTanks ~= false end,
          setFunction = function(value) settings.showTanks = value and true or false; updateUI() end },
        { type = LHAS.ST_CHECKBOX, label = L("Heiler anzeigen"),
          tooltip = L("Zeigt Spieler mit Heilerrolle und den Heilungsbereich an, einschließlich dir selbst. Messung und Empfang laufen auch ausgeblendet weiter."),
          getFunction = function() return settings.showHealers ~= false end,
          setFunction = function(value) settings.showHealers = value and true or false; updateUI() end },
        { type = LHAS.ST_BUTTON, label = L("Layout zurücksetzen"), buttonText = L("Standardlayout"),
          tooltip = L("Setzt DPS-Zahlengröße, Fensterbreite und Zeilenabstand zurück. Position, Namensgröße und Gesamtskalierung bleiben erhalten."),
          clickHandler = function()
              settings.dpsWidth, settings.dpsRowSpacing = defaults.dpsWidth, defaults.dpsRowSpacing
              settings.dpsValueFontSize = panel:GetValueFontSize(defaults)
              updateUI()
          end },
        { type = LHAS.ST_SECTION, label = L("Gruppenanteil-HUD") },
        { type = LHAS.ST_CHECKBOX, label = L("Anteil-HUD anzeigen"),
          tooltip = L("Blendet das persönliche DPS-/Anteil-HUD ein oder aus. Gruppenanzeige, Messung und Empfang laufen weiter."),
          getFunction = function() return settings.showPersonal ~= false end,
          setFunction = function(value) settings.showPersonal = value and true or false; updateUI() end },
        { type = LHAS.ST_BUTTON, label = L("Anteil-HUD verschieben"), buttonText = L("Eigenen Gruppenanteil verschieben"),
          tooltip = L("Verschiebt das separate DPS-/Anteil-HUD mit Maus oder rechtem Stick. Speichert nach 3 Sekunden ohne Bewegung."),
          clickHandler = function() setMoveMode(true, personalWindow) end },
        { type = LHAS.ST_BUTTON, label = L("Gruppenanteil-HUD-Position zurücksetzen"), buttonText = L("Position zurücksetzen"),
          tooltip = L("Setzt nur die Position dieses HUDs zurück. Größe und Darstellung bleiben erhalten."),
          clickHandler = function() resetPosition(personalWindow) end },
        { type = LHAS.ST_SLIDER, label = L("Anteil-HUD-Größe"), min = 50, max = 200, step = 5,
          tooltip = L("Vergrößert oder verkleinert nur das persönliche DPS-/Anteil-HUD. Die Gruppenanzeige bleibt gleich."),
          getFunction = function() return math.floor(settings.personalScale * 100 + 0.5) end,
          setFunction = function(value)
              settings.personalScale = math.max(0.5, math.min(2, (tonumber(value) or 100) / 100))
              personalWindow:SetScale(settings.personalScale)
              refreshAnchor(personalWindow)
              updateUI()
          end },
        { type = LHAS.ST_SECTION, label = L("Allgemein") },
        { type = LHAS.ST_BUTTON, label = L("Messvergleich ausgeben"), buttonText = L("Vergleich im Chat anzeigen"),
          tooltip = L("Vergleicht die unabhaengigen Messungen mit lokalem BattleScrolls. Aendert keine Werte und sendet nichts."),
          clickHandler = function() SimpleGroupDPS_MeasurementComparison:Print() end },
        { type = LHAS.ST_DROPDOWN, label = L("Nach Kampfende anzeigen"), items = retentionItems, default = 1,
          tooltip = L("Setzt alte Ergebnisse nach 1 bis 5 Minuten zurück. Standard: 1 Minute. Laufende Kämpfe bleiben erhalten."),
          getFunction = function() return retentionItems[retentionSeconds(settings.lingerSeconds) / 60].name end,
          setFunction = function(_, _, item)
              settings.lingerSeconds = retentionSeconds(item.data)
              updateUI()
          end },
    }, nil, false)
end

local function onAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    settings = ZO_SavedVars:NewAccountWide("SimpleGroupDPS_SavedVariables", 1, nil, defaults)
    settings.shareDPS = nil -- Remove the obsolete sending preference.
    settings.chatSummary = nil
    settings.dpsWidth = panel:GetWidth(settings)
    settings.lingerSeconds = retentionSeconds(settings.lingerSeconds)
    lastResultAt = GetGameTimeMilliseconds()
    if settings.displaySizeAdjusted then
        if settings.scale == 1 then settings.scale = 0.7 end
        settings.displaySizeAdjusted = nil
    end
    settings.scale = math.max(0.5, math.min(1.5, tonumber(settings.scale) or defaults.scale))
    settings.personalScale = math.max(0.5, math.min(2, tonumber(settings.personalScale) or settings.scale))
    if settings.dpsValueFontSize == nil then settings.dpsValueFontSize = panel:GetValueFontSize(settings) end
    meter.onStarted = function()
        bridge:BeginEncounter()
        refreshUpdateLoop()
    end
    meter.onFinished = function(stats)
        lastResultAt = GetGameTimeMilliseconds()
        settings.lastSummary = {
            damageTotal = stats.total, dps = stats.dps, bossDamageTotal = stats.bossTotal,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, damageDurationMS = stats.durationMS,
            groupDamageTotal = stats.groupTotal, groupDPS = stats.groupDPS,
            groupBossDamageTotal = stats.groupBossTotal, groupBossDPS = stats.groupBossDPS,
            rawHealingTotal = stats.rawHealingTotal, effectiveHealingTotal = stats.effectiveHealingTotal,
            rawHPS = stats.rawHPS, effectiveHPS = stats.effectiveHPS,
            healingDurationMS = stats.healingDurationMS,
        }
        bridge:MarkResult()
        bridge:SendMetrics(stats, true)
        updateUI()
    end
    meter:Initialize(settings.lastSummary)
    createUI()
    bridge.onChanged = function()
        updateUI()
    end
    bridge:Connect()
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, state)
            if not scene or not scene.GetName then return end
            if state == SCENE_SHOWING or state == SCENE_SHOWN or state == "showing" or state == "shown" then
                local name = scene:GetName()
                updateUI(name == "hud" or name == "hudui")
            end
        end)
    end
    initSettings()
    refreshUpdateLoop()
    updateUI()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."Connect", EVENT_PLAYER_ACTIVATED, function() bridge:Connect() end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."Group", EVENT_GROUP_UPDATE, function()
        bridge:Connect()
        bridge:GetRows()
        updateUI()
    end)
    if SLASH_COMMANDS then
        SLASH_COMMANDS["/sgdvergleich"] = function() SimpleGroupDPS_MeasurementComparison:Print() end
        SLASH_COMMANDS["/sgdmove"] = function() setMoveMode(not moveMode) end
        SLASH_COMMANDS["/sgdsharemove"] = function() setMoveMode(not moveMode, personalWindow) end
        SLASH_COMMANDS["/sgdstatus"] = function()
            bridge:Connect()
            local status = bridge:GetStatus()
            local function yes(value) return value and L("Ja") or L("Nein") end
            local measurement = meter:GetDiagnostics()
            local tickAge = lastTickAt and string.format("%.1f s", math.max(0, GetGameTimeMilliseconds() - lastTickAt) / 1000) or L("noch keiner")
            local damageAge = measurement.damageAgeMS and string.format(L("vor %.1f s"), measurement.damageAgeMS / 1000) or L("kein Ereignis seit Kampfstart")
            d(string.format(L("[SimpleGroupDPS %s] Messung aktiv: %s | Spieler im Kampf: %s"),
                ADDON_VERSION, yes(measurement.active), yes(measurement.inCombat)))
            d(string.format(L("[SimpleGroupDPS] Aktualisierungen: %d | Letzte vor: %s | Takt: %d ms"),
                tickCount, tickAge, UPDATE_INTERVAL_MS))
            d(string.format(L("[SimpleGroupDPS] Messzeit: %.3f s | DPS: %.1f | Letzter Schaden: %s"),
                measurement.durationMS / 1000, measurement.dps, damageAge))
            d(string.format(L("[SimpleGroupDPS] Eigener Schaden: %.0f | Boss-Schaden: %s | Boss-DPS: %s"),
                measurement.total or 0,
                measurement.bossTotal and string.format("%.0f", measurement.bossTotal) or "--",
                measurement.bossDPS and string.format("%.1f", measurement.bossDPS) or "--"))
            d(string.format(L("[SimpleGroupDPS] Schadensereignisse: %d | Eigene/Pets: %d | Andere/eingehend: %d"),
                measurement.damageEvents, measurement.personalEvents, measurement.otherEvents))
            if measurement.finishedAgeMS then
                d(string.format(L("[SimpleGroupDPS] Messung vor %.1f s abgeschlossen."), measurement.finishedAgeMS / 1000))
            end
            d(L("[SimpleGroupDPS] Gruppe: ") .. yes(status.grouped)
                .. L(" | Empfang bereit: ") .. yes(status.connected)
                .. L(" | HPS-Empfang bereit: ") .. yes(status.healingConnected))
            d(L("[SimpleGroupDPS] Gruppenversand: automatisch."))
            if status.localBattleScrolls then
                d(L("[SimpleGroupDPS] Empfang über lokales BattleScrolls."))
            else
                d(L("[SimpleGroupDPS] Empfang über LibGroupBroadcast."))
            end
            if status.error then d("[SimpleGroupDPS] " .. L(status.error)) end
            if status.receivedCount then
                d(string.format(L("[SimpleGroupDPS] DPS-/HPS-Pakete empfangen: %d | An Sendewarteschlange uebergeben: %d"),
                    status.receivedCount, status.queuedCount))
            end
        end
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
