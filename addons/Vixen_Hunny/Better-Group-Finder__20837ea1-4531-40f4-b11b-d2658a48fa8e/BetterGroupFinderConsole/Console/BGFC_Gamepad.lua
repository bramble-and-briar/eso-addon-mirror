-- BGFC_Gamepad.lua
-- Console / gamepad front end: a full-screen parametric list like the game's
-- own menus, with page history (B goes back), tooltips on the left, and
-- keybinds:  A = row action, X = row alternate, Y = page action, B = back.

local BGF = BetterGroupFinderConsole
local U = BGF.util
local A = BGF.Activities
local R = BGF.Roles
local Api = BGF.Api
local L = Api.Listing

local GP = {}
BGF.GP = GP

local SCENE_NAME = "BetterGroupFinderConsoleScene"
local TEMPLATE = "ZO_GamepadMenuEntryTemplate"
local HEADER_TEMPLATE = "ZO_GamepadMenuEntryHeaderTemplate"
local ACCENT = "4FC3F7"

local CP_PRESETS = { 160, 300, 500, 810, 1000, 1200, 1500, 1800, 2000, 2500, 3000 }

local function OnOff(b) return b and U.Colorize("7CFC00", "On") or U.Muted("Off") end

---------------------------------------------------------------------------
-- Text entry (virtual keyboard) dialog
---------------------------------------------------------------------------
local TEXT_DIALOG = "BGFC_TEXT_INPUT"
local TEXT_DIALOG_MULTI = "BGFC_TEXT_INPUT_MULTI"
local pending = nil

local function RegisterTextDialog(name, template)
    ZO_Dialogs_RegisterCustomDialog(name, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        blockDialogReleaseOnPress = true,
        setup = function(dialog) dialog:setupFunc() end,
        title = { text = "<<1>>" },
        mainText = { text = "<<1>>" },
        parametricList = {
            {
                template = template,
                templateData = {
                    textChangedCallback = function(control)
                        if pending then pending.text = control:GetText() end
                    end,
                    setup = function(control, data, selected, reselectingDuringRebuild)
                        control.highlight:SetHidden(not selected)
                        local edit = control.editBoxControl
                        edit.textChangedCallback = data.textChangedCallback
                        if pending then
                            edit:SetMaxInputChars(pending.maxChars or 200)
                            if pending.numeric and edit.SetTextType then
                                edit:SetTextType(TEXT_TYPE_NUMERIC_UNSIGNED_INT)
                            end
                            if not pending.filled then
                                pending.filled = true
                                edit:SetText(pending.text or "")
                            end
                        end
                    end,
                    callback = function(dialog)
                        local target = dialog.entryList:GetTargetControl()
                        if target and target.editBoxControl then target.editBoxControl:TakeFocus() end
                    end,
                },
            },
            {
                template = TEMPLATE,
                templateData = {
                    text = "Done",
                    setup = ZO_SharedGamepadEntry_OnSetup,
                    callback = function()
                        local p = pending
                        pending = nil
                        ZO_Dialogs_ReleaseDialogOnButtonPress(name)
                        if p and p.onDone then p.onDone(p.text or "") end
                    end,
                },
            },
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = function(dialog)
                    local data = dialog.entryList:GetTargetData()
                    if data and data.callback then data.callback(dialog) end
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = function()
                    pending = nil
                    ZO_Dialogs_ReleaseDialogOnButtonPress(name)
                end,
            },
        },
    })
end

-- opts = { title, hint, text, maxChars, numeric, multiline, onDone(text) }
function GP:PromptText(opts)
    pending = {
        text = opts.text or "",
        maxChars = opts.maxChars,
        numeric = opts.numeric,
        onDone = function(text)
            opts.onDone(text)
            self:Rebuild(true)
        end,
    }
    local name = opts.multiline and TEXT_DIALOG_MULTI or TEXT_DIALOG
    local ok, err = pcall(ZO_Dialogs_ShowGamepadDialog, name, {}, {
        titleParams = { opts.title or "Better Group Finder" },
        mainTextParams = { opts.hint or "" },
    })
    if not ok then
        pending = nil
        BGF:Print("Text entry is not available: " .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Screen class
---------------------------------------------------------------------------
local Screen = ZO_Gamepad_ParametricList_Screen and ZO_Gamepad_ParametricList_Screen:Subclass() or nil

if Screen then
    function Screen:Initialize(control, scene)
        self.headerData = { titleText = BGF.displayName }
        ZO_Gamepad_ParametricList_Screen.Initialize(self, control, false, true, scene)
    end

    function Screen:SetupList(list)
        list:AddDataTemplate(TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
        list:AddDataTemplateWithHeader(TEMPLATE, ZO_SharedGamepadEntry_OnSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, HEADER_TEMPLATE)
        list:SetOnSelectedDataChangedCallback(function(_, data) GP:OnSelectionChanged(data) end)
    end

    function Screen:PerformUpdate()
        self.dirty = false
        GP:Rebuild(true)
    end

    function Screen:InitializeKeybindStripDescriptors()
        self.keybindStripDescriptor = {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            {
                name = function() local r = GP:SelectedRow() return r and r.actionText or GetString(SI_GAMEPAD_SELECT_OPTION) end,
                keybind = "UI_SHORTCUT_PRIMARY",
                visible = function() local r = GP:SelectedRow() return r ~= nil and r.action ~= nil end,
                enabled = function() local r = GP:SelectedRow() return r ~= nil and r.enabled ~= false end,
                callback = function() GP:RunRow("action") end,
            },
            {
                name = function() local r = GP:SelectedRow() return r and r.altText or "" end,
                keybind = "UI_SHORTCUT_SECONDARY",
                visible = function() local r = GP:SelectedRow() return r ~= nil and r.alt ~= nil end,
                callback = function() GP:RunRow("alt") end,
            },
            {
                name = function() local p = GP.pageInfo return p and p.tertiary and p.tertiary.text or "" end,
                keybind = "UI_SHORTCUT_TERTIARY",
                visible = function() local p = GP.pageInfo return p ~= nil and p.tertiary ~= nil end,
                callback = function()
                    local p = GP.pageInfo
                    if p and p.tertiary then p.tertiary.fn() GP:Rebuild(true) end
                end,
            },
            {
                name = "Main Menu",
                keybind = "UI_SHORTCUT_RIGHT_STICK",
                visible = function() return GP.page ~= "main" end,
                callback = function() GP:GoMain() end,
            },
        }
        ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, function() GP:Back() end)
    end

    function Screen:OnHide()
        if ZO_Gamepad_ParametricList_Screen.OnHide then ZO_Gamepad_ParametricList_Screen.OnHide(self) end
        if GAMEPAD_TOOLTIPS then pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP) end
    end
end

---------------------------------------------------------------------------
-- Creation, navigation
---------------------------------------------------------------------------
GP.page = "main"
GP.args = nil
GP.stack = {}

function GP:Create()
    if self.screen or not Screen then return self.screen end
    local ok, err = pcall(function()
        local control = WINDOW_MANAGER:CreateControlFromVirtual("BetterGroupFinderConsoleTopLevel", GuiRoot, "BetterGroupFinderConsoleTopLevelTemplate")
        local fragment = ZO_FadeSceneFragment:New(control)
        local scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
        scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD_OPTIONS)
        scene:AddFragment(FRAME_EMOTE_FRAGMENT_SYSTEM)
        scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
        scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
        scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
        scene:AddFragment(fragment)
        scene:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                Api:SetExpectingUpdates(true)
            elseif newState == SCENE_HIDDEN then
                Api:SetExpectingUpdates(false)
            end
        end)
        self.scene = scene
        self.screen = Screen:New(control, scene)
    end)
    if not ok then
        BGF:Print("Could not create the gamepad screen: " .. tostring(err))
        self.screen, self.scene = nil, nil
    end
    return self.screen
end

function GP:IsShowing()
    return self.scene ~= nil and SCENE_MANAGER:IsShowing(SCENE_NAME)
end

function GP:Show(page, args)
    if not self:Create() then return end
    self.stack = {}
    self.page = page or "main"
    self.args = args
    if self.page == "results" and not self.searchedOnce then
        self.searchedOnce = true
        Api:StartSearch(BGF.sv.lastCategory)
    end
    if self:IsShowing() then
        self:Rebuild(false)
    else
        SCENE_MANAGER:Push(SCENE_NAME)
    end
end

function GP:Close()
    if self:IsShowing() then SCENE_MANAGER:HideCurrentScene() end
end

function GP:Toggle(page)
    if self:IsShowing() then self:Close() else self:Show(page) end
end

function GP:Open(page, args)
    local list = self.screen and self.screen:GetMainList()
    self.stack[#self.stack + 1] = { page = self.page, args = self.args, index = list and list:GetSelectedIndex() }
    self.page = page
    self.args = args
    self:Rebuild(false)
end

function GP:Back()
    local prev = table.remove(self.stack)
    if not prev then
        self:Close()
        return
    end
    self.page = prev.page
    self.args = prev.args
    self:Rebuild(false, prev.index)
end

function GP:GoMain()
    self.stack = {}
    self.page = "main"
    self.args = nil
    self:Rebuild(false)
end

function GP:SelectedRow()
    local list = self.screen and self.screen:GetMainList()
    local data = list and list:GetTargetData()
    return data and data.bgfRow or nil
end

function GP:RunRow(which)
    local row = self:SelectedRow()
    if not row or not row[which] or (which == "action" and row.enabled == false) then return end
    local before = self.rebuildCount
    local ok, err = pcall(row[which])
    if not ok then BGF:Print(tostring(err)) end
    if self:IsShowing() and self.rebuildCount == before then
        self:Rebuild(true)
    end
end

function GP:OnSelectionChanged(data)
    local row = data and data.bgfRow
    if GAMEPAD_TOOLTIPS then
        if row and row.tip then
            local title, body = row.tip[1] or "", row.tip[2] or ""
            local ok = pcall(GAMEPAD_TOOLTIPS.LayoutTitleAndDescriptionTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, title, body)
            if not ok then pcall(GAMEPAD_TOOLTIPS.LayoutSettingTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP, title .. "\n\n" .. body, "") end
        else
            pcall(GAMEPAD_TOOLTIPS.ClearTooltip, GAMEPAD_TOOLTIPS, GAMEPAD_LEFT_TOOLTIP)
        end
    end
    if self.screen and self.screen.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.screen.keybindStripDescriptor)
    end
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
-- A page builder returns { title, rows = {...}, tertiary = { text, fn } }.
-- Row: { text, header, icon, tip = { title, body }, action, actionText,
--        alt, altText, enabled }
GP.pages = {}

function GP:Rebuild(keepSelection, forceIndex)
    local screen = self.screen
    if not screen or not self:IsShowing() then return end
    local list = screen:GetMainList()
    local oldIndex = keepSelection and list:GetSelectedIndex() or nil
    self.rebuildCount = (self.rebuildCount or 0) + 1

    local builder = self.pages[self.page] or self.pages.main
    local ok, info = pcall(builder, self, self.args)
    if not ok then
        BGF:Print("Page error: " .. tostring(info))
        info = { title = "Error", rows = { { text = "Something went wrong. Press B to go back.", tip = { "Error", tostring(info) } } } }
    end
    self.pageInfo = info

    list:Clear()
    for _, row in ipairs(info.rows or {}) do
        local data = ZO_GamepadEntryData:New(row.text or "", row.icon)
        if row.icon and data.SetIconTintOnSelection then data:SetIconTintOnSelection(true) end
        data.bgfRow = row
        if data.SetEnabled then data:SetEnabled(row.enabled ~= false) end
        if row.header then
            data:SetHeader(row.header)
            list:AddEntryWithHeader(TEMPLATE, data)
        else
            list:AddEntry(TEMPLATE, data)
        end
    end
    list:Commit()

    local target = forceIndex or oldIndex
    if target and target > 0 and list:GetNumItems() > 0 then
        list:SetSelectedIndexWithoutAnimation(math.min(target, list:GetNumItems()), true, false)
    end

    ZO_ClearTable(screen.headerData)
    screen.headerData.titleText = info.title or BGF.displayName
    local role = BGF:GetPlayerRole()
    screen.headerData.data1HeaderText = "Role"
    screen.headerData.data1Text = R:Info(role).name
    screen.headerData.data2HeaderText = "CP"
    screen.headerData.data2Text = tostring(BGF:GetPlayerCP())
    if Api:HasListing() then
        screen.headerData.data3HeaderText = "Applicants"
        screen.headerData.data3Text = tostring(#Api:GetApplicants())
    end
    if screen.header then ZO_GamepadGenericHeader_RefreshData(screen.header, screen.headerData) end

    self:OnSelectionChanged(list:GetTargetData())
end

---------------------------------------------------------------------------
-- Shared text builders
---------------------------------------------------------------------------
local function ResultDetail(r)
    local lines = {}
    local function Add(t) lines[#lines + 1] = t end
    Add("Leader: " .. r.leader)
    Add("Activity: " .. r.activityLabel)
    if r.activity then
        Add(string.format("%s - %s", r.activity.abbr or "", r.activity.source or ""))
        if r.activity.summary then Add(r.activity.summary) end
    end
    if r.playstyle then Add("Playstyle: " .. Api:PlaystyleName(r.playstyle)) end
    Add("")
    Add(string.format("Roles %d / %d", r.filled, r.numRoles))
    for _, role in ipairs(R.ALL) do
        local desired = r.desired[role] or 0
        if desired > 0 then
            Add(string.format("  %s %s  %d / %d", R:Icon(role, 24), R:Info(role).name, r.attained[role] or 0, desired))
        end
    end
    Add("")
    local req = {}
    if r.requiresCP and r.cp > 0 then req[#req + 1] = "CP " .. r.cp .. "+" .. (r.meetsCP and "" or " (you don't meet this)") end
    if r.voip then req[#req + 1] = "Voice chat" end
    if r.inviteCode then req[#req + 1] = "Invite code" end
    if r.autoAccept then req[#req + 1] = "Auto-accept" end
    if #req > 0 then Add("Requirements: " .. table.concat(req, ", ")) end
    if r.warning and r.warning ~= "" then Add(r.warning) end
    if r.description ~= "" then
        Add("")
        Add(r.description)
    end
    return table.concat(lines, "\n")
end

local function CycleIndex(list, isMatch, delta)
    if #list == 0 then return nil end
    local idx = 1
    for i, item in ipairs(list) do
        if isMatch(item) then idx = i break end
    end
    idx = idx + delta
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    return list[idx]
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local P = GP.pages

function P.main(self)
    local rows = {}
    local cat = A:CategoryByValue(BGF.sv.lastCategory)
    rows[#rows + 1] = { header = "Find a Group", text = "Browse Groups",
        tip = { "Browse Groups", "Pick a category and see every listed group, with open roles, requirements and descriptions." },
        action = function() self:Open("categories") end }
    rows[#rows + 1] = { text = "Quick Search: " .. (cat and cat.name or "Dungeons"),
        tip = { "Quick Search", "Search the last category you browsed using your saved filters." },
        action = function() Api:StartSearch(BGF.sv.lastCategory) self:Open("results") end }

    local editing = Api:IsEditing()
    rows[#rows + 1] = { header = "Your Group", text = editing and "Edit Listing" or "Create Listing",
        tip = { "Create Listing", "Choose what you're doing; roles, title and description are generated for you and can be tweaked." },
        action = function() self:EnsureDraft() self:Open("create") end }
    local apps = #Api:GetApplicants()
    rows[#rows + 1] = { text = string.format("My Listing & Applicants%s", apps > 0 and string.format(" (%d)", apps) or ""),
        tip = { "My Listing", Api:HasListing() and "See your listing and accept or decline applicants." or "You have no listing yet." },
        action = function() self:Open("mine") end }
    if Api:HasApplied() then
        local a = Api:GetAppliedListing()
        rows[#rows + 1] = { text = "Cancel Application: " .. (a and a.title or ""),
            tip = { "Your Application", a and string.format("%s\n%s\n\n%s", a.title, a.leader, a.description) or "" },
            action = function() Api:Rescind() end, actionText = "Cancel Application" }
    end

    local role = BGF:GetPlayerRole()
    rows[#rows + 1] = { header = "You", text = string.format("%s %s  -  CP %d", R:Icon(role, 28), R:Info(role).name, BGF:GetPlayerCP()),
        tip = { "Your role", "Groups are matched against your selected role. Change it in the Activity Finder before applying." } }
    rows[#rows + 1] = { header = "Settings", text = "Settings",
        tip = { "Settings", "Defaults for browsing and filters, automatic roles (trial tanks / healers), title and description options, live listing updates and notifications." },
        actionText = "Open", action = function() self:Open("settings") end }
    return { title = BGF.displayName, rows = rows }
end

function P.categories(self)
    local rows = {}
    for i, cat in ipairs(A:GetCategories()) do
        rows[#rows + 1] = {
            header = i == 1 and "Choose a Category" or nil,
            text = cat.name, icon = cat.icon,
            tip = { cat.name, cat.blurb },
            actionText = "Search",
            action = function()
                Api:StartSearch(cat.value)
                self:Open("results")
            end,
        }
    end
    return { title = "Browse Groups", rows = rows }
end

function P.results(self)
    local rows = {}
    local cat = A:CategoryByValue(BGF.sv.lastCategory)
    local text = U.Trim(BGF.sv.searchText)
    rows[#rows + 1] = { header = "Search", text = "Search: " .. (text ~= "" and text or U.Muted("anything")),
        tip = { "Search", "Matches title, activity, leader, playstyle and description. Separate words must all match." },
        actionText = "Edit", action = function()
            self:PromptText({ title = "Search Groups", hint = "Words to look for", text = BGF.sv.searchText, maxChars = 60,
                onDone = function(t) BGF.sv.searchText = t end })
        end,
        altText = "Clear", alt = text ~= "" and function() BGF.sv.searchText = "" end or nil }

    local active = {}
    if BGF.sv.filterNeedsMyRole then active[#active + 1] = "my role" end
    if BGF.sv.filterMeetsCP then active[#active + 1] = "my CP" end
    if BGF.sv.filterHideFull then active[#active + 1] = "not full" end
    if BGF.sv.filterAutoAcceptOnly then active[#active + 1] = "auto-accept" end
    if BGF.sv.filterNoInviteCode then active[#active + 1] = "no code" end
    rows[#rows + 1] = { text = string.format("Filters & Sort  %s", U.Muted(#active > 0 and table.concat(active, ", ") or "none")),
        tip = { "Filters & Sort", "Sort: " .. BGF.SORT_MODES[BGF.sv.sortMode or 1].name },
        action = function() self:Open("filters") end }
    rows[#rows + 1] = { text = "Category: " .. (cat and cat.name or "?"), tip = { "Category", "Change the category to search." },
        action = function() self:Open("categories") end, actionText = "Change" }

    local list = Api:FilterResults()
    local state = Api:SearchStateText()
    local header = string.format("Groups (%d of %d)", #list, #Api.results)
    if state ~= "" then
        rows[#rows + 1] = { header = header, text = U.Muted(state) }
        header = nil
    elseif #list == 0 then
        rows[#rows + 1] = { header = header, text = U.Muted(#Api.results > 0 and "No groups match your filters" or "No groups listed right now"),
            tip = { "Nothing here", "Try other filters, refresh, or create your own listing from the main menu." },
            action = function() self:EnsureDraft() self:Open("create") end, actionText = "Create Listing" }
        header = nil
    end
    for _, r in ipairs(list) do
        local prefix = r.isFull and U.Muted("[Full]") or R:OpenIcons(r.open, 26, 6)
        local label = string.format("%s  %s  %s", prefix, r.title, U.Muted(string.format("%d/%d", r.filled, r.numRoles)))
        if r.isActiveApplication then label = U.Colorize("FFD700", "[Applied] ") .. label end
        rows[#rows + 1] = {
            header = header, text = label,
            tip = { r.title, ResultDetail(r) },
            enabled = true,
            actionText = "Details", action = function() self:Open("listing", { result = r }) end,
            altText = r.autoAccept and "Join" or "Apply",
            alt = (r.canJoin and not r.isFull and not r.isActiveApplication) and function() self:ApplyTo(r) end or nil,
        }
        header = nil
    end
    return { title = cat and cat.name or "Groups", rows = rows,
        tertiary = { text = "Refresh", fn = function() Api:StartSearch(BGF.sv.lastCategory) end } }
end

function P.filters(self)
    local rows = {}
    local defs = {
        { "filterNeedsMyRole", "Needs my role", "Only groups with an open slot for your role (or an Any slot)." },
        { "filterMeetsCP", "I meet the CP requirement", "Hide groups whose CP requirement is above yours." },
        { "filterHideFull", "Hide full groups", "Hide groups with no open slots." },
        { "filterAutoAcceptOnly", "Auto-accept only", "Only groups you join instantly." },
        { "filterNoInviteCode", "Hide invite-code groups", "Hide groups that need an invite code." },
    }
    for i, d in ipairs(defs) do
        rows[#rows + 1] = { header = i == 1 and "Filters" or nil, text = d[2] .. ":  " .. OnOff(BGF.sv[d[1]]), tip = { d[2], d[3] },
            actionText = "Toggle", action = function() BGF.sv[d[1]] = not BGF.sv[d[1]] end }
    end
    local n = #BGF.SORT_MODES
    rows[#rows + 1] = { header = "Sort", text = "Sort by: " .. BGF.SORT_MODES[BGF.sv.sortMode or 1].name,
        tip = { "Sort", "Best match puts groups that need your role, accept your CP and are nearly full first." },
        actionText = "Next", action = function() BGF.sv.sortMode = ((BGF.sv.sortMode or 1) % n) + 1 end,
        altText = "Previous", alt = function() BGF.sv.sortMode = (((BGF.sv.sortMode or 1) - 2) % n) + 1 end }
    return { title = "Filters & Sort", rows = rows }
end

function GP:ApplyTo(r, message)
    if Api:HasListing() then
        BGF:Alert("Remove your own listing before applying to another group.", true)
        return
    end
    if r.inviteCode then
        self:PromptText({ title = "Invite Code", hint = "This group needs an invite code.", numeric = true, maxChars = 8,
            onDone = function(code) Api:Apply(r, message or BGF.sv.applyMessage, code) end })
        return
    end
    Api:Apply(r, message or BGF.sv.applyMessage)
end

function P.listing(self, args)
    local r = args and args.result
    if not r then return { title = "Group", rows = { { text = "Group no longer listed." } } } end
    -- Refresh from the latest results if possible.
    for _, fresh in ipairs(Api.results) do
        if fresh.listingIndex == r.listingIndex and fresh.title == r.title then r = fresh args.result = fresh break end
    end

    local rows = {}
    local detail = ResultDetail(r)
    rows[#rows + 1] = { header = "Group", text = r.title, tip = { r.title, detail } }
    rows[#rows + 1] = { text = "Leader: " .. r.leader, tip = { "Leader", r.leader .. (r.leaderCharacter ~= "" and ("\n" .. ZO_FormatUserFacingCharacterName(r.leaderCharacter)) or "") } }
    rows[#rows + 1] = { text = "Activity: " .. r.activityLabel,
        tip = { r.activityLabel, r.activity and string.format("%s\n%s\n\n%s", r.activity.abbr or "", r.activity.source or "", r.activity.summary or "") or "" } }
    local roleLines = {}
    for _, role in ipairs(R.ALL) do
        if (r.desired[role] or 0) > 0 then
            roleLines[#roleLines + 1] = string.format("%s %s  %d / %d", R:Icon(role, 24), R:Info(role).name, r.attained[role] or 0, r.desired[role])
        end
    end
    rows[#rows + 1] = { text = string.format("Roles: %d / %d   %s", r.filled, r.numRoles, r.isFull and U.Muted("Full") or ("Open: " .. R:OpenIcons(r.open, 26, 8))),
        tip = { "Roles", table.concat(roleLines, "\n") } }
    if r.requiresCP and r.cp > 0 then
        rows[#rows + 1] = { text = string.format("Champion Points: %d+  %s", r.cp, r.meetsCP and U.Colorize("7CFC00", "(OK)") or U.Colorize("FF6666", "(too low)")) }
    end
    if r.description ~= "" then
        rows[#rows + 1] = { text = "Description", tip = { "Description", r.description } }
    end

    local canApply = r.canJoin and not r.isFull and not r.isActiveApplication
    local verb = r.autoAccept and "Join" or "Apply"
    rows[#rows + 1] = { header = "Actions", text = verb .. (BGF.sv.applyMessage ~= "" and "  " .. U.Muted("(with saved message)") or ""),
        enabled = canApply, tip = { verb, r.warning or (canApply and "Send your application to the leader." or "You can't apply to this group.") },
        actionText = verb, action = function() self:ApplyTo(r) end }
    rows[#rows + 1] = { text = verb .. " with a message", enabled = canApply,
        tip = { "Message", "Write a short note to the leader (role, build, experience)." },
        action = function()
            self:PromptText({ title = "Message to Leader", hint = "Optional note sent with your application", text = BGF.sv.applyMessage, maxChars = 200,
                onDone = function(t) BGF.sv.applyMessage = t self:ApplyTo(r, t) end })
        end }
    if Api:HasApplied() then
        rows[#rows + 1] = { text = "Cancel My Application", action = function() Api:Rescind() end }
    end
    return { title = "Group Details", rows = rows }
end

---------------------------------------------------------------------------
-- Create / edit
---------------------------------------------------------------------------
function GP:EnsureDraft()
    if Api:IsEditing() or self.draftInitialized then return end
    self.draftInitialized = true
    if U.Trim(L:GetTitle()) == "" then
        L:ApplyIntent(A:GetIntent(BGF.sv.lastIntent))
    end
end

local function AfterManualRoles()
    BGF.sv.autoRoles = false
    local intent = A:GetIntent(BGF.sv.lastIntent)
    if BGF.sv.autoTitle then L:AutoTitle(intent) end
    if BGF.sv.autoDescription then L:AutoDescription(intent) end
end

function P.create(self)
    local rows = {}
    local editing = Api:IsEditing()
    local intent = A:GetIntent(BGF.sv.lastIntent)
    local lockTip = editing and "\n\nCan't be changed while your listing is up." or ""

    rows[#rows + 1] = { header = "What are you doing?", text = intent.name,
        tip = { intent.name, intent.details .. (intent.cp > 0 and ("\n\nSuggested CP: " .. intent.cp .. "+") or "") },
        actionText = "Change", action = function() self:Open("intents") end }

    -- Activity
    local cat = A:CategoryByValue(L:GetCategory())
    rows[#rows + 1] = { header = "Activity", text = "Category: " .. (cat and cat.name or "?"), enabled = not editing,
        tip = { "Category", (cat and cat.blurb or "") .. lockTip }, actionText = "Change", action = function() self:Open("pick_category") end }

    local prim = L:GetPrimaryOptions()
    if #prim > 0 then
        local current = L:GetPrimary()
        local function Step(delta)
            local nextOpt = CycleIndex(prim, function(o) return o.isSet end, delta)
            if nextOpt then L:SetPrimary(nextOpt.index) L:RefreshAuto() end
        end
        rows[#rows + 1] = { text = "Type: " .. (current and current.name or "Choose"), enabled = not editing,
            tip = { "Difficulty / Type", "Normal or Veteran for dungeons, trials and arenas; the activity type for other categories." .. lockTip },
            actionText = "Next", action = function() Step(1) end, altText = "Previous", alt = not editing and function() Step(-1) end or nil }
    end

    local sec = L:GetSecondaryOptions()
    if #sec > 0 then
        local activity, name = L:GetActivity()
        local label = name or "Choose"
        if activity and activity.abbr then label = string.format("%s (%s)", label, activity.abbr) end
        local tip = activity and string.format("%s\n%s\n\n%s%s", activity.abbr or "", activity.source or "", activity.summary or "",
            activity.hm and "\n\nHard Mode available." or "") or "Pick the specific activity."
        rows[#rows + 1] = { text = "Activity: " .. label, enabled = not editing, tip = { name or "Activity", tip .. lockTip },
            actionText = "Choose", action = function() self:Open("pick_secondary") end }
    end

    local sizes = L:GetSizes()
    if #sizes > 0 then
        local current = L:GetSize()
        local function Step(delta)
            local nextSize = CycleIndex(sizes, function(s) return s.value == current end, delta)
            if nextSize then L:SetSize(nextSize.value) L:RefreshAuto() end
        end
        rows[#rows + 1] = { text = "Group size: " .. Api:SizeName(current), enabled = not editing,
            tip = { "Group size", "Total players including you." .. lockTip },
            actionText = "Next", action = function() Step(1) end, altText = "Previous", alt = not editing and function() Step(-1) end or nil }
    end

    local styles = Api:GetPlaystyles()
    if #styles > 0 then
        local current = L:GetPlaystyle()
        local function Step(delta)
            local s = CycleIndex(styles, function(x) return x.value == current end, delta)
            if s then L:SetPlaystyle(s.value) end
        end
        rows[#rows + 1] = { text = "Playstyle: " .. Api:PlaystyleName(current), tip = { "Playstyle", "How you want to play. Picked automatically from what you're doing." },
            actionText = "Next", action = function() Step(1) end, altText = "Previous", alt = function() Step(-1) end }
    end

    -- Roles
    local desired, attained = L:GetRoles()
    local numRoles = L:GetNumRoles()
    local open = R:Open(desired, attained)
    rows[#rows + 1] = { header = "Roles", text = "Automatic roles: " .. OnOff(BGF.sv.autoRoles),
        tip = { "Automatic roles", "Work out tanks, healers and DPS from the activity, group size and who is already in your group." },
        actionText = "Toggle", action = function()
            BGF.sv.autoRoles = not BGF.sv.autoRoles
            if BGF.sv.autoRoles then L:RefreshAuto() end
        end,
        altText = "Regenerate", alt = function() L:AutoRoles(intent) L:RefreshAuto(intent) end }
    for _, role in ipairs(R.ORDER) do
        local inGroup = attained[role] or 0
        rows[#rows + 1] = {
            text = string.format("%s %s: %d%s", R:Icon(role, 28), R:Info(role).plural, desired[role] or 0, inGroup > 0 and U.Muted(string.format("  (%d in group)", inGroup)) or ""),
            tip = { R:Info(role).plural, "A adds one, X removes one. Slots not given to a role are open to any role." },
            actionText = "Add", action = function() if L:AdjustRole(role, 1) then AfterManualRoles() end end,
            altText = "Remove", alt = function() if L:AdjustRole(role, -1) then AfterManualRoles() end end,
        }
    end
    rows[#rows + 1] = { text = string.format("Still needed: %s", R:Long(open)),
        tip = { "Composition", string.format("Size %d\n%s\nAny role: %d", numRoles, R:Compact(desired, true), desired[R.ANY] or 0) } }

    -- Text
    local title = L:GetTitle()
    rows[#rows + 1] = { header = "Title & Description", text = "Title: " .. (title ~= "" and title or U.Muted("none")),
        tip = { "Title", (BGF.sv.autoTitle and "Auto: kept in sync with the activity and open roles.\n\n" or "") .. title },
        actionText = "Edit", action = function()
            self:PromptText({ title = "Listing Title", hint = "Short and clear, e.g. vSS HM LF 1H 2D", text = title,
                maxChars = GROUP_FINDER_GROUP_LISTING_TITLE_MAX_LENGTH or 40,
                onDone = function(t) L:SetTitle(t) BGF.sv.autoTitle = false end })
        end,
        altText = BGF.sv.autoTitle and "Auto: On" or "Auto: Off", alt = function()
            BGF.sv.autoTitle = not BGF.sv.autoTitle
            if BGF.sv.autoTitle then L:AutoTitle(intent) end
        end }
    local desc = L:GetDescription()
    rows[#rows + 1] = { text = "Description" .. (BGF.sv.autoDescription and U.Muted("  (auto)") or ""),
        tip = { "Description", desc ~= "" and desc or "No description." },
        actionText = "Edit", action = function()
            self:PromptText({ title = "Description", hint = "What you're doing, what you need, requirements", text = desc, multiline = true,
                maxChars = GROUP_FINDER_GROUP_LISTING_DESCRIPTION_MAX_LENGTH or 300,
                onDone = function(t) L:SetDescription(t) BGF.sv.autoDescription = false end })
        end,
        altText = BGF.sv.autoDescription and "Auto: On" or "Auto: Off", alt = function()
            BGF.sv.autoDescription = not BGF.sv.autoDescription
            if BGF.sv.autoDescription then L:AutoDescription(intent) end
        end }
    local notes = BGF.sv.extraNotes or ""
    rows[#rows + 1] = { text = "Extra notes: " .. (notes ~= "" and notes or U.Muted("none")),
        tip = { "Extra notes", "Added to the end of the automatic description: sets you want, parse, discord, etc." },
        actionText = "Edit", action = function()
            self:PromptText({ title = "Extra Notes", hint = "Added to the auto description", text = notes, maxChars = 150,
                onDone = function(t) BGF.sv.extraNotes = t if BGF.sv.autoDescription then L:AutoDescription(intent) end end })
        end }

    -- Requirements
    local reqCP, cp = L:GetRequiresCP(), L:GetCP()
    rows[#rows + 1] = { header = "Requirements", text = "Minimum CP: " .. (reqCP and U.Colorize("FFFFFF", tostring(cp)) or U.Muted("Off")),
        tip = { "Minimum CP", "A toggles the requirement, X steps through common values (160, 810, 1200...)." },
        actionText = "Toggle", action = function()
            L:SetRequiresCP(not reqCP)
            if not reqCP and cp <= 0 then L:SetCP(160) end
            L:RefreshAuto()
        end,
        altText = "Change", alt = reqCP and function()
            local nextCP = CP_PRESETS[1]
            for _, v in ipairs(CP_PRESETS) do if v > cp then nextCP = v break end end
            L:SetCP(nextCP)
            L:RefreshAuto()
        end or nil }
    rows[#rows + 1] = { text = "Voice chat required: " .. OnOff(L:GetVOIP()), actionText = "Toggle",
        action = function() L:SetVOIP(not L:GetVOIP()) L:RefreshAuto() end }
    rows[#rows + 1] = { text = "Auto-accept applicants: " .. OnOff(L:GetAutoAccept()), actionText = "Toggle",
        tip = { "Auto-accept", "Players who fit join instantly without you approving them." },
        action = function() L:SetAutoAccept(not L:GetAutoAccept()) end }
    rows[#rows + 1] = { text = "Enforce roles: " .. OnOff(L:GetEnforceRoles()), actionText = "Toggle",
        tip = { "Enforce roles", "Only accept applicants whose role matches an open slot." },
        action = function() L:SetEnforceRoles(not L:GetEnforceRoles()) end }
    local needCode = L:GetRequiresInviteCode()
    local code = L:GetInviteCode()
    rows[#rows + 1] = { text = "Invite code: " .. (needCode and U.Colorize("FFFFFF", (code and code > 0) and tostring(code) or "not set") or U.Muted("Off")),
        tip = { "Invite code", "Only players with the code can join. Good for guild or friends groups." },
        actionText = needCode and "Turn Off" or "Set Code", action = function()
            if needCode then
                L:SetRequiresInviteCode(false)
            else
                self:PromptText({ title = "Invite Code", hint = "Numbers only", numeric = true, maxChars = GROUP_FINDER_GROUP_LISTING_INVITE_CODE_MAX_LENGTH or 8,
                    onDone = function(t)
                        local n = tonumber(t) or 0
                        L:SetRequiresInviteCode(n > 0)
                        L:SetInviteCode(n)
                    end })
            end
        end }

    -- Post
    local problems = L:Validate()
    rows[#rows + 1] = { header = "Post", text = editing and "Update Listing" or "Post Listing", enabled = #problems == 0,
        tip = { editing and "Update Listing" or "Post Listing", #problems > 0 and table.concat(problems, "\n") or "Ready to go!" },
        action = function() L:Post() end }
    if Api:HasListing() then
        rows[#rows + 1] = { text = "Remove Listing", action = function() Api:RemoveListing() end }
    end
    return { title = editing and "Edit Listing" or "Create Listing", rows = rows,
        tertiary = { text = "Regenerate All", fn = function()
            L:AutoRoles(intent) L:AutoTitle(intent) L:AutoDescription(intent)
        end } }
end

function P.intents(self)
    local rows = {}
    local lastCat
    for _, intent in ipairs(A.INTENTS) do
        local cat = A:CategoryByKey(intent.category)
        local header
        if intent.category ~= lastCat then
            header = cat and cat.name or intent.category
            lastCat = intent.category
        end
        local selected = intent.id == BGF.sv.lastIntent
        local extra = {}
        if intent.difficulty then extra[#extra + 1] = "Difficulty: " .. intent.difficulty end
        if intent.cp > 0 then extra[#extra + 1] = "Suggested CP: " .. intent.cp .. "+" end
        rows[#rows + 1] = {
            header = header,
            text = (selected and U.Colorize(ACCENT, "> ") or "") .. intent.name,
            tip = { intent.name, intent.summary .. "\n\n" .. intent.details .. (#extra > 0 and ("\n\n" .. table.concat(extra, "\n")) or "") },
            actionText = "Choose", enabled = not (Api:IsEditing() and cat and cat.value ~= L:GetCategory()),
            action = function()
                L:ApplyIntent(intent)
                self:Back()
            end,
        }
    end
    return { title = "What are you doing?", rows = rows }
end

function P.pick_category(self)
    local rows = {}
    local current = L:GetCategory()
    for i, cat in ipairs(A:GetCategories()) do
        rows[#rows + 1] = { header = i == 1 and "Category" or nil, icon = cat.icon,
            text = (cat.value == current and U.Colorize(ACCENT, "> ") or "") .. cat.name, tip = { cat.name, cat.blurb },
            actionText = "Choose", action = function()
                L:SetCategory(cat.value)
                local intents = A:IntentsForCategory(cat.key)
                if intents[1] and A:GetIntent(BGF.sv.lastIntent).category ~= cat.key then
                    L:ApplyIntent(intents[1], true)
                else
                    L:RefreshAuto()
                end
                self:Back()
            end }
    end
    return { title = "Category", rows = rows }
end

function P.pick_secondary(self)
    local rows = {}
    for i, o in ipairs(L:GetSecondaryOptions()) do
        local info = A:Lookup(o.name)
        local label = info and info.abbr and string.format("%s  %s", o.name, U.Muted("(" .. info.abbr .. ")")) or o.name
        rows[#rows + 1] = {
            header = i == 1 and "Activity" or nil,
            text = (o.isSet and U.Colorize(ACCENT, "> ") or "") .. label,
            tip = { o.name, info and string.format("%s\n\n%s%s", info.source or "", info.summary or "", info.hm and "\n\nHard Mode available." or "") or "" },
            actionText = "Choose", action = function()
                L:SetSecondary(o.index)
                L:RefreshAuto()
                self:Back()
            end,
        }
    end
    if #rows == 0 then rows[1] = { text = U.Muted("No activities for this category.") } end
    return { title = "Choose Activity", rows = rows }
end

---------------------------------------------------------------------------
-- Settings: renders the shared LAM option list as gamepad rows
---------------------------------------------------------------------------
local function Resolve(v)
    if type(v) == "function" then
        local ok, r = pcall(v)
        return ok and r or nil
    end
    return v
end

local function DropdownLabel(o, value)
    for i, v in ipairs(o.choicesValues or o.choices or {}) do
        if v == value then return o.choices[i] end
    end
    return tostring(value or "")
end

local function DropdownStep(o, delta)
    local values = o.choicesValues or o.choices or {}
    if #values == 0 then return end
    local current, idx = o.getFunc(), 1
    for i, v in ipairs(values) do if v == current then idx = i break end end
    idx = ((idx - 1 + delta) % #values) + 1
    o.setFunc(values[idx])
end

local function SliderStep(o, delta)
    local step = o.step or 1
    local v = (tonumber(o.getFunc()) or o.min or 0) + delta * step
    if v > (o.max or v) then v = o.min or v elseif v < (o.min or v) then v = o.max or v end
    o.setFunc(v)
end

function P.settings(self)
    local rows = {}
    local pendingHeader = "General"
    local options = BGF.Settings and BGF.Settings:BuildOptions() or {}
    for _, o in ipairs(options) do
        local tip = { o.name or o.title or "", o.tooltip or "" }
        local enabled = not Resolve(o.disabled)
        local row
        if o.type == "header" then
            pendingHeader = o.name
        elseif o.type == "description" then
            row = { text = U.Muted(o.text or ""), tip = { o.title or "", o.text or "" } }
        elseif o.type == "checkbox" then
            row = { text = string.format("%s: %s", o.name, OnOff(o.getFunc())), tip = tip, enabled = enabled,
                actionText = "Toggle", action = function() o.setFunc(not o.getFunc()) end }
        elseif o.type == "slider" then
            row = { text = string.format("%s: %s", o.name, U.Colorize("FFFFFF", tostring(o.getFunc()))), tip = tip, enabled = enabled,
                actionText = "Increase", action = function() SliderStep(o, 1) end,
                altText = "Decrease", alt = function() SliderStep(o, -1) end }
        elseif o.type == "dropdown" then
            row = { text = string.format("%s: %s", o.name, U.Colorize("FFFFFF", DropdownLabel(o, o.getFunc()))), tip = tip, enabled = enabled,
                actionText = "Next", action = function() DropdownStep(o, 1) end,
                altText = "Previous", alt = function() DropdownStep(o, -1) end }
        elseif o.type == "editbox" then
            local value = tostring(o.getFunc() or "")
            local tipBody = tip[2]
            if value ~= "" then tipBody = tipBody .. "\n\n" .. value end
            row = { text = string.format("%s: %s", o.name, value ~= "" and value or U.Muted("none")), tip = { tip[1], tipBody },
                enabled = enabled, actionText = "Edit", action = function()
                    self:PromptText({ title = o.name, hint = o.tooltip, text = value, maxChars = o.maxChars or 200,
                        onDone = function(t) o.setFunc(t) end })
                end,
                altText = value ~= "" and "Clear" or nil, alt = value ~= "" and function() o.setFunc("") end or nil }
        elseif o.type == "button" and not o.opensUI and not o.isPCOnly then
            row = { text = o.name, tip = tip, enabled = enabled, actionText = "Select", action = function() o.func() end }
        end
        if row then
            row.header = pendingHeader
            pendingHeader = nil
            rows[#rows + 1] = row
        end
    end
    rows[#rows + 1] = { header = "Reset", text = "Reset all settings to defaults",
        tip = { "Reset", "Puts every Better Group Finder setting back to its default." },
        actionText = "Reset", action = function() if BGF.Settings then BGF.Settings:ResetToDefaults() end end }
    return { title = "Settings", rows = rows }
end

---------------------------------------------------------------------------
-- My listing / applicants
---------------------------------------------------------------------------
function P.mine(self)
    local rows = {}
    local s = Api:GetMyListingSummary()
    if s then
        rows[#rows + 1] = { header = "Your Listing", text = s.title, tip = { s.title, s.description } }
        rows[#rows + 1] = { text = "Activity: " .. (s.secondaryText ~= "" and s.secondaryText or s.primaryText) }
        local filled = 0
        for _, role in ipairs(R.ALL) do filled = filled + (s.attained[role] or 0) end
        rows[#rows + 1] = { text = string.format("Roles: %d / %d  -  needed: %s", filled, s.numRoles, R:Long(s.open)) }
        rows[#rows + 1] = { text = "Edit Listing", action = function() self:Open("create") end }
        rows[#rows + 1] = { text = "Remove Listing", action = function() Api:RemoveListing() end }
    else
        rows[#rows + 1] = { header = "Your Listing", text = "Create a Listing", tip = { "No listing", "Post a listing and players will apply to join you." },
            action = function() self:EnsureDraft() self:Open("create") end }
    end

    local apps = Api:GetApplicants()
    local header = string.format("Applicants (%d)", #apps)
    if #apps == 0 then
        rows[#rows + 1] = { header = header, text = U.Muted(s and "No applicants yet" or "Post a listing to receive applicants") }
    end
    for i, app in ipairs(apps) do
        local info = string.format("%s\n%s\n%s", ZO_FormatUserFacingCharacterName(app.characterName), app.className,
            app.cp > 0 and ("CP " .. app.cp) or ("Level " .. app.level))
        if app.timeLeft > 0 then info = info .. "\n" .. U.FormatSeconds(app.timeLeft) .. " left" end
        if app.note ~= "" then info = info .. "\n\n\"" .. app.note .. "\"" end
        rows[#rows + 1] = {
            header = i == 1 and header or nil,
            text = string.format("%s %s  %s", R:Icon(app.role, 28), app.displayName, U.Muted(app.cp > 0 and ("CP " .. app.cp) or ("Lv " .. app.level))),
            tip = { app.displayName, info },
            enabled = not app.pending,
            actionText = "Accept", action = function() Api:ResolveApplicant(app.characterId, true) end,
            altText = "Decline", alt = not app.pending and function() Api:ResolveApplicant(app.characterId, false) end or nil,
        }
    end

    if Api:HasApplied() then
        local a = Api:GetAppliedListing()
        rows[#rows + 1] = { header = "Your Application", text = a and a.title or "Applied",
            tip = { "Your application", a and string.format("%s\n%s", a.leader, a.description) or "" },
            actionText = "Cancel Application", action = function() Api:Rescind() end }
    end
    return { title = "My Group", rows = rows }
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
BGF:OnInitialize(function()
    pcall(RegisterTextDialog, TEXT_DIALOG, "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem")
    pcall(RegisterTextDialog, TEXT_DIALOG_MULTI, "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem_Multiline")

    local function Refresh()
        if GP:IsShowing() then GP:Rebuild(true) end
    end
    BGF:On("SearchUpdated", Refresh)
    BGF:On("ListingChanged", Refresh)
    BGF:On("ApplicantsChanged", Refresh)
    BGF:On("StatusChanged", Refresh)
    BGF:On("SettingsChanged", Refresh)
end)
