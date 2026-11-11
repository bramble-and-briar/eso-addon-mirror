local A = AddKillCounter
local C = A.Core
local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()
local PAGE_SIZE = 40
local function date(day) return C.FormatDate(day) end

function Screen:Initialize(control, scene)
    self.view = {kind = "home", page = 1}
    self.history = {}
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, ZO_GAMEPAD_HEADER_TABBAR_DONT_CREATE, true, scene)
    self.headerData = {titleText = "Add Kill Counter"}
    self:SetListsUseTriggerKeybinds(true)
end

function Screen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = "Auswählen", keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local row = self:GetMainList():GetTargetData()
                if row and row.action then row.action() end
            end,
            enabled = function()
                local row = self:GetMainList():GetTargetData()
                return row and row.action ~= nil
            end,
        },
        {
            name = "Zurück", keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function() self:Back() end,
        },
        {
            name = "Aktualisieren", keybind = "UI_SHORTCUT_SECONDARY",
            callback = function() self:PerformUpdate() end,
        },
        {
            name = "Löschen", keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function() return self:GetSelectedDay() ~= nil end,
            callback = function()
                local day = self:GetSelectedDay()
                if day then A:RequestDeleteConfirmation("day", day) end
            end,
        },
    }
end

function Screen:AfterDayDeleted()
    local daysView = {kind = "days", page = 1}
    if self.view.kind == "days" then daysView = self.view end
    for _, view in ipairs(self.history) do
        if view.kind == "days" then daysView = view end
    end
    self.history = {{kind = "home", page = 1}}
    self.view = daysView
    self:Update()
end

function A:RequestDeleteConfirmation(kind, day)
    if kind == "day" and (not day or not self.sv.stats.days[day]) then return end
    if self.screen:IsShowing() then self.screen:DeactivateCurrentList() end
    ZO_Dialogs_ShowGamepadDialog("ADD_KILL_COUNTER_DELETE", {kind = kind, day = day, confirmed = false})
end

function A:CreateDeleteDialog()
    ZO_Dialogs_RegisterCustomDialog("ADD_KILL_COUNTER_DELETE", {
        gamepadInfo = {dialogType = GAMEPAD_DIALOGS.BASIC},
        title = {text = function(dialog)
            return dialog.data.kind == "day" and "Tag löschen?" or "Statistik löschen?"
        end},
        mainText = {text = function(dialog)
            if dialog.data.kind ~= "day" then
                return "Gesamte Statistik löschen? Alle Gesamt- und Tageszahlen werden gelöscht."
            end
            local day = dialog.data.day
            local message = "Den " .. date(day) .. " aus dem Tagesverlauf löschen? Die Gesamtzahl bleibt erhalten."
            if day == self:Now() then message = message .. " Heute beginnt anschließend wieder bei 0." end
            return message
        end},
        buttons = {
            {keybind = "DIALOG_PRIMARY", text = "Löschen", callback = function(dialog)
                dialog.data.confirmed = true
            end},
            {keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL},
        },
        finishedCallback = function(dialog)
            if dialog.data.confirmed then
                if dialog.data.kind == "day" then
                    C.DeleteDay(self.sv.stats, dialog.data.day)
                    self.screen:AfterDayDeleted()
                else
                    self.sv.stats = C.NewStats()
                    self.session = 0
                    self.screen.history = {}
                    self.screen.view = {kind = "home", page = 1}
                    self.screen:Update()
                end
                self:RefreshHUD()
            end
            if self.screen:IsShowing() then
                self.screen:ActivateCurrentList()
                self.screen:Update()
            end
        end,
    })
end

function Screen:GetSelectedDay()
    local day
    if self.view.kind == "days" then
        local row = self:GetMainList():GetTargetData()
        day = row and row.day
    elseif self.view.kind == "day" then
        day = self.view.day
    end
    if day and A.sv.stats.days[day] then return day end
end

function Screen:Navigate(view)
    local list = self:GetMainList()
    self.view.selection = list:GetSelectedIndex()
    self.history[#self.history + 1] = self.view
    self.view = view
    self.view.page = self.view.page or 1
    self.view.selection = 1
    self:PerformUpdate()
end

function Screen:Back()
    if #self.history == 0 then SCENE_MANAGER:HideCurrentScene(); return end
    self.view = table.remove(self.history)
    self:PerformUpdate()
end

function Screen:AddRow(text, subtitle, detail, action)
    local row = ZO_GamepadEntryData:New(text)
    if subtitle then row:AddSubLabel(subtitle) end
    row.detail = detail or subtitle or text
    row.action = action
    self:GetMainList():AddEntry("ZO_GamepadMenuEntryTemplate", row)
    return row
end

function Screen:OnSelectionChanged(list, row, old)
    ZO_Gamepad_ParametricList_Screen.OnSelectionChanged(self, list, row, old)
    AddKillCounterDetailsTitle:SetText(row and row.text or "Add Kill Counter")
    AddKillCounterDetailsBody:SetText(row and row.detail or "Noch keine Daten vorhanden.")
    self:RefreshKeybinds()
end

function Screen:OnShowing()
    self:PerformUpdate()
end

function Screen:PageRows(rows, render)
    local pages = math.max(1, math.ceil(#rows / PAGE_SIZE))
    self.view.page = math.max(1, math.min(self.view.page or 1, pages))
    local page = self.view.page
    if page > 1 then
        self:AddRow("‹ Vorherige Seite", nil, "Seite " .. page .. " / " .. pages, function()
            self.view.page = page - 1; self.view.selection = 1; self:PerformUpdate()
        end)
    end
    if #rows == 0 then self:AddRow("Noch keine Einträge", nil, "Noch keine Kills aufgezeichnet.") end
    for i = (page - 1) * PAGE_SIZE + 1, math.min(#rows, page * PAGE_SIZE) do render(rows[i]) end
    if page < pages then
        self:AddRow("Nächste Seite ›", nil, "Seite " .. page .. " / " .. pages, function()
            self.view.page = page + 1; self.view.selection = 1; self:PerformUpdate()
        end)
    end
end

function Screen:Home()
    local today = A:Now()
    local stats = A.sv.stats
    local daily = stats.days[today]
    self:AddRow("Heute · " .. (daily and daily.total or 0), date(today),
        "Kills heute: " .. (daily and daily.total or 0) .. "\nDatum: " .. date(today)
        .. "\nGesamt: " .. stats.total,
        function() self:Navigate({kind = "day", day = today}) end)
    self:AddRow("Alle Tage", #C.GetDays(stats) .. " Tage gespeichert", "Kills pro Tag, neueste Tage zuerst.",
        function() self:Navigate({kind = "days"}) end)
    self:AddRow("Gesamt · " .. stats.total, "Gesamtzahl aller Kills", "Getötete Adds insgesamt: " .. stats.total)
end

function Screen:Days()
    self:PageRows(C.GetDays(A.sv.stats), function(day)
        local row = A.sv.stats.days[day]
        local entry = self:AddRow(date(day) .. " · " .. row.total, row.firstTime .. " – " .. row.lastTime,
            "Datum: " .. date(day) .. "\nKills: " .. row.total .. "\nErster Kill: " .. row.firstTime .. "\nLetzter Kill: " .. row.lastTime,
            function() self:Navigate({kind = "day", day = day}) end)
        entry.day = day
    end)
end

function Screen:Day()
    local day = self.view.day
    local row = A.sv.stats.days[day]
    self:AddRow(date(day) .. " · " .. (row and row.total or 0) .. " Kills", nil,
        row and ("Erster Kill: " .. row.firstTime .. "\nLetzter Kill: " .. row.lastTime) or "Heute wurden noch keine Kills erfasst.")
end

function Screen:PerformUpdate()
    if not A.sv then return end
    local list = self:GetMainList()
    local selection = self.view.selection or list:GetSelectedIndex() or 1
    list:Clear()
    local kind = self.view.kind
    local titles = {home = "Add Kill Counter", days = "Alle Tage", day = "Tagesübersicht"}
    self.headerData.titleText = titles[kind] or "Add Kill Counter"
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    if kind == "home" then self:Home()
    elseif kind == "days" then self:Days()
    elseif kind == "day" then self:Day()
    end
    list:Commit()
    list:SetSelectedIndexWithoutAnimation(math.max(1, math.min(selection, list:GetNumEntries())))
    self:OnSelectionChanged(list, list:GetTargetData())
    self.dirty = false
end

function A:CreateUI()
    local scene = ZO_Scene:New(self.sceneName, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(ZO_FadeSceneFragment:New(AddKillCounterWindow))
    scene:AddFragment(ZO_FadeSceneFragment:New(AddKillCounterDetails))
    self.screen = Screen:New(AddKillCounterWindow, scene)
    self.hud = AddKillCounterHUD
    self.hud.label = AddKillCounterHUDText
    self.hudFragment = ZO_HUDFadeSceneFragment:New(self.hud)
    SCENE_MANAGER:GetScene("hud"):AddFragment(self.hudFragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(self.hudFragment)
    self:RefreshHUD()
    self:CreateDeleteDialog()
end
