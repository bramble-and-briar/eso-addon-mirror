-- Native gamepad menus and dialogs. Internal names preserve saved settings.
local R = Relais
local SCENE_NAME = "relaisGamepad"
local TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_skills.dds"
local GEAR_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds"
local CHAMPION_ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_champion.dds"
local CONFIRM_DIALOG = "RELAIS_CONFIRM_GAMEPAD"
local RENAME_DIALOG = "RELAIS_RENAME_GAMEPAD"

local function Trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Table(value)
    return type(value) == "table" and value or {}
end

local function Profiles()
    return Table(R.db and R.db.profiles)
end

local function Profile(id)
    if type(id) ~= "number" or id <= 0 or id ~= math.floor(id) then return nil end
    local profile = Profiles()[id]
    return type(profile) == "table" and profile or nil
end

local function PlainText(value, fallback)
    if type(value) ~= "string" then return fallback end
    local text = value:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", " ")
    return Trim(text) ~= "" and text or fallback
end

local function ProfileName(profile, id)
    local fallback = type(id) == "number" and ("Setup " .. tostring(id)) or "Setup"
    return PlainText(profile and profile.name, fallback)
end

local function HasContentModel()
    return type(R.GetContentEntries) == "function" and type(R.GetPageEntries) == "function"
end

local DIFFICULTIES = { { "any", "Commun" }, { "normal", "Normal" }, { "veteran", "Vétéran" }, { "hard", "Hard Mode" } }
local ROLES = { { "damage", "Dégâts" }, { "healer", "Soins" }, { "tank", "Tank" }, { "any", "Libre" } }
local CATEGORIES = { { "general", "Général" }, { "raids", "Raids" }, { "dungeons", "Donjons" }, { "favorites", "Favoris" } }

local function DifficultyLabel(value)
    for _, difficulty in ipairs(DIFFICULTIES) do if difficulty[1] == value then return difficulty[2] end end
    return "Commun"
end

local function RoleLabel(value)
    for _, role in ipairs(ROLES) do if role[1] == value then return role[2] end end
    return "Libre"
end

local function ContentName(id)
    if type(R.GetContentName) == "function" then
        local ok, name = pcall(R.GetContentName, R, id)
        if ok then return PlainText(name, id == "general" and "Général" or "Contenu") end
    end
    return id == "general" and "Général" or "Contenu"
end

local function PageContext(id)
    local context = Table(Table(R.db and R.db.pageContexts)[id])
    return context.contentId or "general", context.difficulty or "any", context.role or "any"
end

local function Encounter(contentId, encounterId)
    local content = Table(R:GetContent(contentId))
    for _, encounter in ipairs(Table(content.encounters)) do
        if type(encounter) == "table" and encounter.id == encounterId then return encounter end
    end
end

local function RaidSteps(contentId, pageId)
    if type(R.GetRaidSteps) ~= "function" then return {} end
    local ok, steps = pcall(R.GetRaidSteps, R, contentId, pageId)
    return ok and Table(steps) or {}
end

local function HasRaidSteps(contentId, pageId)
    if type(R.GetContent) ~= "function" or Table(R:GetContent(contentId)).category ~= "trials" then return false end
    if type(R.GetRaidRoute) == "function" and type(R:GetRaidRoute(contentId, pageId)) == "table" then return true end
    return #RaidSteps(contentId, pageId) > 0
end

local function StepId(key)
    return type(key) == "string" and key:match("^stage:(.+)$") or nil
end

local function EffectiveProfile(contentId, pageId, key)
    local stepId = StepId(key)
    if stepId and type(R.GetEffectiveRaidStepProfile) == "function" then
        return R:GetEffectiveRaidStepProfile(contentId, pageId, stepId)
    end
    return R:GetAssignedProfile(contentId, pageId, key), nil
end

local function SharedSetupWarning(id)
    if type(R.GetProfileContentAssignments) ~= "function" then return "" end
    local ok, rows = pcall(R.GetProfileContentAssignments, R, id)
    rows = ok and Table(rows) or {}
    if #rows < 2 then return "" end
    local places = {}
    for index = 1, math.min(#rows, 3) do
        local row = Table(rows[index])
        local named, pageName = pcall(R.GetPageName, R, row.pageId)
        local name = PlainText(row.name, "Emplacement")
        if name:match("^stage:") then name = "Étape d'un autre parcours" end
        places[#places + 1] = name .. " · " .. (named and PlainText(pageName, "Page") or "Page")
    end
    return " Ce setup est partagé entre " .. tostring(#rows) .. " emplacements : " .. table.concat(places, "; ") .. (#rows > 3 and "; …" or "") .. ". Sa mise à jour les modifiera tous."
end

local function IsBusy()
    return (R.engine and R.engine:IsBusy()) or R.bankTransfer ~= nil
end

local function AutomaticEnabled()
    return Table(R.db and R.db.settings).automatic == true
end

local function StatusText()
    local text = R:GetStatusText()
    return type(text) == "string" and text ~= "" and text or "Prêt."
end

local function ReadText(api, fallback, ...)
    if type(api) ~= "function" then return fallback end
    local ok, value = pcall(api, ...)
    return ok and PlainText(value, fallback) or fallback
end

local function Inspect(profile)
    if type(R.adapter.InspectProfile) ~= "function" then return {} end
    local ok, value = pcall(R.adapter.InspectProfile, R.adapter, profile)
    return ok and Table(value) or {}
end

local function Availability(item)
    item = Table(item)
    if item.missing then return "\nObjet absent du sac et de l'équipement." end
    if item.available == false then return "\n" .. PlainText(item.problem, "Cet élément est indisponible pour le chargement.") end
    if item.different then return "\nDifférent de la configuration actuelle." end
    if item.equipped then return "\nDéjà équipé." end
    return ""
end

local function EquipmentSlots()
    return {
        { EQUIP_SLOT_HEAD, "Tête" }, { EQUIP_SLOT_CHEST, "Torse" },
        { EQUIP_SLOT_SHOULDERS, "Épaules" }, { EQUIP_SLOT_HAND, "Mains" },
        { EQUIP_SLOT_WAIST, "Taille" }, { EQUIP_SLOT_LEGS, "Jambes" },
        { EQUIP_SLOT_FEET, "Pieds" }, { EQUIP_SLOT_NECK, "Collier" },
        { EQUIP_SLOT_RING1, "Anneau 1" }, { EQUIP_SLOT_RING2, "Anneau 2" },
        { EQUIP_SLOT_MAIN_HAND, "Arme principale" }, { EQUIP_SLOT_OFF_HAND, "Main secondaire" },
        { EQUIP_SLOT_BACKUP_MAIN, "Arme de secours" }, { EQUIP_SLOT_BACKUP_OFF, "Main secondaire de secours" },
    }
end

local function SkillSlots()
    if type(GetAssignableAbilityBarStartAndEndSlots) == "function" then
        return GetAssignableAbilityBarStartAndEndSlots()
    end
    return 3, 8
end

local function ChampionSlots()
    if type(GetAssignableChampionBarStartAndEndSlots) == "function" then
        return GetAssignableChampionBarStartAndEndSlots()
    end
    return 1, 12
end

local function ZoneRules()
    return Table(Table(R.db and R.db.rules).zones)
end

local function PositionCount(id, zoneId)
    local count = 0
    for _, point in ipairs(Table(Table(R.db and R.db.rules).positions)) do
        if type(point) == "table" and point.profileId == id and point.zoneId == zoneId then count = count + 1 end
    end
    return count
end

local function BossAssociations(zoneId)
    local rules = Table(Table(Table(R.db and R.db.rules).bosses)[zoneId])
    local names = {}
    for name in pairs(rules) do
        if type(name) == "string" then names[#names + 1] = name end
    end
    table.sort(names)
    return names, rules
end

local function SameZone(zoneId)
    if zoneId and zoneId ~= 0 and R:GetZoneId() == zoneId then return true end
    R:Notify("La zone a changé. Rouvrez ce menu dans la zone souhaitée.")
    R:RefreshUI()
    return false
end

local function EndCaptureDialog(dialog)
    if R.ui and dialog and dialog.data and dialog.data.capture then R.ui.captureDialogOpen = false end
end

local function CanOpenDialog()
    if ZO_Dialogs_IsShowingDialog() then
        R:Notify("Une fenêtre est déjà ouverte. Fermez-la puis réessayez.")
        return false
    end
    return true
end

local function BeginCaptureDialog()
    if IsBusy() or not CanOpenDialog() then return false end
    if R.ui then R.ui.captureDialogOpen = true end
    if R.SuppressAutomationForContext then R:SuppressAutomationForContext() end
    return true
end

local function ShowConfirmation(title, message, callback, capture)
    if not CanOpenDialog() then
        if capture and R.ui then R.ui.captureDialogOpen = false end
        return false
    end
    local ok = pcall(ZO_Dialogs_ShowGamepadDialog, CONFIRM_DIALOG, { title = title, message = message, confirm = callback, capture = capture })
    if not ok then
        if capture and R.ui then R.ui.captureDialogOpen = false end
        R:Notify("La confirmation n'a pas pu être ouverte. Réessayez.")
    end
    return ok
end

local function InitializeDialogs()
    ZO_Dialogs_RegisterCustomDialog(CONFIRM_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = function(dialog) return dialog.data.title end },
        mainText = { text = function(dialog) return dialog.data.message end },
        noChoiceCallback = EndCaptureDialog,
        finishedCallback = EndCaptureDialog,
        buttons = {
            { keybind = "DIALOG_PRIMARY", text = "Confirmer", callback = function(dialog)
                local capture, confirm = dialog.data.capture, dialog.data.confirm
                local ok = not confirm or pcall(confirm)
                if capture and R.ui then R.ui.captureDialogOpen = false end
                if not ok then R:Notify("L'action n'a pas pu être terminée. Réessayez.") end
                R:RefreshUI()
            end },
            { keybind = "DIALOG_NEGATIVE", text = "Annuler", callback = EndCaptureDialog },
        },
    })

    local enteredName = ""
    local function NameValue()
        return Trim(enteredName:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", ""))
    end
    local function CharacterCount(name)
        local _, count = name:gsub("[^\128-\191]", "")
        return count
    end
    local function ValidName()
        local name = NameValue()
        return name ~= "" and CharacterCount(name) <= 48 and #name <= 192
    end
    local editEntry = ZO_GamepadEntryData:New("Nom")
    editEntry.isEditControl = true
    editEntry.textChangedCallback = function(control)
        enteredName = control:GetText() or ""
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
    editEntry.setup = function(control, data, selected)
        control.highlight:SetHidden(not selected)
        control.editBoxControl.textChangedCallback = data.textChangedCallback
        -- Existing long names stay intact until the player deliberately edits.
        control.editBoxControl:SetMaxInputChars(math.max(48, CharacterCount(enteredName)))
        control.editBoxControl:SetText(enteredName)
    end
    editEntry.narrationText = ZO_GetDefaultParametricListEditBoxNarrationText

    local submitEntry = ZO_GamepadEntryData:New("Enregistrer")
    submitEntry.isSubmit = true
    submitEntry.setup = function(control, data, selected, reselecting, enabled, active)
        data:SetEnabled(ValidName())
        ZO_SharedGamepadEntry_OnSetup(control, data, selected, reselecting, ValidName(), active)
    end
    ZO_Dialogs_RegisterCustomDialog(RENAME_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        blockDialogReleaseOnPress = true,
        setup = function(dialog)
            local profile = dialog.data.id and Profile(dialog.data.id)
            enteredName = type(dialog.data.initial) == "string" and dialog.data.initial
                or (profile and ProfileName(profile, dialog.data.id) or "")
            editEntry.text = dialog.data.fieldLabel or "Nom"
            submitEntry.text = dialog.data.submitLabel or "Enregistrer"
            dialog:setupFunc()
        end,
        title = { text = function(dialog) return dialog.data.title or "Renommer le setup" end },

        mainText = { text = function(dialog) return dialog.data.instructions or "Sélectionnez le nom pour le modifier, puis Enregistrer. Les nouveaux noms sont limités à 48 caractères." end },
        noChoiceCallback = EndCaptureDialog,
        finishedCallback = EndCaptureDialog,
        parametricList = {
            { template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem", entryData = editEntry },
            { template = "ZO_GamepadTextFieldSubmitItem", entryData = submitEntry },
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = "Sélectionner",
                enabled = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    return data and (data.isEditControl or (data.isSubmit and ValidName() and (dialog.data.id ~= nil or not IsBusy())))
                end,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    local control = dialog.entryList:GetTargetControl()
                    if data and data.isEditControl and control then
                        control.editBoxControl:TakeFocus()
                    elseif data and data.isSubmit and ValidName() and (dialog.data.id ~= nil or not IsBusy()) then
                        local id, name, submit = dialog.data.id, NameValue(), dialog.data.submit
                        local ok, result
                        if submit then ok, result = pcall(submit, name)
                        elseif id then ok, result = pcall(R.RenameSetup, R, id, name)
                        else ok, result = pcall(R.SaveNewSetup, R, name, R.ui and R.ui.pageId) end
                        if not ok then
                            R:Notify("Le nom n'a pas pu être enregistré. Réessayez.")
                            return
                        end
                        if not result then return end
                        EndCaptureDialog(dialog)
                        ZO_Dialogs_ReleaseDialogOnButtonPress(RENAME_DIALOG)

                    end
                end,
            },
            { keybind = "DIALOG_NEGATIVE", text = "Annuler", callback = function(dialog)
                ZO_Dialogs_ReleaseDialogOnButtonPress(RENAME_DIALOG)
                EndCaptureDialog(dialog)
            end },
        },
    })
end

local Screen = ZO_Gamepad_ParametricList_Screen:Subclass()
local RESULT_LABELS = { success = "Chargé", error = "Échec", cancelled = "Annulé" }

function Screen:Initialize(control)
    self.page = "home"
    self.profileId = nil
    self.pageId = 1
    self.previewMode = "target"
    self.components = { gear = true, skills = true, champion = true }
    self.contentId, self.contentCategory, self.pageFilter = "general", "general", "any"
    self.expectedZoneId = nil
    self.captureDialogOpen = false
    self.selectionByPage = {}
    self.rows = {}
    local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
    local fragment = ZO_SimpleSceneFragment:New(control)
    fragment:SetHideOnSceneHidden(true)
    scene:AddFragment(fragment)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_RIGHT)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    self.headerData = { titleText = "Setup Assist" }
    self:SetListsUseTriggerKeybinds(true)
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    self:InitializePreview(control)
end

function Screen:OpenPage(page, id, zoneId)
    if page == "overview" and id == nil then
        local ok, preview = pcall(R.adapter.Preview, R.adapter)
        self.preview = ok and type(preview) == "table" and preview or nil
    end
    self.page, self.profileId, self.expectedZoneId = page, id, zoneId
    if page == "profile" then self.previewMode = "target" end
    self:Update()
end

function Screen:GoBack()
    if self.page == "contents" then self:OpenPage("home")
    elseif self.page == "content" then self:OpenPage((self.contentCategory == "general" or self.contentCategory == "dungeons") and "home" or "contents")
    elseif self.page == "contentPage" or self.page == "generalPage" or self.page == "contentPageOptions" then self:OpenPage("content")
    elseif self.page == "contentSlot" then self:OpenPage(self.slotReturnPage or "contentPage")
    elseif self.page == "raidRoutes" or self.page == "raidAdvanced" then self:OpenPage("contentPage")
    elseif self.page == "raidProgress" then self:OpenPage("contentPage")
    elseif self.page == "raidAddKind" then self:OpenPage(self.addRaidReturnPage or "contentPage")
    elseif self.page == "chooseContentProfile" then self:OpenPage("contentSlot")
    elseif self.page == "contentPoints" then self:OpenPage("contentSlot")
    elseif self.page == "aliasBosses" or self.page == "encounterAliases" then self:OpenPage("contentSlot")
    elseif self.page == "aliasMembers" then self:OpenPage("aliasBosses")
    elseif self.page == "pageFilter" or self.page == "contentDifficulty" then self:OpenPage("content")
    elseif self.page == "createContentDifficulty" then self:OpenPage("content")
    elseif self.page == "createContentRole" then self:OpenPage("createContentDifficulty")
    elseif self.page == "moveContentCategories" then self:OpenPage("contentPageOptions")
    elseif self.page == "moveContents" then self:OpenPage("moveContentCategories")
    elseif self.page == "moveContentDifficulty" then self:OpenPage("moveContentCategories")
    elseif self.page == "moveContentRole" then self:OpenPage("moveContentDifficulty")
    elseif (self.page == "automatic" or self.page == "journal") and HasContentModel() then self:OpenPage(self.optionsReturnPage or "settings")
    elseif self.page == "profile" and HasContentModel() then self:OpenPage(self.profileReturnPage or "generalPage")
    elseif self.page == "gear" or self.page == "skills" or self.page == "champion" then
        self:OpenPage(self.profileId and "profile" or "overview", self.profileId)
    elseif self.page == "overview" then
        self:OpenPage(self.overviewReturnPage or "home")
    elseif self.page == "bindBoss" or self.page == "bindTrash" then
        self:OpenPage("setupRules", self.profileId, self.expectedZoneId)
    elseif self.page == "partial" or self.page == "movePage" or self.page == "points" then
        self:OpenPage("profile", self.profileId)
    elseif self.page == "pageActions" then
        self:OpenPage("pages")
    elseif self.page == "setupRules" then
        self:OpenPage("profile", self.profileId)
    elseif self.page == "clearBoss" then
        self:OpenPage("automatic", nil, self.expectedZoneId)
    elseif self.page ~= "home" then
        self:OpenPage("home")
    else
        SCENE_MANAGER:HideCurrentScene()
    end
end

function Screen:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local data = self:GetMainList():GetTargetData()
                return data and data.action or "Sélectionner"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                local data = self:GetMainList():GetTargetData()
                return data and data.callback ~= nil
            end,
            enabled = function()
                local data = self:GetMainList():GetTargetData()
                return data and data:IsEnabled() and data.callback ~= nil
            end,
            callback = function()
                local data = self:GetMainList():GetTargetData()
                if data and data:IsEnabled() and data.callback then
                    local ok = pcall(data.callback)
                    if not ok then
                        self.captureDialogOpen = false
                        R:Notify("L'action n'a pas pu être terminée. Réessayez.")
                    end
                end
            end,
            sound = SOUNDS.GAMEPAD_MENU_FORWARD,
        },
        {
            name = "Charger",
            keybind = "UI_SHORTCUT_SECONDARY",
            enabled = function() return not IsBusy() end,
            visible = function()
                local data = self:GetMainList():GetTargetData()
                return (self.page == "home" or self.page == "generalPage" or self.page == "contentPage") and data and data.profileId ~= nil
            end,
            callback = function()
                local data = self:GetMainList():GetTargetData()
                if (self.page == "home" or self.page == "generalPage" or self.page == "contentPage") and data and Profile(data.profileId) and not IsBusy() then
                    if data.raidStepId and type(R.LoadRaidStep) == "function" then
                        local ok, problem = R:LoadRaidStep(self.contentId, self.pageId, data.raidStepId)
                        if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Cette étape ne peut pas être chargée maintenant.")) end
                    else R:EquipSetup(data.profileId, "manuel", false) end
                    R:RefreshUI()
                end
            end,
        },
        {
            name = "Pages", keybind = "UI_SHORTCUT_TERTIARY",
            visible = function() return HasContentModel() and (self.page == "generalPage" or self.page == "contentPage") or (not HasContentModel() and self.page == "home") end,
            callback = function() self:OpenPage(HasContentModel() and "content" or "pages") end,
        },
        {
            name = function() return self.previewMode == "current" and "Voir la cible" or "Voir l'actuel" end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            visible = function()
                local data = self:GetMainList():GetTargetData()
                return Profile((data and data.profileId) or self.profileId) ~= nil
            end,
            callback = function()
                self.previewMode = self.previewMode == "current" and "target" or "current"
                self:UpdateTooltip(self:GetMainList():GetTargetData()); self:RefreshKeybinds()
            end,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptorsWithSound(self.keybindStripDescriptor,
        GAME_NAVIGATION_TYPE_BUTTON, function() self:GoBack() end)
end

function Screen:AddEntry(key, text, details, callback, enabled, action, header, profileId, icon)
    local data = ZO_GamepadEntryData:New(text, type(icon) == "string" and icon or ICON)
    data:SetIconTintOnSelection(true)
    data:SetEnabled(enabled ~= false)
    data.key, data.callback, data.details = key, callback, details
    data.action, data.profileId = action or "Ouvrir", profileId
    if header then data:SetHeader(header) end
    self.rows[#self.rows + 1] = data
end

function Screen:UpdateTooltip(data)
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    self:UpdatePreview(data)
end

function Screen:OnSelectionChanged(list, selectedData, oldData)
    ZO_Gamepad_ParametricList_Screen.OnSelectionChanged(self, list, selectedData, oldData)
    self:UpdateTooltip(list:GetTargetData() or selectedData)
end

function Screen:OnTargetChanged(list, targetData, oldData, reachedTarget, targetIndex)
    ZO_Gamepad_ParametricList_Screen.OnTargetChanged(self, list, targetData, oldData, reachedTarget, targetIndex)
    self:UpdateTooltip(targetData)
end

function Screen:OnHide()
    ZO_Gamepad_ParametricList_Screen.OnHide(self)
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
end

function Screen:OnShowing()
    self.dirty = true
    ZO_Gamepad_ParametricList_Screen.OnShowing(self)
end

local function PageName(id)
    return PlainText(R:GetPageName(id), "Mes setups")
end

local function ShowNameDialog(data)
    if not CanOpenDialog() then return false end
    local ok = pcall(ZO_Dialogs_ShowGamepadDialog, RENAME_DIALOG, data)
    if not ok then R:Notify("Le clavier n'a pas pu être ouvert. Réessayez.") end
    return ok
end

function Screen:OpenContent(id)
    self.contentId, self.slotKey, self.pageFilter = id, nil, "any"
    self:OpenPage("content")
end

function Screen:OpenProfile(id, returnPage)
    self.profileReturnPage = returnPage
    local stepId = returnPage == "contentSlot" and StepId(self.slotKey) or nil
    self.raidLoadContext = stepId and { contentId = self.contentId, pageId = self.pageId, stepId = stepId } or nil
    self:OpenPage("profile", id)
end

function Screen:LoadProfile(id, components)
    if IsBusy() then return false end
    local context = self.raidLoadContext
    if context and type(R.LoadRaidStep) == "function" and type(R.GetEffectiveRaidStepProfile) == "function"
        and R:GetEffectiveRaidStepProfile(context.contentId, context.pageId, context.stepId) == id then
        local ok, problem = R:LoadRaidStep(context.contentId, context.pageId, context.stepId, components)
        if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Cette étape ne peut pas être chargée maintenant.")) end
        R:RefreshUI(); return ok
    end
    R:EquipSetup(id, "manuel", false, components); R:RefreshUI()
    return true
end

function Screen:BuildHome()
    if not HasContentModel() then self:BuildFreeSetups(); return end
    for _, category in ipairs(CATEGORIES) do
        local id, label = category[1], category[2]
        local help = id == "general" and "Vos setups et pages libres, y compris les sauvegardes des versions précédentes."
            or (id == "dungeons" and "Des pages communes à tous les donjons, avec vos setups Général, Boss et Trash."
            or (id == "favorites" and "Retrouvez les raids et la collection Donjons ajoutés aux favoris." or "Choisissez un contenu, puis ses pages et ses setups."))
        self:AddEntry("category:" .. id, label, help, function()
            self.contentCategory, self.contentQuery, self.contentDlc = id, nil, nil
            if id == "general" then self:OpenContent("general")
            elseif id == "dungeons" then self:OpenContent("dungeons:general")
            else self:OpenPage("contents") end
        end, true, "Ouvrir", id == "general" and "Mes setups" or nil)
    end
    self:AddEntry("settings", "Réglages", "Changements automatiques, historique et accès rapide.", function() self:OpenPage("settings") end, true, "Ouvrir", "Options")
    self:AddEntry("current", "Configuration actuelle", "Consultez les pièces, les deux barres et les étoiles Champion de votre personnage.", function()
        self.overviewReturnPage = "home"; self:OpenPage("overview")
    end, true, "Voir", "Mon personnage")
    self:AddCancelEntry()
end

function Screen:BuildContents(moving)
    local options = { query = self.contentQuery, dlc = self.contentDlc }
    local contents = Table(R:GetContentEntries(self.contentCategory, options))
    local count = 0
    for _, content in ipairs(contents) do
        if type(content) == "table" and (type(content.id) == "string" or type(content.id) == "number")
            and (content.category ~= "dungeons" or content.id == "dungeons:general") then
            local id, name = content.id, ContentName(content.id)
            count = count + 1
            self:AddEntry("content:" .. tostring(id), name, PlainText(content.description, "Ouvrez ce contenu pour choisir une page et préparer vos setups."), function()
                if moving then self.destinationContentId = id; self:OpenPage("moveContentDifficulty")
                else self:OpenContent(id) end
            end, not moving or not IsBusy(), moving and "Choisir" or "Ouvrir", content.favorite and "Favoris" or nil, nil, content.icon)
        end
    end
    if count == 0 then
        self:AddEntry("noContents", self.contentCategory == "favorites" and "Aucun favori" or "Aucun contenu trouvé",
            self.contentCategory == "favorites" and "Ouvrez un raid ou la collection Donjons et choisissez Ajouter aux favoris." or "Retirez le filtre de recherche pour afficher le catalogue complet.", nil, true)
    end
    self:AddEntry("searchContents", "Rechercher un contenu", "Entrez une partie de son nom. La recherche reste limitée à cette catégorie.", function()
        ShowNameDialog({ title = "Rechercher un contenu", fieldLabel = "Recherche", submitLabel = "Rechercher",
            instructions = "Sélectionnez le texte pour saisir une partie du nom, puis Rechercher.", initial = self.contentQuery or "", submit = function(value)
            self.contentQuery = value; self:Update(); return true
        end })
    end, true, "Rechercher", "Recherche")
    self:AddEntry("contentDlcFilter", "Catalogue : " .. (self.contentDlc == true and "DLC" or (self.contentDlc == false and "Jeu de base" or "Tout")),
        "Sélectionnez pour afficher tout le catalogue, les contenus du jeu de base ou les contenus DLC. L'accès en jeu dépend de votre compte.", function()
        if self.contentDlc == nil then self.contentDlc = false elseif self.contentDlc == false then self.contentDlc = true else self.contentDlc = nil end
        self:Update()
    end, true, "Filtrer")
    if self.contentQuery then
        self:AddEntry("clearContentSearch", "Afficher tout", "Retire le filtre de recherche.", function() self.contentQuery = nil; self:Update() end, true, "Afficher")
    end
end

function Screen:BuildContent()
    local id = self.contentId
    local favorite = R:IsContentFavorite(id)
    if id ~= "general" then
        self:AddEntry("favorite", favorite and "Retirer des favoris" or "Ajouter aux favoris", "Ce raccourci restera accessible dans la catégorie Favoris.", function()
            R:SetContentFavorite(id, not R:IsContentFavorite(id)); R:RefreshUI()
        end, true, favorite and "Retirer" or "Ajouter", "Ce contenu")
        local selected = R:GetSelectedContentDifficulty(id)
        self:AddEntry("contentDifficulty", "Difficulté : " .. (selected == "any" and "Automatique" or DifficultyLabel(selected)),
            "Choisissez la difficulté utilisée par les changements automatiques. Hard Mode reste un choix manuel lorsque le jeu ne le confirme pas.", function() self:OpenPage("contentDifficulty") end, true, "Choisir")
    end
    self:AddEntry("pageFilter", "Pages : " .. (self.pageFilter == "any" and "Toutes" or DifficultyLabel(self.pageFilter)),
        "Ce filtre sert seulement à consulter les pages. Il ne change pas la difficulté de vos chargements automatiques.", function() self:OpenPage("pageFilter") end, true, "Filtrer", "Mes pages")
    local pages = Table(R:GetPageEntries(id, self.pageFilter))
    local active = R:GetActiveContentPage(id, R:GetContentDifficulty(id))
    for _, page in ipairs(pages) do
        if type(page) == "table" and type(page.id) == "number" then
            local pageId, difficulty, role = page.id, page.difficulty or "any", page.role or "any"
            local name = PlainText(page.name, PageName(pageId))
            self:AddEntry("contentPage:" .. tostring(pageId), name .. (active == pageId and " · sélectionnée" or ""),
                DifficultyLabel(difficulty) .. " · " .. RoleLabel(role) .. ". Ouvrez pour consulter les setups de cette page.", function()
                self.pageId = pageId; self:OpenPage(id == "general" and "generalPage" or "contentPage")
            end, true, "Ouvrir", DifficultyLabel(difficulty))
        end
    end
    if #pages == 0 then self:AddEntry("noContentPages", "Aucune page", "Créez une page pour préparer les setups de ce contenu.", nil, true) end
    self:AddEntry("createContentPage", "Créer une page", "Choisissez sa difficulté, son rôle et son nom. Aucun setup ne sera créé automatiquement.", function()
        self:OpenPage("createContentDifficulty")
    end, not IsBusy(), "Créer", "Organiser")
end

function Screen:BuildDifficulty(kind)
    local content = Table(R:GetContent(kind == "move" and self.destinationContentId or self.contentId))
    local hardUnavailable = Table(Table(content.difficulty).hardMode).supported == false
    for _, difficulty in ipairs(DIFFICULTIES) do
        local value = difficulty[1]
        if not ((kind == "create" or kind == "move") and value == "hard" and hardUnavailable) then
        local label = value == "any" and (kind == "filter" and "Toutes les pages" or (kind == "override" and "Automatique" or "Toutes difficultés")) or difficulty[2]
        local description = value == "any" and (kind == "override" and "Utilise la difficulté connue du jeu. Choisissez Hard Mode manuellement si nécessaire." or "Les pages communes peuvent servir dans plusieurs difficultés.")
            or "Les setups resteront regroupés sous cette difficulté."
        self:AddEntry("difficulty:" .. value, label, description, function()
            if kind == "filter" then self.pageFilter = value; self:OpenPage("content")
            elseif kind == "override" then
                local ok, problem = R:SetContentDifficulty(self.contentId, value)
                if ok then self:OpenPage("content") elseif type(problem) == "string" then R:Notify(PlainText(problem, "Cette difficulté n'est pas disponible.")) end
            else self.newPageDifficulty = value; self:OpenPage(kind == "move" and "moveContentRole" or "createContentRole") end
        end, kind == "filter" or not IsBusy(), "Choisir")
        end
    end
end

function Screen:BuildContentRole(moving)
    for _, role in ipairs(ROLES) do
        local value, label = role[1], role[2]
        self:AddEntry("role:" .. value, label, "Le rôle sert à reconnaître cette page. Il ne change pas votre personnage.", function()
            if IsBusy() then return end
            if moving then
                local pageId, destination, difficulty = self.pageId, self.destinationContentId, self.newPageDifficulty
                ShowConfirmation("Déplacer « " .. PageName(pageId) .. " » ?",
                    "Les associations aux emplacements de l'ancien contenu seront retirées. Les setups restent conservés. Destination : " .. ContentName(destination) .. " — " .. DifficultyLabel(difficulty) .. ".", function()
                    if IsBusy() then return end
                    local ok, problem = R:MovePageToContent(pageId, destination, difficulty, value)
                    if ok then self.contentId, self.pageFilter = destination, "any"; self:OpenPage("contentPageOptions")
                    elseif type(problem) == "string" then R:Notify(PlainText(problem, "Cette page ne peut pas être déplacée ici.")) end
                end)
            else
                local contentId, difficulty = self.contentId, self.newPageDifficulty
                ShowNameDialog({ title = "Créer une page", initial = "Nouvelle page", submit = function(name)
                    local pageId = R:CreateContentPage(contentId, difficulty, name, value)
                    if pageId then
                        self.pageId = pageId; self:OpenPage(contentId == "general" and "generalPage" or "contentPage")
                    end
                    return pageId
                end })
            end
        end, not IsBusy(), moving and "Déplacer" or "Choisir")
    end
end

function Screen:BuildContentPage()
    local contentId, pageId = self.contentId, self.pageId
    self:AddEntry("contentPageOptions", "Gérer cette page", "Sélectionnez cette page pour l'automatique, renommez-la, dupliquez-la ou déplacez-la.", function() self:OpenPage("contentPageOptions") end, true, "Ouvrir", "Page : " .. PageName(pageId))
    if HasRaidSteps(contentId, pageId) then
        local route = type(R.GetRaidRoute) == "function" and Table(R:GetRaidRoute(contentId, pageId)) or {}
        self:AddEntry("raidRoutes", "Parcours : " .. PlainText(route.name, "Standard"), PlainText(route.description, "Choisissez l'ordre des étapes adapté à votre groupe. Changer de parcours ne charge aucun setup."), function()
            self:OpenPage("raidRoutes")
        end, not IsBusy(), "Choisir")
        if route.personalized then
            self:AddEntry("personalizedRaidRoute", "Parcours personnalisé", route.orderModified and "L'ordre a été modifié. Utilisez les actions Charger et Reprendre ; cet ordre personnalisé ne confirme aucune victoire et ne permet pas de supposer la progression du groupe."
                or "Les noms ont été personnalisés. Les étapes officielles et leurs conditions de reconnaissance restent conservées.", nil, true)
        end
        self:AddEntry("raidProgress", "Tentative en cours", "Consultez la progression, reprenez à une étape ou recommencez. La reconnaissance, la victoire et le chargement sont indiqués séparément.", function()
            self:OpenPage("raidProgress")
        end, true, "Voir")
        for index, step in ipairs(RaidSteps(contentId, pageId)) do
            if type(step) == "table" and type(step.key) == "string" then self:AddContentSlotRow(step, index) end
        end
        if #RaidSteps(contentId, pageId) == 0 then self:AddEntry("noRaidSteps", "Aucun emplacement dans ce parcours", "Ajoutez un emplacement ou rétablissez le parcours officiel depuis les options avancées.", nil, true) end
        if type(R.AddRaidStep) == "function" then
            self:AddEntry("addRaidStep", "Ajouter un emplacement", "Ajoutez un setup libre, une portion Trash ou une étape Boss. Aucun combat ni aucune victoire ne seront inventés.", function()
                self.addRaidAfterStep, self.addRaidReturnPage = nil, "contentPage"; self:OpenPage("raidAddKind")
            end, not IsBusy(), "Ajouter", "Organiser")
        end
        self:AddEntry("raidAdvanced", "Options avancées", "Setups par défaut, anciennes associations, points de préparation et noms de boss reconnus.", function()
            self:OpenPage("raidAdvanced")
        end, true, "Ouvrir", "Autres réglages")
    else
        for _, slot in ipairs(Table(R:GetContentSlots(contentId, pageId))) do self:AddContentSlotRow(slot) end
    end
    self:AddCancelEntry()
end

function Screen:AddContentSlotRow(slot, index)
    local contentId, pageId = self.contentId, self.pageId
        if type(slot) == "table" and type(slot.key) == "string" then
            local key, name = slot.key, PlainText(slot.name, "Emplacement")
            local profileId, source = EffectiveProfile(contentId, pageId, key)
            local profile = Profile(profileId)
            local description = PlainText(slot.description, "Enregistrez la configuration actuelle ou choisissez un setup déjà enregistré.")
            if slot.available == false then description = description .. " Cet emplacement n'est pas encore disponible." end
            if slot.verified == false then description = description .. " Le déclenchement automatique reste à valider en jeu." end
            local state = ""
            if index then state = self:RaidStepState(slot.id) end
            local setupLabel = profile and ProfileName(profile, profileId) or "Aucun setup"
            if source == "trash" or source == "boss" then setupLabel = "Hérité · " .. setupLabel end
            if index then description = state .. "\n" .. description end
            self:AddEntry("contentSlot:" .. key, (index and (tostring(index) .. ". ") or "") .. name .. " : " .. setupLabel, description, function()
                self.slotKey, self.slotName, self.slotDescription = key, name, description
                self.slotEncounterId = slot.encounterId
                self.slotReturnPage = self.page
                self:OpenPage("contentSlot")
            end, slot.available ~= false, "Ouvrir", index and (slot.kind == "trash" and "Trash" or (slot.kind == "boss" and "Boss" or "Setup libre")) or nil, profile and profileId or nil)
            if index then self.rows[#self.rows].raidStepId = slot.id end
        end
end

function Screen:BuildRaidRoutes()
    local contentId, pageId = self.contentId, self.pageId
    local selected = type(R.GetRaidRoute) == "function" and Table(R:GetRaidRoute(contentId, pageId)) or {}
    local routes = type(R.GetRaidRoutes) == "function" and Table(R:GetRaidRoutes(contentId, pageId)) or {}
    for _, route in ipairs(routes) do
        if type(route) == "table" and type(route.id) == "string" then
            local id, name = route.id, PlainText(route.name, "Parcours")
            self:AddEntry("raidRoute:" .. id, name .. (selected.id == id and " · choisi" or ""), PlainText(route.description, "Choisissez ce parcours pour cette page."), function()
                if IsBusy() then return end
                if selected.id == id then self:OpenPage("contentPage"); return end
                ShowConfirmation("Choisir « " .. name .. " » ?", "Le suivi de la tentative sera réinitialisé. Choisissez ensuite le point de reprise si votre groupe est déjà en cours. Les setups enregistrés resteront conservés ; les étapes propres à un autre parcours seront accessibles en choisissant ce parcours.", function()
                    if IsBusy() then return end
                    local ok, problem = R:SetRaidRoute(contentId, pageId, id)
                    if ok then self:OpenPage("contentPage") else R:Notify(PlainText(problem, "Ce parcours n'est plus disponible.")) end
                end)
            end, not IsBusy(), "Choisir")
        end
    end
    if #routes == 0 then self:AddEntry("noRaidRoutes", "Aucun autre parcours", "Revenez aux étapes pour préparer cette page.", nil, true) end
end

function Screen:BuildRaidAdvanced()
    local contentId, pageId = self.contentId, self.pageId
    local notes = type(R.GetRaidMigrationNotes) == "function" and Table(R:GetRaidMigrationNotes(contentId, pageId)) or {}
    if #notes > 0 then
        self:AddEntry("raidMigrationNotes", "Anciennes associations à vérifier", tostring(#notes) .. " anciennes associations n'ont pas été attribuées à une étape unique. Elles restent accessibles ci-dessous ; choisissez vous-même leur nouvelle étape pour éviter un déplacement incorrect.", nil, true)
    end
    self:AddEntry("raidDefaults", "Setups de secours", "Sans setup dédié, une étape Trash utilise le Trash par défaut ; une étape Boss utilise le Boss par défaut. Les anciennes sauvegardes restent conservées.", nil, true)
    for _, slot in ipairs(Table(R:GetContentSlots(contentId, pageId))) do
        if type(slot) == "table" and not StepId(slot.key) then
            if type(slot.key) == "string" and (slot.key:match("^encounter:") or slot.key:match("^after:")) then
                local legacy = {}; for key, value in pairs(slot) do legacy[key] = value end
                legacy.name = "Ancienne association · " .. PlainText(slot.name, "Rencontre")
                legacy.description = "Association conservée des anciennes versions. Pour ce parcours, affectez le setup à l'étape correspondante dans la liste principale. Les noms reconnus restent modifiables ici."
                self:AddContentSlotRow(legacy)
            else self:AddContentSlotRow(slot) end
        end
    end
    if type(R.RestoreRaidRoute) == "function" then
        self:AddEntry("restoreRaidRoute", "Rétablir le parcours officiel", "Retrouve les étapes, les noms et l'ordre du catalogue. Les setups restent enregistrés ; les emplacements ajoutés seront retirés de la liste.", function()
            ShowConfirmation("Rétablir le parcours officiel ?", "L'organisation personnalisée de ce parcours sera retirée. Les setups resteront enregistrés et accessibles ici. La tentative devra être reprise.", function()
                if IsBusy() then return end
                local ok, problem = R:RestoreRaidRoute(contentId, pageId)
                if ok then self:OpenPage("contentPage") else R:Notify(PlainText(problem, "Ce parcours ne peut pas être rétabli.")) end
            end)
        end, not IsBusy(), "Rétablir", "Organiser")
    end
    for _, id in ipairs(Table(R.db.order)) do
        local profile = Profile(id)
        if profile and (profile.pageId or 1) == pageId then
            local profileId = id
            self:AddEntry("savedPageProfile:" .. tostring(profileId), ProfileName(profile, profileId), "Sauvegarde conservée dans cette page, même si son emplacement a été retiré. Ouvrez pour la consulter, la charger ou l'organiser.", function()
                self:OpenProfile(profileId, "raidAdvanced")
            end, true, "Ouvrir", "Sauvegardes de cette page", profileId)
        end
    end
end

function Screen:BuildRaidAddKind()
    local contentId, pageId, after = self.contentId, self.pageId, self.addRaidAfterStep
    for _, entry in ipairs({ { "free", "Setup libre", "Un emplacement manuel, sans reconnaissance automatique de combat." },
        { "trash", "Portion Trash", "Un setup pour une portion personnalisée du parcours, sans progression automatique supposée." },
        { "boss", "Étape Boss", "Un setup Boss personnalisé. Ajouter un nom ne reconnaît aucun boss et ne confirme aucune victoire." } }) do
        local kind, label, description = entry[1], entry[2], entry[3]
        self:AddEntry("raidStepKind:" .. kind, label, description, function()
            if IsBusy() then return end
            ShowNameDialog({ title = "Ajouter un emplacement", fieldLabel = "Nom de l'emplacement", initial = label, submit = function(name)
                local stepId, problem = R:AddRaidStep(contentId, pageId, name, kind, after)
                if not stepId then R:Notify(PlainText(problem, "Cet emplacement n'a pas pu être ajouté.")); return false end
                local step = Table(R:GetRaidStep(contentId, pageId, stepId))
                self.slotKey, self.slotName, self.slotDescription = "stage:" .. stepId, PlainText(step.name, name), PlainText(step.description, description)
                self.slotEncounterId, self.slotReturnPage = step.encounterId, "contentPage"
                self.slotFeedback = { contentId = contentId, pageId = pageId, key = self.slotKey, text = "Emplacement créé", details = "Enregistrez la configuration actuelle ou choisissez une sauvegarde existante pour cet emplacement." }
                self:OpenPage("contentSlot"); return true
            end })
        end, not IsBusy(), "Créer")
    end
end

function Screen:AddRaidStepManagement(stepId)
    if type(R.GetRaidStep) ~= "function" then return end
    local contentId, pageId = self.contentId, self.pageId
    local step = Table(R:GetRaidStep(contentId, pageId, stepId))
    local index, steps = nil, RaidSteps(contentId, pageId)
    for position, item in ipairs(steps) do if item.id == stepId then index = position; break end end
    if type(R.RenameRaidStep) == "function" then
        self:AddEntry("renameRaidStep", "Renommer l'emplacement", "Change le nom affiché. Renommer un Boss ne modifie pas sa reconnaissance par le jeu.", function()
            ShowNameDialog({ title = "Renommer l'emplacement", initial = PlainText(step.name, "Emplacement"), submit = function(name)
                local ok, problem = R:RenameRaidStep(contentId, pageId, stepId, name)
                if ok then self.slotName = PlainText(Table(R:GetRaidStep(contentId, pageId, stepId)).name, name); R:RefreshUI()
                else R:Notify(PlainText(problem, "Cet emplacement ne peut pas être renommé.")) end
                return ok
            end })
        end, not IsBusy(), "Renommer", "Organiser l'emplacement")
    end
    if type(R.MoveRaidStep) == "function" then
        for _, move in ipairs({ { -1, "Monter dans le parcours", "moveRaidStepUp" }, { 1, "Descendre dans le parcours", "moveRaidStepDown" } }) do
            local delta = move[1]
            self:AddEntry(move[3], move[2], "Change l'ordre de ce parcours personnalisé. La tentative devra être reprise manuellement.", function()
                if IsBusy() then return end
                local ok, problem = R:MoveRaidStep(contentId, pageId, stepId, delta)
                if not ok then R:Notify(PlainText(problem, "Cet emplacement ne peut pas être déplacé.")) end
                R:RefreshUI()
            end, not IsBusy() and index ~= nil and (delta < 0 and index > 1 or delta > 0 and index < #steps), "Déplacer")
        end
    end
    if type(R.DuplicateRaidStep) == "function" then
        self:AddEntry("duplicateRaidStep", "Dupliquer l'emplacement et son setup", "Crée un nouvel emplacement et une sauvegarde indépendante lorsque ce setup existe. L'original reste conservé.", function()
            if IsBusy() then return end
            local newId, problem = R:DuplicateRaidStep(contentId, pageId, stepId)
            if not newId then R:Notify(PlainText(problem, "Cet emplacement n'a pas pu être dupliqué.")); return end
            local duplicate = Table(R:GetRaidStep(contentId, pageId, newId))
            self.slotKey, self.slotName, self.slotDescription = "stage:" .. newId, PlainText(duplicate.name, "Copie de l'emplacement"), PlainText(duplicate.description, "Emplacement personnalisé.")
            self.slotEncounterId, self.slotReturnPage, self.slotFeedback = duplicate.encounterId, "contentPage", nil
            self:OpenPage("contentSlot")
        end, not IsBusy(), "Dupliquer")
    end
    if type(R.AddRaidStep) == "function" then
        self:AddEntry("addRaidStepAfter", "Ajouter un emplacement après celui-ci", "Choisissez Setup libre, Trash ou Boss, puis son nom.", function()
            self.addRaidAfterStep, self.addRaidReturnPage = stepId, "contentSlot"; self:OpenPage("raidAddKind")
        end, not IsBusy(), "Ajouter")
    end
    if type(R.RemoveRaidStep) == "function" then
        self:AddEntry("removeRaidStep", step.isOfficial and "Masquer cette étape" or "Retirer cet emplacement", "Retire l'emplacement du parcours sans effacer son setup. Les sauvegardes restent accessibles dans les options avancées.", function()
            ShowConfirmation("Retirer « " .. PlainText(step.name, "cet emplacement") .. " » ?", "Son setup restera enregistré. L'ordre de ce parcours sera personnalisé et la tentative devra être reprise. Les étapes officielles peuvent être rétablies depuis les options avancées.", function()
                if IsBusy() then return end
                local ok, problem = R:RemoveRaidStep(contentId, pageId, stepId)
                if ok then self.slotFeedback = nil; self:OpenPage("contentPage") else R:Notify(PlainText(problem, "Cet emplacement ne peut pas être retiré.")) end
            end)
        end, not IsBusy(), "Retirer", "Retirer de la page")
    end
end

function Screen:RaidStepState(stepId)
    if type(R.GetRaidStepStatus) ~= "function" then return "Progression en attente." end
    local ok, status, label, details = pcall(R.GetRaidStepStatus, R, self.contentId, self.pageId, stepId)
    if not ok then return "Progression en attente." end
    if type(status) == "string" then
        local labels = { recognized = "Rencontre reconnue", completed = "Victoire confirmée", selected = "Étape choisie", pending = "Chargement en attente", loaded = "Chargement vérifié", partial = "Chargement partiel vérifié", failed = "Chargement échoué", waiting = "À préparer", inactive = "Page non sélectionnée" }
        local text = PlainText(label, labels[status] or "À préparer")
        details = Table(details)
        if details.recognized and status ~= "recognized" then text = text .. " · Rencontre reconnue" end
        if details.victoryVerified and status ~= "completed" then text = text .. " · Victoire confirmée" end
        if details.pending and status ~= "pending" then text = text .. " · Chargement en attente" end
        if details.loaded and status ~= "loaded" and status ~= "partial" then text = text .. (details.partial and " · Chargement partiel vérifié" or " · Chargement vérifié") end
        if details.failed and status ~= "failed" then text = text .. " · Chargement échoué" end
        return text
    end
    status = Table(status)
    local labels = {}
    if status.recognized then labels[#labels + 1] = "Rencontre reconnue" end
    if status.completed then labels[#labels + 1] = "Victoire confirmée" end
    if status.pending then labels[#labels + 1] = "Chargement en attente" end
    if status.loaded then labels[#labels + 1] = "Chargement vérifié" end
    if status.current then labels[#labels + 1] = "Étape actuelle" end
    return #labels > 0 and table.concat(labels, " · ") or "À préparer"
end

function Screen:BuildRaidProgress()
    local progress = type(R.GetRaidProgress) == "function" and Table(R:GetRaidProgress(self.contentId, self.pageId)) or {}
    self:AddEntry("raidProgressInfo", progress.needsResume and "Reprise à confirmer" or "Progression de la tentative", progress.needsResume and "Choisissez l'étape où reprend votre groupe. Une disparition de boss ne confirme pas sa défaite." or "Choisissez une étape pour consulter ses actions. Seules les victoires confirmées font progresser la tentative.", nil, true)
    for index, step in ipairs(RaidSteps(self.contentId, self.pageId)) do self:AddContentSlotRow(step, index) end
    local contentId, pageId = self.contentId, self.pageId
    self:AddEntry("resetRaidProgress", "Recommencer la tentative", "Remet la progression au début de ce parcours. Aucun setup ne sera effacé ni chargé. Rejoignez ce raid et sortez du combat pour recommencer.", function()
        ShowConfirmation("Recommencer la tentative ?", "La progression de ce parcours sera remise au début. Les setups et leurs affectations restent conservés.", function()
            if IsBusy() then return end
            if type(R.ResetRaidProgress) == "function" then
                local ok, problem = R:ResetRaidProgress(contentId, pageId)
                if not ok then R:Notify(PlainText(problem, "Cette tentative ne peut pas être recommencée maintenant.")) end
                R:RefreshUI()
            end
        end)
    end, not IsBusy() and type(R.ResetRaidProgress) == "function", "Recommencer", "Tentative")
end

function Screen:BuildContentSlot()
    local contentId, pageId, key = self.contentId, self.pageId, self.slotKey
    local directProfileId = R:GetAssignedProfile(contentId, pageId, key)
    local profileId, source = EffectiveProfile(contentId, pageId, key)
    local profile = Profile(profileId)
    local stepId = StepId(key)
    if stepId then
        self:AddEntry("raidStepStatus", self:RaidStepState(stepId), "La reconnaissance, la victoire et le résultat du chargement sont suivis séparément. Choisir une étape manuellement ne confirme ni sa victoire ni son chargement.", nil, true)
        if source == "trash" or source == "boss" then
            self:AddEntry("inheritedSetup", "Setup hérité : " .. (source == "trash" and "Trash" or "Boss"), "Cet emplacement utilise le setup par défaut. Enregistrez ou choisissez un autre setup pour créer une affectation propre à cette étape.", nil, true)
        end
    end
    local feedback = self.slotFeedback
    if feedback and feedback.contentId == contentId and feedback.pageId == pageId and feedback.key == key then
        self:AddEntry("slotSavedFeedback", feedback.text, feedback.details or "La sauvegarde est associée à cet emplacement. L'ancien setup reste conservé.", nil, true)
    end
    self:AddEntry("slotInformation", self.slotName or "Emplacement", self.slotDescription or "Choisissez le setup à utiliser ici.", nil, true, nil, "Setup : " .. (profile and ProfileName(profile, profileId) or "Vide"), profile and profileId or nil)
    if profile then
        self:AddEntry("loadContentSlot", "Charger ce setup", "Applique le setup enregistré dans cet emplacement, hors combat.", function()
            if IsBusy() then return end
            if stepId and type(R.LoadRaidStep) == "function" then
                local ok, problem = R:LoadRaidStep(contentId, pageId, stepId)
                if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Cette étape ne peut pas être chargée maintenant.")) end
                R:RefreshUI()
            else R:EquipSetup(profileId, "manuel", false); R:RefreshUI() end
        end, not IsBusy(), "Charger", nil, profileId)
        self:AddEntry("openContentProfile", "Voir les actions du setup", "Chargement partiel, détails, mise à jour, nom et règles automatiques.", function()
            self:OpenProfile(profileId, "contentSlot")
        end, true, "Ouvrir", nil, profileId)
        if stepId then
            self:AddEntry("updateContentProfile", "Remplacer ce setup par l'actuel", "Met à jour la sauvegarde utilisée ici." .. SharedSetupWarning(profileId), function()
                if not BeginCaptureDialog() then return end
                self.slotFeedback = nil
                local inherited = source == "trash" or source == "boss"
                ShowConfirmation("Mettre à jour « " .. ProfileName(profile, profileId) .. " » ?", "La configuration actuelle remplacera cette sauvegarde."
                    .. (inherited and " Ce setup par défaut sert aussi aux étapes sans affectation propre." or "") .. SharedSetupWarning(profileId), function()
                    if R:UpdateSetup(profileId) then
                        self.slotFeedback = { contentId = contentId, pageId = pageId, key = key, text = "Mis à jour · " .. ProfileName(Profile(profileId), profileId) }
                    end
                    R:RefreshUI()
                end, true)
            end, not IsBusy(), "Remplacer", "Modifier la sauvegarde")
            self:AddEntry("duplicateContentProfile", "Créer une copie pour cette étape", "Crée une sauvegarde indépendante et l'affecte à cette étape. L'original reste conservé.", function()
                if IsBusy() then return end
                self.slotFeedback = nil
                local copy = R:DuplicateSetup(profileId)
                if copy then
                    if type(R.MoveSetupToPage) == "function" then R:MoveSetupToPage(copy, pageId) end
                    local ok, problem = R:AssignContentProfile(contentId, pageId, key, copy)
                    if ok then
                        self.slotFeedback = { contentId = contentId, pageId = pageId, key = key, text = "Copie affectée · " .. ProfileName(Profile(copy), copy) }
                    else R:Notify(PlainText(problem, "La copie reste enregistrée, mais n'a pas pu être affectée à cette étape.")) end
                    R:RefreshUI()
                end
            end, not IsBusy(), "Dupliquer")
        end
    end
    if stepId then
        self:AddEntry("selectRaidStep", "Reprendre à cette étape", "Choisit le point de reprise de cette tentative, sans charger de setup ni confirmer une victoire. Rejoignez ce raid et sortez du combat pour reprendre.", function()
            if IsBusy() or type(R.SelectRaidStep) ~= "function" then return end
            ShowConfirmation("Reprendre à « " .. (self.slotName or "cette étape") .. " » ?", "Cette étape deviendra le point de reprise. Aucune victoire ni aucun chargement ne seront confirmés par ce choix.", function()
                if IsBusy() then return end
                local ok, problem = R:SelectRaidStep(contentId, pageId, stepId)
                if not ok then R:Notify(PlainText(problem, "Cette tentative ne peut pas reprendre ici maintenant.")) end
                R:RefreshUI()
            end)
        end, not IsBusy() and type(R.SelectRaidStep) == "function", "Reprendre", "Progression")
        local step = type(R.GetRaidStep) == "function" and Table(R:GetRaidStep(contentId, pageId, stepId)) or {}
        if step.kind == "boss" and step.custom ~= true and type(R.BindRaidPreparationPoint) == "function" then
            local current = R:GetCurrentContent()
            local inRaid = type(current) == "table" and current.id == contentId
            self:AddEntry("bindRaidPreparationPoint", "Préparer ce boss depuis un point", "Placez-vous avant ce boss pour enregistrer votre position. Le point est lié à ce parcours et à cette étape ; il utilisera le setup de la page choisie pour l'automatique, hors combat.", function()
                if IsBusy() then return end
                local now = R:GetCurrentContent()
                if type(now) ~= "table" or now.id ~= contentId then R:Notify("Rejoignez ce raid pour enregistrer le point."); return end
                local ok, problem = R:BindRaidPreparationPoint(contentId, pageId, stepId, nil, R:GetZoneId())
                if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Ce point n'a pas pu être enregistré.")) end
                R:RefreshUI()
            end, not IsBusy() and profile ~= nil and inRaid, "Enregistrer", "Préparer le combat")
            if type(R.GetRaidPreparationPoints) == "function" then
                self:AddEntry("raidPreparationPoints", "Points de cette étape", "Consultez, renommez ou retirez les points de préparation de ce parcours et de cette étape, même depuis une autre zone.", function()
                    self:OpenPage("contentPoints")
                end, true, "Ouvrir")
            end
        end
    end
    if type(key) == "string" and key:match("^prepare:") then
        local encounterId = self.slotEncounterId or key:match("^prepare:(.+)$")
        local current = R:GetCurrentContent()
        local inContent = type(current) == "table" and current.id == contentId
        self:AddEntry("bindContentPoint", "Enregistrer un point près d'ici", "Placez-vous avant ce combat. L'emplacement du point sera partagé entre les pages de cette rencontre ; le setup chargé sera celui de la page choisie pour l'automatique. Il faut être dans ce contenu et avoir choisi un setup.", function()
            if IsBusy() then return end
            local now = R:GetCurrentContent()
            if type(now) ~= "table" or now.id ~= contentId then R:Notify("Rejoignez ce contenu pour enregistrer le point."); return end
            local ok, problem = R:BindPreparationPoint(contentId, encounterId, nil, R:GetZoneId(), pageId)
            if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Ce point n'a pas pu être enregistré.")) end
            R:RefreshUI()
        end, not IsBusy() and profile ~= nil and inContent, "Enregistrer", "Préparer le combat")
        self:AddEntry("contentPoints", "Points de cette rencontre", "Consultez, renommez ou retirez les points personnels de cette rencontre, même depuis une autre zone.", function()
            self:OpenPage("contentPoints")
        end, true, "Ouvrir")
    end
    if type(key) == "string" and key:match("^encounter:") then
        self:AddEntry("learnEncounterAlias", "Reconnaître un boss observé", "Choisissez un boss vivant reconnu par le jeu, puis le membre exact de cette rencontre. Cette association personnelle peut aider à reconnaître son nom dans votre langue.", function()
            self:OpenPage("aliasBosses")
        end, not IsBusy(), "Choisir", "Reconnaissance du boss")
        self:AddEntry("encounterAliases", "Noms reconnus", "Consultez ou retirez les noms personnels associés à cette rencontre.", function() self:OpenPage("encounterAliases") end)
    end
    self:AddEntry("captureContentSlot", profile and "Enregistrer un nouveau setup ici" or "Enregistrer le setup actuel ici", "Crée une nouvelle sauvegarde dans cette page. Votre ancien setup reste conservé.", function()
        if not BeginCaptureDialog() then return end
        self.slotFeedback = nil
        local ok, result, problem = pcall(R.CaptureContentSlot, R, contentId, pageId, key)
        self.captureDialogOpen = false
        if not ok then R:Notify("Le setup n'a pas pu être enregistré. Réessayez.")
        elseif not result and type(problem) == "string" then R:Notify(PlainText(problem, "Le setup n'a pas pu être enregistré.")) end
        if ok and result then self.slotFeedback = { contentId = contentId, pageId = pageId, key = key, text = "Enregistré · " .. ProfileName(Profile(result), result) } end
        R:RefreshUI()
    end, not IsBusy(), "Enregistrer", "Modifier")
    self:AddEntry("chooseContentProfile", "Choisir un setup enregistré", "Associe une sauvegarde existante à cet emplacement.", function() self:OpenPage("chooseContentProfile") end, not IsBusy(), "Choisir")
    if profile and (not stepId or directProfileId) then
        self:AddEntry("unassignContentProfile", stepId and "Retirer le setup dédié" or "Vider cet emplacement", stepId and "Retire l'affectation propre à cette étape. Le setup Trash ou Boss par défaut sera utilisé s'il existe. La sauvegarde reste conservée." or "Retire seulement l'association. Le setup enregistré et votre personnage restent inchangés.", function()
            ShowConfirmation("Vider « " .. (self.slotName or "cet emplacement") .. " » ?", "Le setup « " .. ProfileName(profile, profileId) .. " » restera enregistré.", function()
                if not IsBusy() then self.slotFeedback = nil; R:AssignContentProfile(contentId, pageId, key, nil); R:RefreshUI() end
            end)
        end, not IsBusy(), "Retirer")
    end
    if stepId then self:AddRaidStepManagement(stepId) end
    self:AddCancelEntry()
end

function Screen:BuildChooseContentProfile()
    local contentId, pageId, key = self.contentId, self.pageId, self.slotKey
    local count = 0
    for _, savedId in ipairs(Table(R.db.order)) do
        local profile, id = Profile(savedId), savedId
        if profile then
            count = count + 1
            self:AddEntry("assignProfile:" .. tostring(id), ProfileName(profile, id), "Page : " .. PageName(profile.pageId or 1) .. ". Le contenu du setup reste inchangé.", function()
                if IsBusy() then return end
                local ok, problem = R:AssignContentProfile(contentId, pageId, key, id)
                if ok then self.slotFeedback = nil; self:OpenPage("contentSlot")
                elseif type(problem) == "string" then R:Notify(PlainText(problem, "Ce setup ne peut pas être associé.")) end
            end, not IsBusy(), "Choisir", PageName(profile.pageId or 1), id)
        end
    end
    if count == 0 then self:AddEntry("noProfilesToAssign", "Aucun setup enregistré", "Revenez en arrière et choisissez Enregistrer le setup actuel ici.", nil, true) end
end

function Screen:BuildAliasBosses()
    local current = R:GetCurrentContent()
    if type(current) ~= "table" or current.id ~= self.contentId then
        self:AddEntry("aliasOutsideContent", "Rejoignez ce contenu", "Le boss doit être vivant et reconnu par le jeu dans le contenu choisi.", nil, true)
        return
    end
    local count = 0
    for _, observed in ipairs(Table(R:GetObservedBossNames())) do
        if type(observed) == "string" and observed ~= "" then
            local name = observed
            count = count + 1
            self:AddEntry("aliasBoss:" .. name, PlainText(name, "Boss"), "Sélectionnez ce boss observé puis indiquez le membre exact de la rencontre.", function()
                self.aliasObservedName, self.aliasExpectedZoneId = name, R:GetZoneId()
                self:OpenPage("aliasMembers")
            end, not IsBusy(), "Choisir")
        end
    end
    if count == 0 then self:AddEntry("noAliasBoss", "Aucun boss vivant reconnu", "Approchez-vous du boss et rouvrez cette liste. Aucun nom ne sera associé par supposition.", nil, true) end
end

function Screen:BuildAliasMembers()
    local encounterId = self.slotEncounterId or (type(self.slotKey) == "string" and self.slotKey:match("^encounter:(.+)$"))
    local encounter = Encounter(self.contentId, encounterId)
    if not encounter then self:AddEntry("missingEncounter", "Rencontre indisponible", "Revenez à la page du contenu et choisissez une rencontre disponible.", nil, true); return end
    local members = Table(encounter.members)
    if #members == 0 then members = { encounter } end
    local contentId, observed, expectedZoneId = self.contentId, self.aliasObservedName, self.aliasExpectedZoneId
    for _, member in ipairs(members) do
        if type(member) == "table" and type(member.id) == "string" then
            local memberId, memberName = member.id, ContentName(member)
            self:AddEntry("aliasMember:" .. memberId, memberName,
                "Nom observé : " .. PlainText(observed, "Boss indisponible") .. ". Confirmez seulement s'il s'agit bien de ce membre de la rencontre.", function()
                ShowConfirmation("Reconnaître « " .. PlainText(observed, "ce boss") .. " » ?",
                    "Ce nom observé sera associé personnellement à « " .. memberName .. " ». Vérifiez que vous avez choisi le bon membre de la rencontre.", function()
                    if IsBusy() then return end
                    local ok, problem = R:LearnEncounterAlias(contentId, encounterId, memberId, observed, expectedZoneId)
                    if ok then self:OpenPage("encounterAliases")
                    elseif type(problem) == "string" then R:Notify(PlainText(problem, "Ce boss ne peut pas être reconnu actuellement.")) end
                end)
            end, not IsBusy(), "Associer")
        end
    end
end

function Screen:BuildEncounterAliases()
    local encounterId = self.slotEncounterId or (type(self.slotKey) == "string" and self.slotKey:match("^encounter:(.+)$"))
    local encounter = Encounter(self.contentId, encounterId)
    local aliases = Table(R:GetLearnedEncounterAliases(self.contentId, encounterId))
    local count, contentId = 0, self.contentId
    for _, alias in ipairs(aliases) do
        if type(alias) == "table" and type(alias.language) == "string" and type(alias.key) == "string" then
            local language, key, name = alias.language, alias.key, PlainText(alias.name, "Boss reconnu")
            local memberName = encounter and ContentName(encounter) or "Rencontre indisponible"
            for _, member in ipairs(Table(encounter and encounter.members)) do if member.id == alias.memberId then memberName = ContentName(member); break end end
            local languageName = language == "fr" and "Français" or (language == "en" and "Anglais" or "Autre langue")
            count = count + 1
            self:AddEntry("encounterAlias:" .. language .. ":" .. key, name, languageName .. " — membre : " .. memberName .. ". Sélectionnez pour retirer cette association personnelle.", function()
                ShowConfirmation("Retirer « " .. name .. " » ?", "Ce nom ne sera plus reconnu grâce à cette association personnelle. Vos setups restent enregistrés.", function()
                    R:ForgetEncounterAlias(contentId, language, key); R:RefreshUI()
                end)
            end, not IsBusy(), "Retirer")
        end
    end
    if count == 0 then self:AddEntry("noEncounterAliases", "Aucun nom personnel enregistré", "Les noms déjà connus du catalogue restent disponibles. Ajoutez seulement un nom réellement observé si nécessaire.", nil, true) end
end

function Screen:BuildContentPageOptions()
    local contentId, difficulty = PageContext(self.pageId)
    local pageId = self.pageId
    self:AddEntry("openContentPage", "Voir les setups", "Ouvre les setups de cette page.", function()
        self.contentId = contentId; self:OpenPage(contentId == "general" and "generalPage" or "contentPage")
    end)
    self:AddEntry("activateContentPage", "Utiliser cette page pour l'automatique", DifficultyLabel(difficulty) .. " — les règles de ce contenu utiliseront les emplacements de cette page.", function()
        local ok, problem = R:SetActiveContentPage(contentId, difficulty, pageId)
        if not ok and type(problem) == "string" then R:Notify(PlainText(problem, "Cette page ne peut pas être sélectionnée.")) end
        R:RefreshUI()
    end, not IsBusy(), "Sélectionner", "Utilisation")
    if contentId ~= "general" then
        local initialTrash = R:IsInitialTrashEnabled(contentId, pageId)
        self:AddEntry("initialTrash", "Trash à l'entrée : " .. (initialTrash and "activé" or "désactivé"), "Facultatif : charge le setup Trash après votre entrée dans ce contenu, hors combat. L'automatique et la page sélectionnée doivent être actifs.", function()
            ShowConfirmation(initialTrash and "Désactiver le Trash à l'entrée ?" or "Activer le Trash à l'entrée ?",
                "Cette option change votre setup à l'entrée du contenu. Un choix manuel et les restrictions du combat restent prioritaires.", function()
                if not IsBusy() then R:SetInitialTrashEnabled(contentId, pageId, not initialTrash); R:RefreshUI() end
            end)
        end, not IsBusy(), initialTrash and "Désactiver" or "Activer")
    end
    if contentId == "dungeons:general" and type(R.IsDungeonBossObservationEnabled) == "function" and type(R.SetDungeonBossObservationEnabled) == "function" then
        local observedBosses = R:IsDungeonBossObservationEnabled(pageId)
        self:AddEntry("dungeonBossObservation", "Boss signalés par ESO : " .. (observedBosses and "activé" or "désactivé"),
            "Utiliser le setup Boss commun pour tous les boss signalés par le jeu dans un donjon reconnu. Cela ne confirme pas leur défaite. L'automatique et cette page doivent être actifs.", function()
            ShowConfirmation(observedBosses and "Désactiver les boss signalés par ESO ?" or "Activer les boss signalés par ESO ?",
                "Cette option utilise le setup Boss commun de cette page, sans reconnaître une victoire ni charger le Trash après une simple disparition.", function()
                if not IsBusy() then
                    local ok, problem = R:SetDungeonBossObservationEnabled(pageId, not observedBosses)
                    if not ok then R:Notify(PlainText(problem, "Cette page n'est plus disponible pour les donjons.")) end
                    R:RefreshUI()
                end
            end)
        end, not IsBusy(), observedBosses and "Désactiver" or "Activer")
    end
    self:AddEntry("renameContentPage", "Renommer la page", "Modifie son nom sans changer les setups.", function()
        ShowNameDialog({ title = "Renommer la page", initial = PageName(pageId), submit = function(name) return R:RenamePage(pageId, name) end })
    end, not IsBusy(), "Renommer", "Organiser")
    self:AddEntry("duplicateContentPage", "Dupliquer la page", "Crée une autre page avec ses emplacements. Les règles personnelles des setups restent conservées.", function()
        ShowNameDialog({ title = "Dupliquer la page", initial = "Copie de la page", submit = function(name)
            local newId = R:DuplicatePage(pageId, name)
            if newId then self.pageId = newId; self:OpenPage("contentPageOptions") end
            return newId
        end })
    end, not IsBusy(), "Dupliquer")
    local pages, index = Table(R:GetPageEntries(contentId)), nil
    for position, page in ipairs(pages) do if page.id == pageId then index = position; break end end
    self:AddEntry("moveContentPageUp", "Monter dans le contenu", "Place cette page avant la précédente de ce contenu.", function()
        if not IsBusy() then R:MovePage(pageId, -1); R:RefreshUI() end
    end, not IsBusy() and index ~= nil and index > 1, "Monter")
    self:AddEntry("moveContentPageDown", "Descendre dans le contenu", "Place cette page après la suivante de ce contenu.", function()
        if not IsBusy() then R:MovePage(pageId, 1); R:RefreshUI() end
    end, not IsBusy() and index ~= nil and index < #pages, "Descendre")
    if pageId ~= 1 then
        self:AddEntry("moveContentPage", "Déplacer vers un autre contenu", "Conserve la page et ses setups. Choisissez le contenu, la difficulté et le rôle de destination.", function() self:OpenPage("moveContentCategories") end, not IsBusy(), "Déplacer")
        self:AddEntry("deleteContentPage", "Supprimer la page", "Les setups seront conservés dans Général. Les emplacements de cette page seront retirés.", function()
            ShowConfirmation("Supprimer « " .. PageName(pageId) .. " » ?", "Les setups resteront enregistrés dans Général. Les associations de cette page seront retirées.", function()
                if not IsBusy() and R:DeletePage(pageId) then self.pageId = 1; self:OpenPage("content") end
            end)
        end, not IsBusy(), "Supprimer", "Supprimer")
    end
end

function Screen:BuildMoveContentCategories()
    for _, category in ipairs(CATEGORIES) do
        local id, label = category[1], category[2]
        self:AddEntry("moveCategory:" .. id, label, "Choisissez le contenu de destination.", function()
            self.contentCategory, self.contentQuery, self.contentDlc = id, nil, nil
            if id == "general" or id == "dungeons" then
                self.destinationContentId = id == "dungeons" and "dungeons:general" or "general"; self:OpenPage("moveContentDifficulty")
            else self:OpenPage("moveContents") end
        end, not IsBusy(), "Choisir")
    end
end

function Screen:BuildSettings()
    if type(R.GetContentDetectionSummary) == "function" then
        local ok, summary = pcall(R.GetContentDetectionSummary, R)
        self:AddEntry("contentDetection", "Reconnaissance du contenu", ok and PlainText(summary, "Reconnaissance en attente.") or "Reconnaissance en attente.", nil, true)
    end
    if type(R.IsAutomaticContentNavigationEnabled) == "function" and type(R.SetAutomaticContentNavigation) == "function" then
        local enabled = R:IsAutomaticContentNavigationEnabled()
        self:AddEntry("automaticNavigation", "Ouvrir le contenu actuel : " .. (enabled and "activé" or "désactivé"), "À l'ouverture de Setup Assist, affiche directement le contenu où se trouve le personnage. Cela ne charge aucun setup.", function()
            R:SetAutomaticContentNavigation(not R:IsAutomaticContentNavigationEnabled()); R:RefreshUI()
        end, true, enabled and "Désactiver" or "Activer")
    end
    self:AddEntry("automatic", "Changements automatiques", "Activez ou désactivez les changements et consultez les associations de la zone actuelle.", function()
        self.optionsReturnPage = "settings"
        self:OpenPage("automatic", nil, R:GetZoneId())
    end, true, "Ouvrir")
    self:AddEntry("journal", "Historique", "Les derniers chargements, erreurs et annulations.", function() self.optionsReturnPage = "settings"; self:OpenPage("journal") end)
    self:AddEntry("bankHelp", "Pièces en banque", "Dans votre banque personnelle, utilisez le raccourci Setup Assist pour retirer ou déposer les pièces. Les coffres de maison et la banque de guilde ne sont pas pris en charge.", nil, true)
    if R.radialAvailable then self:AddEntry("radialHelp", "Accès rapide par la roue", "Configurez la roue pour ouvrir Setup Assist ou charger le setup choisi.", nil, true) end
    self:AddCancelEntry()
end

function Screen:BuildFreeSetups()
    local currentPage = self.pageId
    if not Table(R.db.pages)[currentPage] then self.pageId, currentPage = 1, 1 end
    self:AddEntry("pages", "Page : " .. PageName(currentPage), "Choisissez une page ou organisez vos setups par rôle et contenu.", function()
        if HasContentModel() then self:OpenContent("general") else self:OpenPage("pages") end
    end, true, "Choisir", "Mes pages")
    if HasContentModel() then
        self:AddEntry("contentPageOptions", "Gérer cette page", "Renommer, dupliquer et organiser cette page.", function() self:OpenPage("contentPageOptions") end)
    end
    self:AddEntry("current", "Configuration actuelle", "L'aperçu affiche vos pièces, les sets de chaque barre et vos étoiles Champion. Ouvrez pour consulter les noms complets.", function()
        self.overviewReturnPage = HasContentModel() and "generalPage" or "home"; self:OpenPage("overview")
    end, true, "Voir", "Mon personnage")
    local first = true
    for _, profileId in ipairs(Table(R.db and R.db.order)) do
        local id, profile = profileId, Profile(profileId)
        if profile and (profile.pageId or 1) == currentPage then
            self:AddEntry("profile:" .. tostring(id), ProfileName(profile, id),
                "L'aperçu compare ce setup à votre personnage. Ouvrez pour charger, modifier ou organiser.",
                function() if HasContentModel() then self:OpenProfile(id, "generalPage") else self:OpenPage("profile", id) end end, true, "Ouvrir", first and PageName(currentPage) or nil, id)
            first = false
        end
    end
    if first then
        self:AddEntry("emptySetups", "Aucun setup dans cette page", "Préparez votre personnage, puis choisissez Enregistrer le setup actuel. Le nouveau setup apparaîtra ici.", nil, true, nil, PageName(currentPage))
    end
    self:AddEntry("save", "Enregistrer le setup actuel", "Enregistre l'équipement, les deux barres et les étoiles Champion dans cette page. Le nom peut ensuite être modifié.", function()
        if not BeginCaptureDialog() then return end
        local ok, id = pcall(R.SaveNewSetup, R, nil, self.pageId)
        self.captureDialogOpen = false
        if ok and id and Profile(id) then
            if HasContentModel() then self:OpenProfile(id, "generalPage") else self:OpenPage("profile", id) end
            local selectionKey = (HasContentModel() and "generalPage:" or "home:") .. tostring(self.pageId)
            if HasContentModel() then selectionKey = selectionKey .. ":" .. tostring(self.contentCategory) .. ":" .. tostring(self.contentId) .. ":" .. tostring(self.slotKey) .. ":" .. tostring(self.pageFilter) end
            self.selectionByPage[selectionKey] = { key = "profile:" .. tostring(id), index = 1 }
        else
            if not ok then R:Notify("Impossible d'enregistrer le setup. Réessayez après le chargement.") end
            R:RefreshUI()
        end
    end, not IsBusy(), "Enregistrer", "Créer un setup")
    self:AddCancelEntry()
    self:AddEntry("automatic", "Changements automatiques", "Automatique : " .. (AutomaticEnabled() and "activé" or "désactivé") .. ". Consultez les règles des setups et les associations de cette zone.", function()
        self.optionsReturnPage = HasContentModel() and "generalPage" or "home"
        self:OpenPage("automatic", nil, R:GetZoneId())
    end, true, "Ouvrir", "Options")
    self:AddEntry("journal", "Historique", "Les derniers chargements et leurs résultats restent consultables ici.", function() self.optionsReturnPage = HasContentModel() and "generalPage" or "home"; self:OpenPage("journal") end)
    if R.radialAvailable then
        self:AddEntry("radialHelp", "Accès rapide par la roue", "Configurez la roue dans ses réglages : ouvrir Setup Assist ou charger le setup choisi. Les restrictions du jeu restent applicables.", nil, true)
    end
end

function Screen:AddCancelEntry()
    if IsBusy() then
        self:AddEntry("cancel", R.bankTransfer and "Annuler le transfert" or "Annuler le changement",
            R.bankTransfer and "Les pièces déjà déplacées restent à leur place." or "Les étapes déjà terminées restent appliquées.", function()
            R:CancelRequest(); R:RefreshUI()
        end, true, "Annuler", "Chargement")
    end
end

function Screen:BuildProfile(profile, id)
    local name = ProfileName(profile, id)
    self:AddEntry("load", "Charger ce setup", "Charge équipement, compétences et étoiles Champion. Les pièces absentes ou compétences indisponibles sont signalées avant l'application.", function()
        self:LoadProfile(id)
    end, not IsBusy(), "Charger")
    self:AddEntry("partial", "Choisir les éléments à charger", "Chargez uniquement l'équipement, les compétences ou les étoiles Champion.", function()
        self.components = { gear = true, skills = true, champion = true }
        self:OpenPage("partial", id)
    end, not IsBusy(), "Choisir")
    self:AddOverviewEntries(id)
    self:AddCancelEntry()
    self:AddEntry("update", "Enregistrer les changements", "Remplace cette sauvegarde par la configuration actuelle du personnage.", function()
        if not BeginCaptureDialog() then return end
        local context, inherited = self.raidLoadContext, false
        if context and type(R.GetEffectiveRaidStepProfile) == "function" then
            local effective, source = R:GetEffectiveRaidStepProfile(context.contentId, context.pageId, context.stepId)
            inherited = effective == id and (source == "trash" or source == "boss")
        end
        ShowConfirmation("Mettre à jour « " .. name .. " » ?", "La configuration actuelle remplacera le setup enregistré."
            .. (inherited and " Ce setup par défaut sert aussi aux étapes sans affectation propre." or "") .. SharedSetupWarning(id), function()
            R:UpdateSetup(id); R:RefreshUI()
        end, true)
    end, not IsBusy(), "Enregistrer", "Modifier")
    self:AddEntry("rename", "Renommer", "Modifiez le nom avec le clavier de la console.", function()
        ShowNameDialog({ id = id })
    end, not IsBusy(), "Renommer")
    self:AddEntry("duplicate", "Dupliquer", "Crée une copie dans la même page. Les règles automatiques restent associées au setup original.", function()
        if IsBusy() then return end
        local copy = R:DuplicateSetup(id)
        if copy then self:OpenPage("profile", copy) end
    end, not IsBusy(), "Dupliquer")
    self:AddEntry("movePage", "Déplacer dans une page", "Déplace le setup sans modifier son contenu ni ses règles.", function()
        self:OpenPage("movePage", id)
    end, not IsBusy(), "Déplacer")
    local order, index = {}, nil
    for _, savedId in ipairs(Table(R.db.order)) do
        local item = Profile(savedId)
        if item and (item.pageId or 1) == (profile.pageId or 1) then
            order[#order + 1] = savedId
            if savedId == id then index = #order end
        end
    end
    self:AddEntry("moveUp", "Monter dans la page", "Place ce setup avant le précédent.", function()
        if not IsBusy() then R:MoveSetup(id, -1); R:RefreshUI() end
    end, not IsBusy() and index ~= nil and index > 1, "Monter")
    self:AddEntry("moveDown", "Descendre dans la page", "Place ce setup après le suivant.", function()
        if not IsBusy() then R:MoveSetup(id, 1); R:RefreshUI() end
    end, not IsBusy() and index ~= nil and index < #order, "Descendre")
    self:AddEntry("rules", "Règles automatiques", "Consultez les zones, boss et points associés à ce setup.", function()
        self:OpenPage("setupRules", id, R:GetZoneId())
    end, true, "Ouvrir", "Utiliser automatiquement")
    if R.ShowBankDialog then
        self:AddEntry("bank", "Pièces en banque", "Pour retirer ou déposer les pièces, ouvrez votre banque personnelle puis utilisez son raccourci Setup Assist. Les coffres de maison et la banque de guilde ne sont pas pris en charge.", nil, true, nil, "Équipement")
    end
    self:AddEntry("delete", "Supprimer ce setup", "Retire la sauvegarde et ses règles automatiques.", function()
        ShowConfirmation("Supprimer « " .. name .. " » ?", "Le setup et ses règles seront supprimés. Votre personnage reste inchangé.", function()
            if IsBusy() then R:Notify("Attendez la fin du changement."); return end
            R:DeleteSetup(id)
            if not Profile(id) then self:OpenPage(HasContentModel() and (self.profileReturnPage or "generalPage") or "home") end
        end)
    end, not IsBusy(), "Supprimer", "Supprimer")
end

function Screen:BuildPartial(id)
    for _, entry in ipairs({ { "gear", "Équipement" }, { "skills", "Compétences" }, { "champion", "Étoiles Champion" } }) do
        local key, label = entry[1], entry[2]
        self:AddEntry("component:" .. key, label .. (self.components[key] and " : inclus" or " : exclu"), "Sélectionnez pour inclure ou exclure cet élément du prochain chargement.", function()
            self.components[key] = not self.components[key]; self:Update()
        end, not IsBusy(), self.components[key] and "Exclure" or "Inclure")
    end
    local any = self.components.gear or self.components.skills or self.components.champion
    self:AddEntry("loadSelected", "Charger la sélection", "Les éléments exclus restent tels qu'ils sont sur votre personnage.", function()
        if IsBusy() or not any then return end
        local components = { gear = self.components.gear, skills = self.components.skills, champion = self.components.champion }
        self:LoadProfile(id, components)
    end, not IsBusy() and any, "Charger")
    self:AddCancelEntry()
end

function Screen:BuildPages(moveId)
    for _, pageId in ipairs(Table(R:GetPageIds())) do
        local id = pageId
        self:AddEntry("page:" .. tostring(id), PageName(id), moveId and "Déplace le setup dans cette page." or "Ouvrez cette page ou modifiez son nom.", function()
            if moveId then
                if IsBusy() then return end
                if R:MoveSetupToPage(moveId, id) then self.pageId = id; self:OpenPage("profile", moveId) end
            else
                self.pageId = id; self:OpenPage("pageActions")
            end
        end, not moveId or not IsBusy(), moveId and "Déplacer" or "Ouvrir")
    end
    if not moveId then
        self:AddEntry("createPage", "Créer une page", "Par exemple : Donjons, Raid ou Tank.", function()
            ShowNameDialog({ title = "Créer une page", initial = "Nouvelle page", submit = function(name)
                local id = R:CreatePage(name)
                if id then self.pageId = id; self:OpenPage("home") end
                return id
            end })
        end, not IsBusy(), "Créer", "Organiser")
    end
end

function Screen:BuildPageActions()
    local id, name = self.pageId, PageName(self.pageId)
    self:AddEntry("openPage", "Voir les setups", "Affiche les setups de « " .. name .. " ».", function() self:OpenPage("home") end)
    self:AddEntry("renamePage", "Renommer la page", "Modifie uniquement le nom de cette page.", function()
        ShowNameDialog({ title = "Renommer la page", initial = name, submit = function(value)
            return R:RenamePage(id, value)
        end })
    end, not IsBusy(), "Renommer")
    if id ~= 1 then
        self:AddEntry("deletePage", "Supprimer la page", "Les setups seront déplacés dans « " .. PageName(1) .. " » et conservés.", function()
            ShowConfirmation("Supprimer « " .. name .. " » ?", "Les setups de cette page seront déplacés dans « " .. PageName(1) .. " ». Aucun setup ne sera supprimé.", function()
                if IsBusy() then return end
                if R:DeletePage(id) then self.pageId = 1; self:OpenPage("pages") end
            end)
        end, not IsBusy(), "Supprimer")
    end
end

function Screen:AddOverviewEntries(id)
    self:AddEntry("gear", "Équipement", "Affiche les pièces enregistrées, les armes et les noms de leurs sets.", function()
        self:OpenPage("gear", id)
    end, true, "Voir", "Contenu du setup", nil, GEAR_ICON)
    self:AddEntry("skills", "Compétences", "Affiche séparément les cinq compétences et l'ultime de chaque barre.", function()
        self:OpenPage("skills", id)
    end, true, "Voir", nil, nil, ICON)
    self:AddEntry("champion", "Étoiles Champion", "Affiche les étoiles équipées enregistrées dans ce setup.", function()
        self:OpenPage("champion", id)
    end, true, "Voir", nil, nil, CHAMPION_ICON)
end

function Screen:BuildOverview()
    if not self.preview then
        self:AddEntry("unavailable", "Configuration en attente", "Fermez cet écran et rouvrez Configuration actuelle après le chargement du personnage.", nil, true)
        return
    end
    self:AddOverviewEntries(nil)
end

function Screen:BuildEquipment(profile)
    local gear = Table(profile.gear)
    local inspection = Table(Inspect(profile).gear)
    for index, slot in ipairs(EquipmentSlots()) do
        local item = Table(gear[slot[1]])
        local inspected = Table(inspection[slot[1]])
        local name = item.uid == "0" and "Vide" or PlainText(inspected.name, PlainText(item.name, "Vide"))
        local setName = PlainText(item.setName)
        local details = slot[2] .. "\n" .. name .. (setName and ("\n\nSet : " .. setName) or "") .. Availability(inspection[slot[1]])
        self:AddEntry("item:" .. tostring(index), slot[2] .. " : " .. name, details, nil, true, nil,
            index == 1 and "Armure et bijoux" or (index == 11 and "Barre principale" or (index == 13 and "Barre de secours" or nil)), nil, inspected.icon or item.icon or GEAR_ICON)
    end
end

function Screen:BuildSkills(profile)
    local first, last = SkillSlots()
    local inspection = Table(Inspect(profile).skills)
    for barIndex, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        local bar = Table(Table(profile.skills)[category])
        for slot = first, last do
            local skill = Table(bar[slot])
            local inspected = Table(Table(inspection[category])[slot])
            local name = skill.id == 0 and "Vide" or PlainText(inspected.name, PlainText(skill.name, "Vide"))
            local label = slot == last and "Ultime" or ("Compétence " .. tostring(slot - first + 1))
            self:AddEntry("skill:" .. tostring(barIndex) .. ":" .. tostring(slot), label .. " : " .. name,
                (barIndex == 1 and "Barre principale" or "Barre de secours") .. "\n" .. label .. "\n" .. name .. Availability(Table(inspection[category])[slot]),
                nil, true, nil, slot == first and (barIndex == 1 and "Barre principale" or "Barre de secours") or nil, nil, inspected.icon or skill.icon)
        end
    end
end

function Screen:BuildChampion(profile)
    local first, last = ChampionSlots()
    local inspection = Table(Inspect(profile).champion)
    local previousDiscipline
    for slot = first, last do
        local id = Table(profile.champion)[slot]
        if type(id) ~= "number" or id < 0 then id = 0 end
        local name = id == 0 and "Vide" or ReadText(GetChampionSkillName, "Étoile indisponible", id)
        local discipline
        if type(GetRequiredChampionDisciplineIdForSlot) == "function" then
            local ok, value = pcall(GetRequiredChampionDisciplineIdForSlot, slot, HOTBAR_CATEGORY_CHAMPION)
            if ok then discipline = value end
        end
        local header
        if slot == first or discipline ~= previousDiscipline then
            header = discipline and ReadText(GetChampionDisciplineName, "Champion", discipline) or "Champion"
        end
        previousDiscipline = discipline
        self:AddEntry("champion:" .. tostring(slot), "Étoile " .. tostring(slot - first + 1) .. " : " .. name,
            "Étoile Champion équipée\n" .. name .. Availability(inspection[slot]), nil, true, nil, header, nil, Table(inspection[slot]).icon or CHAMPION_ICON)
    end
end

function Screen:BuildAutomatic()
    local automatic = AutomaticEnabled()
    self:AddEntry("toggle", automatic and "Désactiver l'automatique" or "Activer l'automatique",
        "Les règles attendent la sortie du combat. Le choix manuel est conservé jusqu'à un changement de zone, de boss ou de point.", function()
            R:ToggleAutomatic()
            R:RefreshUI()
        end, true, automatic and "Désactiver" or "Activer")
    local zoneId = self.expectedZoneId
    if not zoneId or zoneId == 0 or R:GetZoneId() ~= zoneId then
        self:AddEntry("zoneChanged", "Zone indisponible", "Revenez à l'accueil et rouvrez ce menu après le chargement de la zone souhaitée.", nil, false)
        return
    end
    local id = ZoneRules()[zoneId]
    if id then
        local name = ProfileName(Profile(id), id)
        self:AddEntry("clearZone", "Setup de la zone : " .. name,
            "Ce setup est utilisé lorsqu'aucun boss ou point associé n'est prioritaire. Sélectionnez pour retirer cette association.", function()
            ShowConfirmation("Retirer le setup de cette zone ?", "« " .. name .. " » restera enregistré. Cette zone ne déclenchera plus son chargement.", function()
                if SameZone(zoneId) then R:ClearZoneRule(zoneId); R:RefreshUI() end
            end)
        end, true, "Retirer", "Cette zone")
    else
        self:AddEntry("noZone", "Aucun setup pour cette zone", "Ouvrez un setup depuis l'accueil, puis ses changements automatiques, pour l'associer à cette zone.", nil, false, nil, "Cette zone")
    end
    self:AddEntry("bosses", "Associations de boss", "Consultez ou retirez les associations de cette zone, même si le boss est absent.", function()
        self:OpenPage("clearBoss", nil, zoneId)
    end)
end

function Screen:BuildSetupRules(profile, id)
    local descriptions = R.GetRuleDescriptions and Table(R:GetRuleDescriptions(id)) or {}
    for index, text in ipairs(descriptions) do
        self:AddEntry("rule:" .. tostring(index), PlainText(text, "Association enregistrée"), "Les règles de ce setup sont conservées pour leur zone.", nil, true, nil, index == 1 and "Associations enregistrées" or nil)
    end
    self:AddEntry("points", "Points de passage", "Consultez, renommez ou retirez chaque point associé à ce setup.", function()
        self:OpenPage("points", id)
    end, true, "Ouvrir")
    local zoneId = self.expectedZoneId
    if not zoneId or zoneId == 0 or R:GetZoneId() ~= zoneId then
        self:AddEntry("zoneChanged", "La zone a changé", "Revenez aux actions du setup et rouvrez ce menu dans la zone souhaitée.", nil, false)
        return
    end
    local name, zoneLabel = ProfileName(profile, id), R:GetZoneLabel() or "cette zone"
    local existingId = ZoneRules()[zoneId]
    local zoneDetails = "Zone : " .. zoneLabel .. "\nCe setup sera utilisé lorsqu'aucun boss ou point associé n'est prioritaire."
    if existingId then zoneDetails = zoneDetails .. "\nSetup de la zone : " .. ProfileName(Profile(existingId), existingId) end
    self:AddEntry("bindZone", "Utiliser dans cette zone", zoneDetails, function()
        local message = "« " .. name .. " » sera utilisé dans " .. zoneLabel .. " lorsque l'automatique est activé."
        if existingId and existingId ~= id then
            message = message .. " L'association avec « " .. ProfileName(Profile(existingId), existingId) .. " » sera remplacée."
        end
        ShowConfirmation("Associer ce setup à la zone ?", message, function()
            if SameZone(zoneId) then R:BindZone(id, zoneId); R:RefreshUI() end
        end)
    end, true, "Associer")
    self:AddEntry("bindPoint", "Utiliser près d'ici", "Enregistre votre position. Ce setup se chargera lorsque vous reviendrez à proximité, hors combat. Placez-vous devant un boss pour préparer son combat.", function()
        if SameZone(zoneId) then R:BindPosition(id, nil, zoneId); R:RefreshUI() end
    end, true, "Enregistrer")
    self:AddEntry("bindBoss", "Utiliser pour un boss", "Choisissez un boss actuellement reconnu par le jeu. Pour préparer un combat avant son apparition, utilisez plutôt un point de passage.", function()
        self:OpenPage("bindBoss", id, zoneId)
    end, true, "Choisir")
    self:AddEntry("bindTrash", "Utiliser après un boss vaincu", "Choisissez un boss pour charger ce setup après une victoire confirmée. Un wipe ne déclenche pas cette règle.", function()
        self:OpenPage("bindTrash", id, zoneId)
    end, true, "Choisir")
    local points = PositionCount(id, zoneId)
    if points > 0 then
        local details = points == 1 and "Un point est associé à ce setup dans cette zone." or (tostring(points) .. " points sont associés à ce setup dans cette zone.")
        self:AddEntry("clearPoints", "Retirer les points de cette zone", details, function()
            ShowConfirmation("Retirer ces points ?", "Tous les points de « " .. name .. " » dans cette zone seront retirés. Le setup restera enregistré.", function()
                if SameZone(zoneId) then R:ClearPositionRule(id, zoneId); R:RefreshUI() end
            end)
        end, true, "Retirer", "Retirer une association")
    end
    if existingId == id then
        self:AddEntry("clearZone", "Retirer le setup de cette zone", "Le setup restera enregistré. Les points et associations de boss seront conservés.", function()
            ShowConfirmation("Retirer le setup de cette zone ?", "Cette zone ne déclenchera plus « " .. name .. " ». Ses points et associations de boss seront conservés.", function()
                if SameZone(zoneId) then R:ClearZoneRule(zoneId); R:RefreshUI() end
            end)
        end, true, "Retirer", points == 0 and "Retirer une association" or nil)
    end
end

function Screen:BuildBossChoices(profile, id)
    local zoneId = self.expectedZoneId
    local afterVictory = self.page == "bindTrash"
    if not zoneId or zoneId == 0 or R:GetZoneId() ~= zoneId then
        self:AddEntry("zoneChanged", "La zone a changé", "Revenez aux actions du setup et rouvrez la liste dans la zone souhaitée.", nil, false)
        return
    end
    local names = Table(R:GetObservedBossNames())
    if self.page == "bindTrash" and R.GetKnownBossNames then
        names = Table(R:GetKnownBossNames(zoneId))
    elseif self.page == "bindTrash" then
        local combined, seen = {}, {}
        for _, value in ipairs(names) do if type(value) == "string" then combined[#combined + 1], seen[value:lower()] = value, true end end
        local savedNames = BossAssociations(zoneId)
        for _, value in ipairs(savedNames) do if not seen[value:lower()] then combined[#combined + 1] = value end end
        names = combined
    end
    local count = 0
    for _, observedName in ipairs(names) do
        if type(observedName) == "string" and observedName ~= "" then
            local name = observedName
            count = count + 1
            self:AddEntry("boss:" .. name, PlainText(name, "Boss"), "Associe ce boss à « " .. ProfileName(profile, id)
                .. " » dans cette zone. Une ancienne association de ce boss sera remplacée.", function()
                ShowConfirmation("Associer « " .. PlainText(name, "Boss") .. " » ?", "« " .. ProfileName(profile, id)
                    .. " » sera utilisé " .. (afterVictory and "après une victoire contre ce boss" or "pour ce boss") .. " lorsque l'automatique est activé.", function()
                    local bound
                    if afterVictory then bound = R:BindTrashAfterBoss(id, name, zoneId)
                    else bound = R:BindBossName(id, name, zoneId) end
                    if bound then self:OpenPage("setupRules", id, zoneId) end
                    R:RefreshUI()
                end)
            end, true, "Associer")
        end
    end
    if count == 0 then
        self:AddEntry("noBoss", "Aucun boss reconnu", "Approchez-vous d'un boss vivant, puis rouvrez cette liste. Pour préparer son combat avant son apparition, revenez en arrière et choisissez Utiliser près d'ici.", nil, false)
    end
end

function Screen:BuildBossAssociations()
    local zoneId = self.expectedZoneId
    if not zoneId or zoneId == 0 or R:GetZoneId() ~= zoneId then
        self:AddEntry("zoneChanged", "La zone a changé", "Revenez à l'accueil et rouvrez les changements automatiques dans la zone souhaitée.", nil, false)
        return
    end
    local names, rules = BossAssociations(zoneId)
    local trash = Table(Table(Table(R.db and R.db.rules).trashAfterBosses)[zoneId])
    if #names == 0 and not next(trash) then
        self:AddEntry("noBossRules", "Aucune association de boss", "Ouvrez un setup depuis l'accueil, puis ses changements automatiques, pour l'associer à un boss reconnu.", nil, false)
        return
    end
    for _, savedName in ipairs(names) do
        local name, id = savedName, rules[savedName]
        local profileName = ProfileName(Profile(id), id)
        self:AddEntry("boss:" .. name, PlainText(name, "Boss"), "Setup : " .. profileName
            .. "\nSélectionnez pour retirer l'association. Le setup restera enregistré.", function()
            ShowConfirmation("Retirer « " .. PlainText(name, "Boss") .. " » ?", "« " .. profileName
                .. " » restera enregistré. Ce boss ne déclenchera plus son chargement dans cette zone.", function()
                R:ClearBossAssociation(name, zoneId)
                R:RefreshUI()
            end)
        end, true, "Retirer")
    end
    local trashNames = {}
    for name in pairs(trash) do if type(name) == "string" then trashNames[#trashNames + 1] = name end end
    table.sort(trashNames)
    for _, savedName in ipairs(trashNames) do
        local name, id = savedName, trash[savedName]
        self:AddEntry("trash:" .. name, "Après " .. PlainText(name, "le boss"),
            "Setup : " .. ProfileName(Profile(id), id) .. ". Chargé uniquement après une victoire confirmée dans cette zone.", function()
            ShowConfirmation("Retirer cette association après victoire ?", "Le setup restera enregistré.", function()
                R:ClearTrashAfterBoss(name, zoneId); R:RefreshUI()
            end)
        end, true, "Retirer", "Après une victoire")
    end
end

function Screen:BuildJournal()
    local log, count = Table(R.db and R.db.log), 0
    for index = #log, math.max(1, #log - 24), -1 do
        local result = log[index]
        if type(result) == "table" then
            count = count + 1
            local profile = result.profileId and Profile(result.profileId)
            local fallback = profile and ProfileName(profile, result.profileId) or (result.profileId and "Setup supprimé" or "Changement")
            local name = PlainText(result.profileName, fallback)
            local message = PlainText(result.message, "Aucun détail disponible.")
            self:AddEntry(result, (RESULT_LABELS[result.state] or "Résultat") .. " — " .. name, message)
        end
    end
    if count == 0 then self:AddEntry("emptyLog", "Aucun chargement récent", "Les chargements, erreurs et annulations apparaîtront ici.", nil, false) end
end


function Screen:BuildPoints(id)
    local points = R.GetPointEntries and Table(R:GetPointEntries(id)) or {}
    self:AddPointEntries(points)
end

function Screen:BuildContentPoints()
    local stepId = StepId(self.slotKey)
    if stepId and type(R.GetRaidPreparationPoints) == "function" then
        self:AddPointEntries(Table(R:GetRaidPreparationPoints(self.contentId, self.pageId, stepId)), "Revenez avant ce boss pour enregistrer un point personnel de ce parcours et de cette étape.", true)
        return
    end
    local encounterId = self.slotEncounterId or (type(self.slotKey) == "string" and self.slotKey:match("^prepare:(.+)$"))
    local points = type(R.GetContentPointEntries) == "function" and Table(R:GetContentPointEntries(self.contentId, encounterId)) or {}
    self:AddPointEntries(points, "Revenez à l'emplacement de préparation pour enregistrer un point personnel dans ce contenu.", true)
end

function Screen:AddPointEntries(points, advice, shared)
    if #points == 0 then
        self:AddEntry("noPoints", "Aucun point enregistré", advice or "Dans les règles du setup, choisissez Utiliser près d'ici pour enregistrer votre position.", nil, true)
    end
    for _, point in ipairs(points) do
        local key, zone, name = point.key, point.zoneId, PlainText(point.name, "Point de passage")
        local zoneName = PlainText(point.zoneName, "Zone inconnue")
        self:AddEntry("point:" .. tostring(key), name, zoneName .. (point.needsRerecording and " — position à enregistrer à nouveau." or " — déclenche le setup à proximité, hors combat.")
            .. (shared and " Cet emplacement est partagé entre les pages de cette rencontre." or ""), nil, true, nil, zoneName)
        self:AddEntry("renamePoint:" .. tostring(key), "Renommer ce point", "Donnez un nom facile à reconnaître, par exemple Entrée du boss.", function()
            ShowNameDialog({ title = "Renommer le point", initial = name, submit = function(value)
                return R:RenamePointById(key, value, zone)
            end })
        end, not IsBusy(), "Renommer")
        self:AddEntry("removePoint:" .. tostring(key), "Retirer ce point", "Le setup et ses autres règles resteront enregistrés.", function()
            ShowConfirmation("Retirer « " .. name .. " » ?", shared and ("Ce point de « " .. zoneName .. " » sera retiré pour toutes les pages de cette rencontre.")
                or ("Ce point de « " .. zoneName .. " » ne déclenchera plus ce setup."), function()
                R:RemovePointById(key, zone); R:RefreshUI()
            end)
        end, not IsBusy(), "Retirer")
    end
end

function Screen:InitializePreview(control)
    self.previewControl = control:GetNamedChild("Preview"):GetNamedChild("Content")
    self.gearControls, self.skillControls, self.championControls = {}, {}, {}
    local gearParent = self.previewControl:GetNamedChild("Equipment")
    for index = 1, 14 do
        local row = WINDOW_MANAGER:CreateControlFromVirtual("RelaisGamepadControlPreviewGear" .. tostring(index), gearParent, "RelaisPreviewGearRow")
        row:SetAnchor(TOPLEFT, gearParent, TOPLEFT, index > 7 and 394 or 0, ((index - 1) % 7) * 42)
        self.gearControls[index] = row
    end
    for barIndex, parentName in ipairs({ "Primary", "Backup" }) do
        local parent = self.previewControl:GetNamedChild(parentName)
        self.skillControls[barIndex] = {}
        for index = 1, 6 do
            local icon = WINDOW_MANAGER:CreateControlFromVirtual("RelaisGamepadControlPreviewSkill" .. tostring(barIndex) .. "Slot" .. tostring(index), parent, "RelaisPreviewAbility")
            icon:SetAnchor(TOPLEFT, parent, TOPLEFT, (index - 1) * 62, 0)
            self.skillControls[barIndex][index] = icon
        end
    end
    local championParent = self.previewControl:GetNamedChild("Champion")
    for index = 1, 12 do
        local icon = WINDOW_MANAGER:CreateControlFromVirtual("RelaisGamepadControlPreviewChampion" .. tostring(index), championParent, "RelaisPreviewAbility")
        icon:SetAnchor(TOPLEFT, championParent, TOPLEFT, (index - 1) * 64, 0)
        self.championControls[index] = icon
    end
end

local EMPTY_ICON = "EsoUI/Art/Quickslots/quickslot_emptySlot.dds"
local function RenderIcon(control, item, fallback)
    item = Table(item)
    control:GetNamedChild("Icon"):SetTexture(type(item.icon) == "string" and item.icon ~= "" and item.icon or EMPTY_ICON)
    control:GetNamedChild("Name"):SetText(PlainText(item.name, fallback or "Vide"))
    local missing = item.missing or item.available == false
    control:GetNamedChild("State"):SetText(missing and "!" or (item.different and "•" or ""))
    control:GetNamedChild("Icon"):SetColor(missing and 1 or 1, missing and 0.45 or 1, missing and 0.3 or 1, 1)
end

function Screen:UpdatePreview(data)
    if not self.previewControl then return end
    local id = (data and data.profileId) or self.profileId
    if not id and HasContentModel() and self.page == "contentSlot" then id = EffectiveProfile(self.contentId, self.pageId, self.slotKey) end
    local target = id and Profile(id)
    if target then R.selectedProfileId = id end
    local current, inspection
    local ok, value = pcall(R.adapter.Preview, R.adapter)
    if ok and type(value) == "table" then current = value end
    local shown = self.previewMode == "current" and current or (target or current)
    if shown and type(R.adapter.InspectProfile) == "function" then
        ok, value = pcall(R.adapter.InspectProfile, R.adapter, shown)
        if ok and type(value) == "table" then inspection = value end
    end
    inspection = Table(inspection)
    local comparisonInspection = inspection
    if target and self.previewMode == "current" and type(R.adapter.InspectProfile) == "function" then
        comparisonInspection = {}
        local comparisonOK, compared = pcall(R.adapter.InspectProfile, R.adapter, target)
        if comparisonOK and type(compared) == "table" then comparisonInspection = compared end
    end
    local summary = Table(comparisonInspection.summary)
    local title = target and ((self.previewMode == "current" and "Actuel — " or "Cible — ") .. ProfileName(target, id)) or "Configuration actuelle"
    self.previewControl:GetNamedChild("Title"):SetText(title)
    local differences = string.format("Différences : %d pièces · %d compétences · %d étoiles", tonumber(summary.differentGear) or 0, tonumber(summary.differentSkills) or 0, tonumber(summary.differentChampion) or 0)
    local unavailable = (tonumber(summary.missingGear) or 0) + (tonumber(summary.unavailableSkills) or 0) + (tonumber(summary.unavailableChampion) or 0)
    local comparison = not shown and "Configuration indisponible. Rouvrez après le chargement."
        or ((not next(inspection) or (target and type(comparisonInspection.summary) ~= "table")) and "Comparaison indisponible. Les noms enregistrés restent consultables.")
        or (target and (differences .. (unavailable > 0 and ("\n" .. tostring(unavailable) .. " éléments indisponibles — ouvrez les détails.") or "\n• À changer  ·  ! Indisponible")) or "Vos pièces, compétences et étoiles actuellement équipées.")
    self.previewControl:GetNamedChild("Comparison"):SetText(comparison)
    for barIndex, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        local names = {}
        for _, set in ipairs(Table(Table(comparisonInspection.sets)[category])) do
            names[#names + 1] = PlainText(set.name, "Set") .. " (" .. tostring(set.count or 0) .. " → " .. tostring(set.targetCount or "?") .. ")"
        end
        local empty = type(comparisonInspection.sets) == "table" and "Aucun set" or "Sets indisponibles"
        self.previewControl:GetNamedChild(barIndex == 1 and "SetsPrimary" or "SetsBackup"):SetText((barIndex == 1 and "Principale (actuel → cible) : " or "Secours (actuel → cible) : ") .. (#names > 0 and table.concat(names, ", ") or empty))
    end
    for index, slot in ipairs(EquipmentSlots()) do
        local saved = Table(Table(shown and shown.gear)[slot[1]])
        local item = Table(Table(inspection.gear)[slot[1]])
        if not next(item) then item = saved end
        local row = self.gearControls[index]
        RenderIcon(row, item)
        row:GetNamedChild("State"):SetText(slot[2] .. (item.missing and " · ABSENT" or (item.available == false and " · Indisponible" or (item.different and " · À changer" or ""))))
    end
    local first = SkillSlots()
    for barIndex, category in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
        for index = 1, 6 do
            local slot = first + index - 1
            local item = Table(Table(Table(inspection.skills)[category])[slot])
            if not next(item) then item = Table(Table(Table(shown and shown.skills)[category])[slot]) end
            RenderIcon(self.skillControls[barIndex][index], item)
        end
    end
    local cpFirst = ChampionSlots()
    for index = 1, 12 do
        local slot = cpFirst + index - 1
        local item = Table(Table(inspection.champion)[slot])
        if not next(item) then
            local skillId = Table(shown and shown.champion)[slot]
            item = { name = type(skillId) == "number" and skillId > 0 and ReadText(GetChampionSkillName, "Étoile", skillId) or "Vide", icon = CHAMPION_ICON }
        end
        RenderIcon(self.championControls[index], item)
    end
    self.previewControl:GetNamedChild("Help"):SetText(PlainText(data and data.details, "Préparez votre personnage puis enregistrez votre premier setup. Les noms complets sont disponibles dans les détails."))
    self.previewControl:GetNamedChild("Status"):SetText("État : " .. StatusText())
    self.previewInspection = inspection
end

function Screen:PerformUpdate()
    local list = self:GetMainList()
    if self.page == "overview" or ((self.page == "gear" or self.page == "skills" or self.page == "champion") and not self.profileId) then
        local ok, current = pcall(R.adapter.Preview, R.adapter)
        self.preview = ok and type(current) == "table" and current or nil
    end
    local profile = self.profileId and Profile(self.profileId)
    if (self.page == "profile" or self.page == "setupRules" or self.page == "bindBoss" or self.page == "bindTrash"
        or ((self.page == "gear" or self.page == "skills" or self.page == "champion") and self.profileId)) and not profile then
        self.page, self.profileId, self.expectedZoneId = "home", nil, nil
    end
    if (self.page == "profile" or self.page == "partial" or self.page == "movePage" or self.page == "points") and not profile then self.page, self.profileId = "home", nil end
    if HasContentModel() and (self.page == "generalPage" or self.page == "contentPage" or self.page == "contentPageOptions" or self.page == "contentSlot" or self.page == "chooseContentProfile" or self.page == "raidRoutes" or self.page == "raidProgress" or self.page == "raidAdvanced" or self.page == "raidAddKind") then
        if not Table(R.db.pages)[self.pageId] then self.page, self.profileId = "content", nil
        elseif PageContext(self.pageId) ~= self.contentId then self.page, self.profileId = "content", nil end
    end
    if HasContentModel() and (self.page == "contentSlot" or self.page == "chooseContentProfile") and StepId(self.slotKey)
        and type(R.GetRaidStep) == "function" and not R:GetRaidStep(self.contentId, self.pageId, StepId(self.slotKey)) then
        self.page, self.profileId = "contentPage", nil
    end
    local pageKey = self.page .. ":" .. tostring(self.profileId or self.pageId or "")
    if HasContentModel() then
        local slotPage = self.page == "contentSlot" or self.page == "chooseContentProfile" or self.page == "contentPoints"
            or self.page == "aliasBosses" or self.page == "aliasMembers" or self.page == "encounterAliases"
        pageKey = pageKey .. ":" .. tostring(self.contentCategory) .. ":" .. tostring(self.contentId) .. ":" .. tostring(slotPage and self.slotKey or nil) .. ":" .. tostring(self.pageFilter)
    end
    self.rows = {}
    if HasContentModel() and (self.page == "contents" or self.page == "moveContents") then
        self.headerData.titleText = self.contentCategory == "raids" and "Raids" or (self.contentCategory == "favorites" and "Favoris" or "Donjons")
        self:BuildContents(self.page == "moveContents")
    elseif HasContentModel() and self.page == "content" then
        self.headerData.titleText = ContentName(self.contentId); self:BuildContent()
    elseif HasContentModel() and self.page == "contentPage" then
        self.headerData.titleText = PageName(self.pageId); self:BuildContentPage()
    elseif HasContentModel() and self.page == "raidRoutes" then
        self.headerData.titleText = "Choisir le parcours"; self:BuildRaidRoutes()
    elseif HasContentModel() and self.page == "raidProgress" then
        self.headerData.titleText = "Tentative en cours"; self:BuildRaidProgress()
    elseif HasContentModel() and self.page == "raidAdvanced" then
        self.headerData.titleText = "Options avancées"; self:BuildRaidAdvanced()
    elseif HasContentModel() and self.page == "raidAddKind" then
        self.headerData.titleText = "Ajouter un emplacement"; self:BuildRaidAddKind()
    elseif HasContentModel() and self.page == "generalPage" then
        self.headerData.titleText = PageName(self.pageId); self:BuildFreeSetups()
    elseif HasContentModel() and self.page == "contentSlot" then
        self.headerData.titleText = self.slotName or "Emplacement"; self:BuildContentSlot()
    elseif HasContentModel() and self.page == "chooseContentProfile" then
        self.headerData.titleText = "Choisir un setup"; self:BuildChooseContentProfile()
    elseif HasContentModel() and self.page == "contentPoints" then
        self.headerData.titleText = "Points de préparation"; self:BuildContentPoints()
    elseif HasContentModel() and self.page == "aliasBosses" then
        self.headerData.titleText = "Choisir le boss observé"; self:BuildAliasBosses()
    elseif HasContentModel() and self.page == "aliasMembers" then
        self.headerData.titleText = "Choisir le membre"; self:BuildAliasMembers()
    elseif HasContentModel() and self.page == "encounterAliases" then
        self.headerData.titleText = "Noms reconnus"; self:BuildEncounterAliases()
    elseif HasContentModel() and self.page == "contentPageOptions" then
        self.headerData.titleText = PageName(self.pageId); self:BuildContentPageOptions()
    elseif HasContentModel() and (self.page == "pageFilter" or self.page == "contentDifficulty" or self.page == "createContentDifficulty" or self.page == "moveContentDifficulty") then
        self.headerData.titleText = self.page == "pageFilter" and "Filtrer les pages" or "Choisir la difficulté"
        self:BuildDifficulty(self.page == "pageFilter" and "filter" or (self.page == "contentDifficulty" and "override" or (self.page == "moveContentDifficulty" and "move" or "create")))
    elseif HasContentModel() and (self.page == "createContentRole" or self.page == "moveContentRole") then
        self.headerData.titleText = "Choisir le rôle"; self:BuildContentRole(self.page == "moveContentRole")
    elseif HasContentModel() and self.page == "moveContentCategories" then
        self.headerData.titleText = "Contenu de destination"; self:BuildMoveContentCategories()
    elseif HasContentModel() and self.page == "settings" then
        self.headerData.titleText = "Réglages"; self:BuildSettings()
    elseif self.page == "pages" or self.page == "movePage" then
        self.headerData.titleText = self.page == "pages" and "Mes pages" or "Déplacer le setup"
        self:BuildPages(self.page == "movePage" and self.profileId or nil)
    elseif self.page == "pageActions" then
        self.headerData.titleText = PageName(self.pageId)
        self:BuildPageActions()
    elseif self.page == "partial" then
        self.headerData.titleText = "Choisir les éléments"
        self:BuildPartial(self.profileId)
    elseif self.page == "points" then
        self.headerData.titleText = "Points de passage"
        self:BuildPoints(self.profileId)
    elseif self.page == "overview" then
        self.headerData.titleText = "Configuration actuelle"
        self:BuildOverview()
    elseif self.page == "gear" or self.page == "skills" or self.page == "champion" then
        local shownProfile = profile or self.preview
        self.headerData.titleText = (self.page == "gear" and "Équipement" or (self.page == "skills" and "Compétences" or "Étoiles Champion"))
        if shownProfile then
            if self.page == "gear" then self:BuildEquipment(shownProfile)
            elseif self.page == "skills" then self:BuildSkills(shownProfile)
            else self:BuildChampion(shownProfile) end
        else
            self:AddEntry("unavailable", "Configuration en attente", "Revenez à l'accueil puis rouvrez Configuration actuelle.", nil, true)
        end
    elseif self.page == "profile" then
        self.headerData.titleText = ProfileName(profile, self.profileId)
        self:BuildProfile(profile, self.profileId)
    elseif self.page == "setupRules" then
        self.headerData.titleText = "Automatique — " .. ProfileName(profile, self.profileId)
        self:BuildSetupRules(profile, self.profileId)
    elseif self.page == "bindBoss" or self.page == "bindTrash" then
        self.headerData.titleText = self.page == "bindTrash" and "Après une victoire" or "Choisir un boss"
        self:BuildBossChoices(profile, self.profileId)
    elseif self.page == "clearBoss" then
        self.headerData.titleText = "Associations de boss"
        self:BuildBossAssociations()
    elseif self.page == "automatic" then
        self.headerData.titleText = "Changements automatiques"
        self:BuildAutomatic()
    elseif self.page == "journal" then
        self.headerData.titleText = "Historique"
        self:BuildJournal()
    else
        self.page, self.profileId, self.expectedZoneId = "home", nil, nil
        self.headerData.titleText = "Setup Assist"
        self:BuildHome()
    end
    self.headerData.data1HeaderText = "Automatique"
    self.headerData.data1Text = AutomaticEnabled() and "Activé" or "Désactivé"
    self.headerData.data2HeaderText = PageName(self.pageId)
    local pageCount = 0
    for _, id in ipairs(Table(R.db.order)) do
        local saved = Profile(id)
        if saved and (saved.pageId or 1) == self.pageId then pageCount = pageCount + 1 end
    end
    if HasContentModel() and self.page == "contentPage" and HasRaidSteps(self.contentId, self.pageId) then
        self.headerData.data2Text = tostring(#RaidSteps(self.contentId, self.pageId)) .. " étapes"
    else self.headerData.data2Text = tostring(pageCount) .. " setups" end
    ZO_GamepadGenericHeader_Refresh(self.header, self.headerData)
    local content = { pageKey, tostring(R:GetZoneId()), tostring(self.expectedZoneId), tostring(AutomaticEnabled()), profile and ProfileName(profile, self.profileId) or "", tostring(self.aliasObservedName), tostring(self.aliasExpectedZoneId) }
    for _, data in ipairs(self.rows) do
        content[#content + 1] = tostring(data.key) .. "\n" .. data.text .. "\n" .. tostring(data.details)
            .. "\n" .. tostring(data:IsEnabled()) .. "\n" .. tostring(data.header)
    end
    local contentKey = table.concat(content, "\n")
    if self.lastContentKey == contentKey then
        self:RefreshKeybinds()
        self:UpdateTooltip(list:GetTargetData())
        self.dirty = false
        return
    end
    if self.lastBuiltPage then
        local selected = list:GetTargetData()
        self.selectionByPage[self.lastBuiltPage] = {
            key = selected and selected.key,
            index = list:GetTargetIndex() or list:GetSelectedIndex() or 1,
        }
    end
    list:Clear()
    for _, data in ipairs(self.rows) do
        if data.header then list:AddEntryWithHeader(TEMPLATE, data) else list:AddEntry(TEMPLATE, data) end
    end
    list:Commit()
    local selection = self.selectionByPage[pageKey] or {}
    local selectedIndex = selection.index or 1
    for index, data in ipairs(self.rows) do
        if data.key == selection.key then selectedIndex = index; break end
    end
    selectedIndex = math.max(1, math.min(selectedIndex, list:GetNumEntries()))
    list:SetSelectedIndexWithoutAnimation(selectedIndex, true)
    self.lastBuiltPage, self.lastContentKey = pageKey, contentKey
    self:RefreshKeybinds()
    self:UpdateTooltip(list:GetTargetData())
    self.dirty = false
end

function R:InitializeUI()
    if self.ui then return end
    InitializeDialogs()
    self.ui = Screen:New(RelaisGamepadControl)
    if ZO_MENU_ENTRIES then
        local exists = false
        for _, entry in ipairs(ZO_MENU_ENTRIES) do if entry.id == "Relais" then exists = true; break end end
        if not exists then
            local entry = ZO_GamepadEntryData:New("Setup Assist", ICON)
            entry.id, entry.data = "Relais", { name = "Setup Assist", scene = SCENE_NAME }
            entry:SetIconTintOnSelection(true)
            entry:SetIconDisabledTintOnSelection(true)
            entry:SetEnabled(true)
            table.insert(ZO_MENU_ENTRIES, entry)
        end
        if MAIN_MENU_GAMEPAD and MAIN_MENU_GAMEPAD:IsShowing() then MAIN_MENU_GAMEPAD:RefreshLists() end
    end
end

function R:RefreshUI()
    if self.ui then self.ui:Update() end
    if self:IsSavingSetup() then KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups() end
end

function R:IsSavingSetup()
    return self.ui ~= nil and self.ui.captureDialogOpen == true
end

function R:ShowUI()
    if not self.ui then return end
    self.ui.page, self.ui.profileId, self.ui.expectedZoneId = "home", nil, nil
    self.ui.raidLoadContext, self.ui.slotFeedback = nil, nil
    if HasContentModel() and type(self.IsAutomaticContentNavigationEnabled) == "function" and self:IsAutomaticContentNavigationEnabled() then
        local current = self:GetCurrentContent()
        if type(current) == "table" then
            local contentId = type(self.GetContentSetupId) == "function" and self:GetContentSetupId(current) or current.id
            self.ui.contentId, self.ui.slotKey, self.ui.pageFilter = contentId, nil, "any"
            self.ui.contentCategory = current.category == "trials" and "raids" or "dungeons"
            local pageId = self:GetActiveContentPage(contentId, self:GetContentDifficulty(contentId))
            self.ui.page = pageId and "contentPage" or "content"
            if pageId then self.ui.pageId = pageId end
        end
    end
    self.ui.dirty = true
    SCENE_MANAGER:Show(SCENE_NAME)
    self.ui:Update()
end
