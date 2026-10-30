local ADDON_NAME = "SimpleGroupDPS"
local ADDON_VERSION = "1.5.1"
local UPDATE_INTERVAL_MS = 300
local wm = WINDOW_MANAGER
local meter, bridge, panel = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls, SimpleGroupDPS_DPSPanel
local defaults = {
    showGroup = true, shareDPS = true,
    posX = 720, posY = 300, scale = 1,
    dpsWidth = 400, dpsFontSize = 22, dpsRowSpacing = 8, lastSummary = {},
    lingerSeconds = 60,
}
local settings, window, moveHint, moveOverlay
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

local function savePosition()
    settings.posX = math.floor(window:GetLeft() + 0.5)
    settings.posY = math.floor(window:GetTop() + 0.5)
end

local function refreshAnchor()
    window:ClearAnchors()
    window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, settings.posX, settings.posY)
end

local function refreshUpdateLoop()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."UI")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."UI", UPDATE_INTERVAL_MS, tick)
end

local function setMoveMode(enabled)
    enabled = enabled and true or false
    if moveMode == enabled then
        if enabled then moveLastInputAt = GetGameTimeMilliseconds() end
        return
    end
    moveMode = enabled
    window:SetMovable(enabled)
    window:SetMouseEnabled(enabled)
    moveHint:SetHidden(not enabled)
    moveOverlay:SetHidden(not enabled)
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."Move")
    if enabled then
        moveLastInputAt = GetGameTimeMilliseconds()
        moveLastX, moveLastY = window:GetLeft(), window:GetTop()
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
            local left, top = window:GetLeft(), window:GetTop()
            if moveDragging or left ~= moveLastX or top ~= moveLastY then
                moveLastInputAt = now
                savePosition()
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
                settings.posX = math.max(0, math.min(math.max(0, GuiRoot:GetWidth() - window:GetWidth()), left + x * 22))
                settings.posY = math.max(0, math.min(math.max(0, GuiRoot:GetHeight() - window:GetHeight()), top - y * 22))
                refreshAnchor()
                savePosition()
                moveLastInputAt = now
            end
            moveLastX, moveLastY = window:GetLeft(), window:GetTop()
            if now - moveLastInputAt >= 3000 then setMoveMode(false) end
        end)
    else
        window:StopMovingOrResizing()
        savePosition()
        moveDragging = false
        if previousUIMode == false and SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
        if previousCameraMode == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
        previousUIMode, previousCameraMode = nil, nil
    end
    refreshUpdateLoop()
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
    if not moveMode and not sceneVisible then window:SetHidden(true); return end
    local stats = snapshot or meter:GetStats()
    local rows = settings.showGroup and bridge:GetRows() or {}
    if moveMode or meter:IsActive() or stats.total > 0 or #rows > 0 then
        rows[#rows + 1] = {
            name = GetUnitDisplayName("player"), dps = stats.dps,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, isPlayer = true,
            role = GetSelectedLFGRole and GetSelectedLFGRole(),
        }
    end
    -- Shared DPS packets do not identify the sender's encounter.
    local bossFight = stats.bossDPS ~= nil
    local height = panel:Render(window, rows, bossFight, stats.durationMS, settings, stats)
    window:SetDimensions(panel:GetWidth(settings), math.max(40, height))
    window:SetHidden(not moveMode and #rows == 0)
end

tick = function()
    lastTickAt = GetGameTimeMilliseconds()
    tickCount = tickCount + 1
    -- Receiving must also connect while idle, without waiting for our first attack.
    bridge:Connect()
    -- One snapshot for display and sending, as in Battle Scrolls' CombatTicker.
    local stats = meter:GetStats()
    if settings.shareDPS and meter:IsActive() then bridge:SendDPS(stats.dps, false, stats.bossDPS) end
    updateUI(nil, stats)
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
    window:SetHandler("OnMouseDown", function(control, button)
        if moveMode and button == MOUSE_BUTTON_INDEX_LEFT then
            moveDragging = true
            moveLastInputAt = GetGameTimeMilliseconds()
            control:StartMoving()
        end
    end)
    window:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
            moveDragging = false
            moveLastInputAt = GetGameTimeMilliseconds()
            savePosition()
        end
    end)
    window:SetHandler("OnMoveStop", function()
        moveDragging = false
        moveLastInputAt = GetGameTimeMilliseconds()
        savePosition()
    end)
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
    label:SetText("SimpleGroupDPS: mit Maus oder rechtem Stick verschieben\nSpeichert nach 3 Sekunden ohne Bewegung")
end

local function initSettings()
    local LHAS = LibHarvensAddonSettings
    local addon = LHAS:AddAddon(ADDON_NAME, { allowRefresh = true })
    local retentionItems = {}
    for minutes = 1, 5 do
        retentionItems[minutes] = {name = minutes == 1 and "1 Minute" or (minutes .. " Minuten"), data = minutes * 60}
    end
    addon:AddSettings({
        { type = LHAS.ST_BUTTON, label = "Move UI", buttonText = "DPS-Anzeige verschieben",
          tooltip = "Mit Maus oder rechtem Stick verschieben. Speichert und endet nach 3 Sekunden ohne Bewegung.",
          clickHandler = function() setMoveMode(true) end },
        { type = LHAS.ST_SLIDER, label = "DPS-Zahlengröße", min = 14, max = 32, step = 1,
          tooltip = "Verändert die DPS-Zahlen und die Summe. Namen und Gesamtskalierung bleiben gleich. Größere Zahlen erhalten bei Bedarf mehr Zeilenhöhe. Für lange Boss-/Gesamtwerte die Fensterbreite erhöhen.",
          getFunction = function() return panel:GetValueFontSize(settings) end,
          setFunction = function(value) settings.dpsValueFontSize = value; updateUI() end },
        { type = LHAS.ST_SLIDER, label = "Fensterbreite", min = 280, max = 400, step = 10,
          tooltip = "Kleinere Werte ziehen Namen und DPS enger zusammen. Lange Namen werden gekürzt; zu breite Zahlen passend verkleinert.",
          getFunction = function() return settings.dpsWidth end,
          setFunction = function(value) settings.dpsWidth = panel:GetWidth({dpsWidth = value}); updateUI() end },
        { type = LHAS.ST_SLIDER, label = "Zeilenabstand", min = 0, max = 16, step = 1,
          tooltip = "Kleinere Werte rücken die Spielerzeilen näher zusammen. Die Schrift bleibt gleich groß.",
          getFunction = function() return settings.dpsRowSpacing end,
          setFunction = function(value) settings.dpsRowSpacing = value; updateUI() end },
        { type = LHAS.ST_DROPDOWN, label = "Nach Kampfende anzeigen", items = retentionItems, default = 1,
          tooltip = "Setzt alte Ergebnisse nach 1 bis 5 Minuten zurück. Standard: 1 Minute. Laufende Kämpfe bleiben erhalten.",
          getFunction = function() return retentionItems[retentionSeconds(settings.lingerSeconds) / 60].name end,
          setFunction = function(_, _, item)
              settings.lingerSeconds = retentionSeconds(item.data)
              updateUI()
          end },
        { type = LHAS.ST_BUTTON, label = "Layout zurücksetzen", buttonText = "Standardlayout",
          tooltip = "Setzt DPS-Zahlengröße, Fensterbreite und Zeilenabstand zurück. Position, Namensgröße und Gesamtskalierung bleiben erhalten.",
          clickHandler = function()
              settings.dpsWidth, settings.dpsRowSpacing = defaults.dpsWidth, defaults.dpsRowSpacing
              settings.dpsValueFontSize = panel:GetValueFontSize(defaults)
              updateUI()
          end },
    }, nil, false)
end

local function onAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    settings = ZO_SavedVars:NewAccountWide("SimpleGroupDPS_SavedVariables", 1, nil, defaults)
    settings.chatSummary = nil
    settings.dpsWidth = panel:GetWidth(settings)
    settings.lingerSeconds = retentionSeconds(settings.lingerSeconds)
    lastResultAt = GetGameTimeMilliseconds()
    if settings.displaySizeAdjusted then
        if settings.scale == 1 then settings.scale = 0.7 end
        settings.displaySizeAdjusted = nil
    end
    if settings.dpsValueFontSize == nil then settings.dpsValueFontSize = panel:GetValueFontSize(settings) end
    meter.onFinished = function(stats)
        lastResultAt = GetGameTimeMilliseconds()
        settings.lastSummary = {
            damageTotal = stats.total, dps = stats.dps, bossDamageTotal = stats.bossTotal,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, damageDurationMS = stats.durationMS,
            groupDamageTotal = stats.groupTotal, groupDPS = stats.groupDPS,
            groupBossDamageTotal = stats.groupBossTotal, groupBossDPS = stats.groupBossDPS,
        }
        if settings.shareDPS then bridge:SendDPS(stats.dps, true, stats.bossDPS) end
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
        SLASH_COMMANDS["/sgdmove"] = function() setMoveMode(not moveMode) end
        SLASH_COMMANDS["/sgdstatus"] = function()
            bridge:Connect()
            local status = bridge:GetStatus()
            local function yes(value) return value and "Ja" or "Nein" end
            local measurement = meter:GetDiagnostics()
            local tickAge = lastTickAt and string.format("%.1f s", math.max(0, GetGameTimeMilliseconds() - lastTickAt) / 1000) or "noch keiner"
            local damageAge = measurement.damageAgeMS and string.format("vor %.1f s", measurement.damageAgeMS / 1000) or "kein Ereignis seit Kampfstart"
            d(string.format("[SimpleGroupDPS %s] Messung aktiv: %s | Spieler im Kampf: %s",
                ADDON_VERSION, yes(measurement.active), yes(measurement.inCombat)))
            d(string.format("[SimpleGroupDPS] Aktualisierungen: %d | Letzte vor: %s | Takt: %d ms",
                tickCount, tickAge, UPDATE_INTERVAL_MS))
            d(string.format("[SimpleGroupDPS] Messzeit: %.3f s | DPS: %.1f | Letzter Schaden: %s",
                measurement.durationMS / 1000, measurement.dps, damageAge))
            d(string.format("[SimpleGroupDPS] Schadensereignisse: %d | Eigene/Pets: %d | Andere/eingehend: %d",
                measurement.damageEvents, measurement.personalEvents, measurement.otherEvents))
            if measurement.finishedAgeMS then
                d(string.format("[SimpleGroupDPS] Messung vor %.1f s abgeschlossen.", measurement.finishedAgeMS / 1000))
            end
            d("[SimpleGroupDPS] Gruppe: " .. yes(status.grouped) .. " | Teilen: " .. yes(settings.shareDPS)
                .. " | Sender bereit: " .. yes(status.connected))
            if status.localBattleScrolls then
                d("[SimpleGroupDPS] Versand wird vom lokal installierten BattleScrolls uebernommen.")
            else
                d("[SimpleGroupDPS] LibGroupBroadcast erlaubt Versand: " .. yes(status.enabled))
                if status.lastSendAt then
                    local age = math.max(0, GetGameTimeMilliseconds() - status.lastSendAt) / 1000
                    d(string.format("[SimpleGroupDPS] Letzte DPS an Sendewarteschlange uebergeben: vor %.1f s", age))
                else
                    d("[SimpleGroupDPS] Seit dem letzten Kampfstart noch keine DPS an die Sendewarteschlange uebergeben.")
                end
                if status.lastSendResult == "failed" then d("[SimpleGroupDPS] Letzter Sendeversuch wurde abgelehnt.") end
            end
            if status.error then d("[SimpleGroupDPS] " .. status.error) end
            if status.receivedCount then
                d(string.format("[SimpleGroupDPS] DPS-/HPS-Pakete empfangen: %d | An Sendewarteschlange uebergeben: %d",
                    status.receivedCount, status.queuedCount))
            end
        end
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
