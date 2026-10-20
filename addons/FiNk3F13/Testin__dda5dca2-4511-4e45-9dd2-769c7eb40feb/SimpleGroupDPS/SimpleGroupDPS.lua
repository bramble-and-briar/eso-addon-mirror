local ADDON_NAME = "SimpleGroupDPS"
local wm = WINDOW_MANAGER
local meter, bridge, panel = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls, SimpleGroupDPS_DPSPanel
local defaults = {
    showUI = true, showGroup = true, shareDPS = true, chatSummary = true,
    posX = 720, posY = 300, scale = 1,
    dpsWidth = 520, dpsFontSize = 22, dpsRowSpacing = 8, lastSummary = {},
}
local settings, window, moveHint
local moveMode = false
local previousUIMode, previousCameraMode
local updateUI

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
    if settings.showUI or moveMode then
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."UI", 250, updateUI)
    end
end

local function setMoveMode(enabled)
    enabled = enabled and true or false
    if moveMode == enabled then return end
    moveMode = enabled
    window:SetMovable(enabled)
    window:SetMouseEnabled(enabled)
    moveHint:SetHidden(not enabled)
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."Move")
    if enabled then
        if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode then
            previousUIMode = SCENE_MANAGER:IsInUIMode()
            SCENE_MANAGER:SetInUIMode(true)
        end
        if SetGameCameraUIMode then
            previousCameraMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive() or false
            SetGameCameraUIMode(true)
        end
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."Move", 16, function()
            if not GetGamepadRightStickX or not GetGamepadRightStickY then return end
            local x = GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE) or 0
            local y = GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
            if math.abs(x) < 0.05 and math.abs(y) < 0.05 then return end
            settings.posX = settings.posX + x * 22
            settings.posY = settings.posY - y * 22
            refreshAnchor()
            savePosition()
        end)
    else
        window:StopMovingOrResizing()
        savePosition()
        if previousUIMode == false and SCENE_MANAGER and SCENE_MANAGER.SetInUIMode then SCENE_MANAGER:SetInUIMode(false) end
        if previousCameraMode == false and SetGameCameraUIMode then SetGameCameraUIMode(false) end
        previousUIMode, previousCameraMode = nil, nil
    end
    refreshUpdateLoop()
    updateUI()
end

updateUI = function()
    local stats = meter:GetStats()
    local rows = settings.showGroup and bridge:GetRows() or {}
    if moveMode or meter:IsActive() or stats.total > 0 or #rows > 0 then
        rows[#rows + 1] = {
            name = GetUnitDisplayName("player"), dps = stats.dps,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, isPlayer = true,
        }
    end
    local bossFight = false
    for _, member in ipairs(rows) do
        if (member.isPlayer and member.bossDPS ~= nil)
            or (not member.isPlayer and member.bossDPS and member.bossDPS > 0) then
            bossFight = true
            break
        end
    end
    local height = panel:Render(window, rows, bossFight, stats.durationMS, settings)
    window:SetDimensions(panel:GetWidth(settings), math.max(40, height))
    window:SetHidden(not moveMode and (not settings.showUI or #rows == 0))
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
        if moveMode and button == MOUSE_BUTTON_INDEX_LEFT then control:StartMoving() end
    end)
    window:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then control:StopMovingOrResizing(); savePosition() end
    end)
    window:SetHandler("OnMoveStop", savePosition)
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
    label:SetText("SimpleGroupDPS: mit Maus oder rechtem Stick verschieben")
end

local function initSettings()
    local LHAS = LibHarvensAddonSettings
    local addon = LHAS:AddAddon(ADDON_NAME, { allowRefresh = true })
    addon:AddSettings({
        { type = LHAS.ST_SECTION, label = "Anzeige / Move UI" },
        { type = LHAS.ST_CHECKBOX, label = "DPS-Anzeige aktiv",
          getFunction = function() return settings.showUI end,
          setFunction = function(value) settings.showUI = value; refreshUpdateLoop(); updateUI() end },
        { type = LHAS.ST_CHECKBOX, label = "Move UI (Verschieben)",
          getFunction = function() return moveMode end,
          setFunction = setMoveMode },
        { type = LHAS.ST_LABEL, label = "Mit der Maus ziehen oder den rechten Stick bewegen. Danach Position speichern." },
        { type = LHAS.ST_BUTTON, label = "Position speichern / Move UI beenden", buttonText = "Speichern",
          clickHandler = function() setMoveMode(false) end },
        { type = LHAS.ST_SLIDER, label = "Gesamtgroesse der Anzeige", min = 0.5, max = 2, step = 0.05,
          getFunction = function() return settings.scale end,
          setFunction = function(value) settings.scale = value; window:SetScale(value) end },
        { type = LHAS.ST_SLIDER, label = "Breite der DPS-Anzeige", min = 420, max = 800, step = 10,
          getFunction = function() return settings.dpsWidth end,
          setFunction = function(value) settings.dpsWidth = value; updateUI() end },
        { type = LHAS.ST_SLIDER, label = "Schriftgroesse der DPS-Anzeige", min = 14, max = 30, step = 1,
          getFunction = function() return settings.dpsFontSize end,
          setFunction = function(value) settings.dpsFontSize = value; updateUI() end },
        { type = LHAS.ST_SLIDER, label = "Zeilenabstand (kleiner = enger)", min = 0, max = 16, step = 1,
          getFunction = function() return settings.dpsRowSpacing end,
          setFunction = function(value) settings.dpsRowSpacing = value; updateUI() end },
        { type = LHAS.ST_BUTTON, label = "Anzeige-Layout zuruecksetzen", buttonText = "Zuruecksetzen",
          clickHandler = function()
              settings.posX, settings.posY, settings.scale = defaults.posX, defaults.posY, defaults.scale
              settings.dpsWidth, settings.dpsFontSize, settings.dpsRowSpacing = defaults.dpsWidth, defaults.dpsFontSize, defaults.dpsRowSpacing
              window:SetScale(settings.scale)
              refreshAnchor()
              updateUI()
          end },
        { type = LHAS.ST_SECTION, label = "Gruppen-DPS / Battle Scrolls" },
        { type = LHAS.ST_CHECKBOX, label = "Gruppenmitglieder anzeigen",
          getFunction = function() return settings.showGroup end,
          setFunction = function(value) settings.showGroup = value; updateUI() end },
        { type = LHAS.ST_CHECKBOX, label = "Eigene DPS mit der Gruppe teilen",
          getFunction = function() return settings.shareDPS end,
          setFunction = function(value) settings.shareDPS = value end },
        { type = LHAS.ST_CHECKBOX, label = "DPS-Zusammenfassung im Chat",
          getFunction = function() return settings.chatSummary end,
          setFunction = function(value) settings.chatSummary = value end },
    }, nil, false)
end

local function onAddonLoaded(_, name)
    if name ~= ADDON_NAME then return end
    settings = ZO_SavedVars:NewAccountWide("SimpleGroupDPS_SavedVariables", 1, nil, defaults)
    meter.onFinished = function(stats)
        settings.lastSummary = {
            damageTotal = stats.total, dps = stats.dps, bossDamageTotal = stats.bossTotal,
            bossDPS = stats.bossDPS, addsDPS = stats.addsDPS, damageDurationMS = stats.durationMS,
        }
        if settings.shareDPS then bridge:SendDPS(stats.dps, true, stats.bossDPS) end
        if settings.chatSummary and stats.total > 0 then
            d(string.format("|c88CCFF[%s]|r DPS %.0f | Schaden %.0f | %.1fs", ADDON_NAME, stats.dps, stats.total, stats.durationMS / 1000))
        end
        updateUI()
    end
    meter:Initialize(settings.lastSummary)
    createUI()
    initSettings()
    refreshUpdateLoop()
    updateUI()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."Connect", EVENT_PLAYER_ACTIVATED, function() bridge:Connect() end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME.."Group", EVENT_GROUP_UPDATE, function() bridge:Clear(); updateUI() end)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."Send", 1000, function()
        if settings.shareDPS and meter:IsActive() and IsUnitInCombat("player") then
            local stats = meter:GetStats()
            bridge:SendDPS(stats.dps, false, stats.bossDPS)
        end
    end)
    if SLASH_COMMANDS then SLASH_COMMANDS["/sgdmove"] = function() setMoveMode(not moveMode) end end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddonLoaded)
