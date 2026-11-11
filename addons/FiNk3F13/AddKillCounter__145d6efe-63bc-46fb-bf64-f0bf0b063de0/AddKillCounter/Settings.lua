local A = AddKillCounter

function A:ClampHUDPosition(x, y)
    -- ESO's measured control dimensions already include its scale.
    local maxX = math.max(0, GuiRoot:GetWidth() - self.hud:GetWidth())
    local maxY = math.max(0, GuiRoot:GetHeight() - self.hud:GetHeight())
    return math.max(0, math.min(maxX, x)), math.max(0, math.min(maxY, y))
end

function A:FinishHUDMove(save)
    if not self.moving then return end
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "MoveHUD")
    self.moving = false
    if not save then
        self.sv.hudCustom = self.moveOriginal.custom
        self.sv.hudX, self.sv.hudY = self.moveOriginal.x, self.moveOriginal.y
    end
    self.moveOriginal = nil
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    self:RefreshHUD()
end

function A:UpdateHUDMove()
    if not self.moving then return end
    local now = GetFrameTimeSeconds()
    local dt = math.max(0, math.min(0.05, now - self.moveFrame))
    self.moveFrame = now
    local stickX = GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE)
    local stickY = GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE)
    if math.abs(stickX) >= 0.05 or math.abs(stickY) >= 0.05 then
        self.sv.hudX, self.sv.hudY = self:ClampHUDPosition(
            self.sv.hudX + stickX * 720 * dt,
            self.sv.hudY - stickY * 720 * dt)
        self.moveLastInput = now
        self:RefreshHUD()
    end
    if now - self.moveLastInput >= 3 then
        self:FinishHUDMove(true)
        SCENE_MANAGER:HideCurrentScene()
    end
end

function A:StartHUDMove()
    if self.moving then return end
    SCENE_MANAGER:Push("addKillCounterMove")
end

function A:CreateMoveScene()
    local scene = ZO_Scene:New("addKillCounterMove", SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(self.hudFragment)
    scene:AddFragment(ZO_FadeSceneFragment:New(AddKillCounterMoveHelp))
    self.moveKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {name = "Position speichern", keybind = "UI_SHORTCUT_PRIMARY", callback = function()
            self:FinishHUDMove(true); SCENE_MANAGER:HideCurrentScene()
        end},
        {name = "Abbrechen", keybind = "UI_SHORTCUT_NEGATIVE", callback = function()
            self:FinishHUDMove(false); SCENE_MANAGER:HideCurrentScene()
        end},
    }
    scene:RegisterCallback("StateChange", function(_, state)
        if state == SCENE_SHOWING then
            self.moveOriginal = {custom = self.sv.hudCustom, x = self.sv.hudX, y = self.sv.hudY}
            self.sv.hudX, self.sv.hudY = self:ClampHUDPosition(self.hud:GetLeft(), self.hud:GetTop())
            self.sv.hudCustom = true
            self.moving = true
            self.moveLastInput = GetFrameTimeSeconds()
            self.moveFrame = self.moveLastInput
            KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
            self:RefreshHUD()
            EVENT_MANAGER:RegisterForUpdate(self.name .. "MoveHUD", 16, function() self:UpdateHUDMove() end)
        elseif state == SCENE_HIDING then
            -- Scene interruptions cancel, rather than leave the movement timer running.
            self:FinishHUDMove(false)
        end
    end)
end

function A:CreateSettings()
    self:CreateMoveScene()
    local lib = LibHarvensAddonSettings
    local panel = lib:AddAddon("Add Kill Counter", {allowRefresh = true})
    self.settingsPanel = panel
    local function button(label, text, help, callback)
        panel:AddSetting({type = lib.ST_BUTTON, label = label, buttonText = text, tooltip = help, clickHandler = callback})
    end
    local function checkbox(key, label, help)
        panel:AddSetting({type = lib.ST_CHECKBOX, label = label, tooltip = help,
            getFunction = function() return self.sv[key] end,
            setFunction = function(value)
                self.sv[key] = value and true or false
                self:RefreshHUD()
                self.screen:Update()
            end, default = self.defaults[key]})
    end
    panel:AddSetting({type = lib.ST_SECTION, label = "Killstatistik"})
    panel:AddSetting({type = lib.ST_LABEL, label = function()
        local day = self:Now()
        local row = self.sv.stats.days[day]
        return string.format("Getötete Adds gesamt: %d · Heute: %d", self.sv.stats.total, row and row.total or 0)
    end})
    button("Statistik", "Killübersicht öffnen", "Gesamtzahl und Tageszahlen anzeigen.", function() self:Open() end)
    panel:AddSetting({type = lib.ST_SECTION, label = "Anzeige und Position"})
    checkbox("showHUD", "Zähler anzeigen", "Zeigt Heute und Gesamtzahl im aktivierten Gebiet.")
    checkbox("combatOnly", "Nur im Kampf anzeigen", "Der Verschiebemodus zeigt den Zähler immer als Vorschau.")
    button("Move UI", "Zähler verschieben", "Rechter Stick: verschieben. Nach 3 Sekunden ohne Bewegung wird gespeichert. Auswählen speichert sofort; Zurück verwirft.", function() self:StartHUDMove() end)
    panel:AddSetting({type = lib.ST_SLIDER, label = "Zählergröße", min = 0.5, max = 1.5, step = 0.05, format = "%.2f",
        getFunction = function() return self.sv.hudScale end,
        setFunction = function(value) self.sv.hudScale = value; self:RefreshHUD() end, default = 1})
    button("Position", "Position zurücksetzen", "Setzt den Zähler auf oben links zurück. Statistik bleibt erhalten.", function()
        self.sv.hudCustom = false; self.sv.hudPosition = 1; self:RefreshHUD()
    end)
    panel:AddSetting({type = lib.ST_SECTION, label = "Erfassung"})
    panel:AddSetting({type = lib.ST_LABEL, label = function()
        return (self.sv.targetZoneId or 0) > 0
            and ("Aktives Gebiet: " .. self.sv.targetZoneName)
            or "Kein Gebiet aktiviert"
    end})
    button("Aktuelles Gebiet aktivieren", "Aktuelles Gebiet aktivieren", "Wählt das Gebiet, in dem du gerade stehst. Nur dort wird angezeigt und gezählt. Die Auswahl bleibt gespeichert.", function()
        self:ActivateCurrentZone()
    end)
    button("Gebiet deaktivieren", "Gebiet deaktivieren", "Beendet die Gebietsauswahl. Deine Gesamt- und Tageszahlen bleiben erhalten.", function()
        self:DeactivateZone()
    end)
    checkbox("enabled", "Kills erfassen", "Zählt nur im aktivierten Gebiet. Aus pausiert die Erfassung.")
    checkbox("includePets", "Eigene Pets mitzählen", "Todesstöße eigener beschworener Pets mitzählen.")
    checkbox("includeCompanion", "Begleiter mitzählen", "Kills deines Begleiters mitzählen.")
    checkbox("participation", "Killbeteiligungen mitzählen", "Zählt auch Gegner, an deren Tötung du, deine Pets oder dein Begleiter beteiligt waren.")
    button("Statistik", "Statistik löschen …", "Öffnet eine Bestätigung. Löscht erst nach deiner Bestätigung.", function() self:RequestDeleteConfirmation("all") end)
end
