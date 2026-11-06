local this = InventoryCompanion

local rows = {}
local selectedReferences = {}
local selectionProfile
local scrollAfterMove
local context = "backpack"
local mode = "display"
local contextCombo
local copyContextCombo

local ROW_HEIGHT = 32

local function EscapeEsoMarkup(value)
    return value:gsub("|", "||")
end

local function Window(name)
    return GetControl(InventoryCompanion_AutoCategoryWindow, name)
end

local function IsActive()
    return this.AutoCategoryIntegration.IsEditorActive()
end

local function AssertCurrentView(contextAtRender, modeAtRender)
    assert(IsActive() and context == contextAtRender and mode == modeAtRender,
        "AutoCategory editor action targets a stale view")
end

local function ShowTooltip(control, text)
    InitializeTooltip(InformationTooltip, control, RIGHT, -4, 0)
    InformationTooltip:AddLine(text)
end

local function HideTooltip()
    ClearTooltip(InformationTooltip)
end

local function IsSelected(entry)
    return selectedReferences[entry.reference] == true
end

local function DescribeEntry(entry)
    if entry == nil then return "none" end
    return entry.reference .. " (" .. entry.kind .. ", order " .. tostring(entry.index) .. "/"
        .. tostring(entry.orderCount) .. ", participating " .. tostring(entry.participating) .. ")"
end

local function EditorSnapshot(entry)
    return function()
        local snapshot = this.AutoCategoryIntegration.TimingSnapshot()
        local selected = {}
        for reference in pairs(selectedReferences) do selected[#selected + 1] = reference end
        table.sort(selected)
        local visible = {}
        for _, row in ipairs(rows) do
            if not row:IsHidden() then
                visible[#visible + 1] = (IsSelected(row.autoCategoryEntry) and "*" or "") .. row.autoCategoryEntry.reference
            end
        end
        snapshot.context = context
        snapshot.mode = mode
        snapshot.row = DescribeEntry(entry)
        snapshot.selected = selected
        snapshot.createdRows = #rows
        snapshot.visibleRows = visible
        return snapshot
    end
end

-- Every editor click/change goes through Timed so slow actions report the list state they started from.
local function Timed(operation, entry, action, ...)
    return this.AutoCategoryIntegration.TimeAction("editor", operation, EditorSnapshot(entry), action, ...)
end

local function Phase(name, operation, ...)
    return this.AutoCategoryIntegration.TimePhase(name, operation, ...)
end

local function ConfigureCombo(containerName, selected, select)
    local bar = containerName == "ContextMode" and "TopActionBar" or "OptionsBar"
    local combo = ZO_ComboBox_ObjectFromContainer(GetControl(Window(bar), containerName))
    assert(combo, "AutoCategory editor is missing its " .. containerName .. " selector")
    combo:SetSortsItems(false)
    combo:ClearItems()
    for _, entryContext in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        local entry = combo:CreateItemEntry(entryContext.title,
            function(_, _, itemData, selectionChanged)
                if selectionChanged and itemData then
                    Timed(containerName .. " selected " .. itemData.key, nil, select, itemData.key)
                end
            end)
        entry.key = entryContext.key
        combo:AddItem(entry)
        if entryContext.key == selected then combo:SetSelectedItem(entryContext.title) end
    end
    return combo
end

local function ConfigureToolbar()
    local topBar = Window("TopActionBar")
    contextCombo = ConfigureCombo("ContextMode", context, function(value)
        context = value
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end)

    local source = copyContextCombo and copyContextCombo.selectedKey or nil
    if source == nil or source == context then
        source = this.AutoCategoryIntegration.GetContexts()[1].key
        if source == context then source = this.AutoCategoryIntegration.GetContexts()[2].key end
    end
    copyContextCombo = ConfigureCombo("CopyContext", source, function(value)
        copyContextCombo.selectedKey = value
        GetControl(Window("OptionsBar"), "BtnCopy"):SetEnabled(value ~= context)
    end)
    copyContextCombo.selectedKey = source

    local copy = GetControl(Window("OptionsBar"), "BtnCopy")
    copy:SetText("Copy")
    copy:SetEnabled(source ~= context)
    copy:SetHandler("OnClicked", function() Timed("copy both orders", nil, this.AutoCategoryIntegration.Run, function()
        local currentSource = copyContextCombo.selectedKey
        assert(IsActive() and currentSource ~= context, "AutoCategory copy targets an invalid context")
        this.AutoCategoryIntegration.CopyBothOrders(currentSource, context)
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    copy:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, "Copy both the priority and display orders from the selected context. Only references present in this context are reordered.")
    end)
    copy:SetHandler("OnMouseExit", HideTooltip)

    local options = Window("OptionsBar")
    local display = GetControl(options, "BtnDisplayOrder")
    local priority = GetControl(options, "BtnPriorityOrder")
    display:SetEnabled(mode ~= "display")
    priority:SetEnabled(mode ~= "matching")
    display:SetHandler("OnClicked", function() Timed("display order mode", nil, function()
        mode = "display"
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    priority:SetHandler("OnClicked", function() Timed("priority order mode", nil, function()
        mode = "matching"
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end) end)
    local area
    for _, entry in ipairs(this.AutoCategoryIntegration.GetContexts()) do
        if entry.key == context then
            area = entry.title:lower()
            break
        end
    end
    assert(area, "AutoCategory explanation requires a known context")
    local info, instructions = Window("Info"), Window("Instructions")
    instructions:SetText("Click a group to select it. Shift-Click selects multiple groups."
        .. " Buttons move groups up and down.")
    local paragraph, compact
    if mode == "display" then
        Window("OrderTitle"):SetText("Display order")
        paragraph = "Move groups to set the order they appear in your %s."
            .. " If you hide a group then it will always be empty, and will not appear."
        compact = "Order groups in your %s. Hidden groups stay empty and do not appear."
    else
        Window("OrderTitle"):SetText("Priority order")
        paragraph = "When an item matches multiple groups, the first included group wins in your %s."
            .. " Hidden groups stay empty and do not appear."
        compact = "The first included match wins in your %s. Hidden groups stay empty and do not appear."
    end
    info:SetText(paragraph:format(area))
    if info:GetNumLines() + instructions:GetNumLines() > 3 then
        info:SetText(compact:format(area))
    end
    info:SetHeight(info:GetTextHeight())
    instructions:SetHeight(instructions:GetTextHeight())
end

local function GetOrCreateRow(scrollChild, index)
    local row = rows[index]
    if row == nil then
        row = CreateControlFromVirtual("InventoryCompanion_AutoCategoryRow_", scrollChild,
            "InventoryCompanion_AutoCategoryRow_Template", index)
        rows[index] = row
    end
    return row
end

local function CanOrder(entry)
    return entry.included == true
end

local function SetRowBackground(row, entry, hovered)
    local bg = GetControl(row, "BG")
    if IsSelected(entry) then
        bg:SetColor(0.16, 0.42, 0.64, 1)
        bg:SetAlpha(0.8)
    else
        bg:SetColor(1, 1, 1, 1)
        bg:SetAlpha(hovered and 0.12 or 0)
    end
end

local function MoveSelection(movement)
    local applied = this.AutoCategoryIntegration.MoveEntries(selectedReferences, context, mode, movement)
    if not applied then return end
    local movingDown = movement == "bottom" or type(movement) == "number" and movement > 0
    scrollAfterMove = movingDown and "last" or "first"
    PlaySound(SOUNDS.MENU_BAR_CLICK)
    this.RefreshAutoCategoryEditor()
end

local function ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    local participation = GetControl(row, "Participation")
    participation:SetHidden(entry.kind == "other")
    if entry.kind == "other" then return end
    participation:SetNormalFontColor(1, 0.94, 0.76, 1)
    participation:SetMouseOverFontColor(1, 0.82, 0.46, 1)
    participation:SetText(entry.included and "Hide" or "Show")
    participation:SetHandler("OnClicked", function()
        Timed("inclusion " .. tostring(not entry.included), entry, this.AutoCategoryIntegration.Run, function()
            assert(row.autoCategoryEntry == entry, "AutoCategory participation action targets a stale row")
            AssertCurrentView(contextAtRender, modeAtRender)
            Phase("SetEntryIncluded", this.AutoCategoryIntegration.SetEntryIncluded,
                entry.reference, contextAtRender, not entry.included)
            this.RefreshAutoCategoryEditor()
            Phase("RefreshTrackedItemsEditor", this.RefreshTrackedItemsEditor)
        end)
    end)
    participation:SetHandler("OnMouseEnter", function(control)
        local scope = " in this context"
        ShowTooltip(control, entry.included
            and "Included" .. scope .. ". Click to exclude it and move it below the Excluded divider in both lists."
            or "Excluded" .. scope .. ". Click to include it again in both lists."
                .. " Its display position is restored; matching priority starts from the restored display number.")
    end)
    participation:SetHandler("OnMouseExit", HideTooltip)
end

local function ConfigureMoves(row, entry, canMoveUp, canMoveDown, contextAtRender, modeAtRender)
    local moveUp, moveDown = GetControl(row, "MoveUp"), GetControl(row, "MoveDown")
    local canMove = CanOrder(entry)
    moveUp:SetHidden(not canMove)
    moveDown:SetHidden(not canMove)
    if not canMove then return end
    moveUp:SetEnabled(IsSelected(entry) and canMoveUp or not IsSelected(entry) and entry.index > 1)
    moveDown:SetEnabled(IsSelected(entry) and canMoveDown or not IsSelected(entry) and entry.index < entry.orderCount)
    local function Move(direction)
        assert(row.autoCategoryEntry == entry, "AutoCategory move action targets a stale row")
        AssertCurrentView(contextAtRender, modeAtRender)
        if not IsSelected(entry) then selectedReferences = { [entry.reference] = true } end
        MoveSelection(direction)
    end
    moveUp:SetHandler("OnClicked", function() Timed("row up", entry, this.AutoCategoryIntegration.Run, Move, -1) end)
    moveDown:SetHandler("OnClicked", function() Timed("row down", entry, this.AutoCategoryIntegration.Run, Move, 1) end)
    moveUp:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, IsSelected(entry) and "Move the whole selection up one step." or "Select and move this assignment up one step.")
    end)
    moveDown:SetHandler("OnMouseEnter", function(control)
        ShowTooltip(control, IsSelected(entry) and "Move the whole selection down one step." or "Select and move this assignment down one step.")
    end)
    moveUp:SetHandler("OnMouseExit", HideTooltip)
    moveDown:SetHandler("OnMouseExit", HideTooltip)
end

local function PopulateRow(row, entry, displayIndex, scrollChild, contextAtRender, modeAtRender, canMoveUp, canMoveDown)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, scrollChild, TOPLEFT, 0, (displayIndex - 1) * ROW_HEIGHT)
    row:SetHidden(false)
    row.autoCategoryEntry = entry

    local label = GetControl(row, "Name")
    SetRowBackground(row, entry, false)
    local orders = GetControl(row, "Orders")
    if entry.kind == "divider" then
        label:SetText("Excluded")
        label:SetColor(1, 0.7, 0.7, 1)
        orders:SetText("")
        for _, name in ipairs({ "Participation", "MoveUp", "MoveDown" }) do GetControl(row, name):SetHidden(true) end
        for _, event in ipairs({ "OnMouseDown", "OnMouseEnter", "OnMouseExit" }) do row:SetHandler(event, nil) end
        return
    end
    orders:SetText("")
    if entry.kind == "heading" then
        label:SetText("AutoCategory: " .. EscapeEsoMarkup(entry.name))
        label:SetColor(0.65, 0.68, 1, 1)
    else
        label:SetText(entry.name)
        if modeAtRender == "display" then label:SetColor(0.2, 0.8, 0.4, 1)
        else label:SetColor(0.60, 0.90, 0.65, 1) end
    end
    if not entry.included then label:SetColor(1, 0.25, 0.25, 1) end

    row:SetHandler("OnMouseEnter", function()
        SetRowBackground(row, entry, true)
        if entry.kind == "other" then
            ShowTooltip(row, "Other always matches after included categories and before excluded categories."
                .. " Moving it changes display order only, not matching precedence.")
        end
    end)
    row:SetHandler("OnMouseExit", function()
        SetRowBackground(row, entry, false)
        HideTooltip()
    end)
    row:SetHandler("OnMouseDown", function(_, button)
        Timed("row click " .. tostring(button), entry, this.AutoCategoryIntegration.Run, function()
            if button ~= MOUSE_BUTTON_INDEX_LEFT or not CanOrder(entry) then return end
            assert(row.autoCategoryEntry == entry, "AutoCategory row selection targets stale data")
            AssertCurrentView(contextAtRender, modeAtRender)
            if IsShiftKeyDown() then
                selectedReferences[entry.reference] = not IsSelected(entry) and true or nil
            else
                selectedReferences = { [entry.reference] = true }
            end
            this.RefreshAutoCategoryEditor()
        end)
    end)

    ConfigureParticipation(row, entry, contextAtRender, modeAtRender)
    ConfigureMoves(row, entry, canMoveUp, canMoveDown, contextAtRender, modeAtRender)
end

local function ConfigureMovementToolbar(entries, sequence, contextAtRender, modeAtRender)
    local toolbar = Window("MovementBar")
    local function Configure(name, enabled, action, tooltip)
        local button = GetControl(toolbar, name)
        button:SetEnabled(enabled)
        button:SetHandler("OnClicked", function() Timed("toolbar " .. name, nil, this.AutoCategoryIntegration.Run, function()
            AssertCurrentView(contextAtRender, modeAtRender)
            action()
        end) end)
        button:SetHandler("OnMouseEnter", function(control) ShowTooltip(control, tooltip) end)
        button:SetHandler("OnMouseExit", HideTooltip)
    end
    for _, action in ipairs({
        { "BtnUp1", -1 }, { "BtnDown1", 1 }, { "BtnUp5", -5 }, { "BtnDown5", 5 },
        { "BtnTop", "top" }, { "BtnBottom", "bottom" },
    }) do
        local movement = action[2]
        local _, changed = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, movement)
        Configure(action[1], changed, function() MoveSelection(movement) end,
            "Move the whole selection. Five steps behave like repeated one-step moves.")
    end
    local selectedKind, mixed = nil, false
    for _, entry in ipairs(entries) do
        if IsSelected(entry) then
            if selectedKind and selectedKind ~= entry.kind then mixed = true end
            selectedKind = entry.kind
        end
    end
    Configure("BtnSelectBlock", selectedKind ~= nil and not mixed, function()
        assert(not mixed, "Cannot expand mixed AutoCategory selections")
        local runStart = 1
        while runStart <= #sequence do
            local runEnd, seeded = runStart, false
            local kind = entries[runStart].kind
            while runEnd <= #sequence and entries[runEnd].kind == kind do
                seeded = seeded or IsSelected(entries[runEnd])
                runEnd = runEnd + 1
            end
            if seeded then
                for index = runStart, runEnd - 1 do selectedReferences[sequence[index]] = true end
            end
            runStart = runEnd
        end
        this.RefreshAutoCategoryEditor()
    end, "Add touching rows of the same type around every selected row. Unavailable for mixed AC/IC selections.")
    Configure("BtnClear", next(selectedReferences) ~= nil, function()
        selectedReferences = {}
        this.RefreshAutoCategoryEditor()
    end, "Clear the row selection without changing participation or ordering.")
end

local function PopulateList(contextAtRender, modeAtRender)
    for _, row in ipairs(rows) do row:SetHidden(true) end
    local scrollChild = GetControl(Window("List"), "ScrollChild")
    assert(scrollChild, "AutoCategory editor is missing its list ScrollChild")
    local entries = Phase("ResolveAutoCategoryOrder", this.AutoCategoryIntegration.ResolveAutoCategoryOrder,
        contextAtRender, { mode = modeAtRender })
    local sequence, orderable = {}, {}
    for _, entry in ipairs(entries) do
        if CanOrder(entry) then
            sequence[#sequence + 1] = entry.reference
            orderable[entry.reference] = true
        end
    end
    for reference in pairs(selectedReferences) do
        if not orderable[reference] then selectedReferences[reference] = nil end
    end
    local _, canMoveUp = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, -1)
    local _, canMoveDown = this.AutoCategoryIntegration.GetMovedSequence(sequence, selectedReferences, 1)
    local firstSelected, lastSelected
    Phase("populate " .. #entries .. " rows", function()
        for index, entry in ipairs(entries) do
            local row = GetOrCreateRow(scrollChild, index)
            PopulateRow(row, entry, index, scrollChild, contextAtRender, modeAtRender, canMoveUp, canMoveDown)
            if IsSelected(entry) then
                firstSelected = firstSelected or row
                lastSelected = row
            end
        end
    end)
    scrollChild:SetHeight(#entries * ROW_HEIGHT)
    ZO_Scroll_UpdateScrollBar(Window("List"))
    Phase("ConfigureMovementToolbar", ConfigureMovementToolbar, entries, sequence, contextAtRender, modeAtRender)
    if scrollAfterMove and firstSelected then
        ZO_Scroll_ScrollControlIntoView(Window("List"), scrollAfterMove == "last" and lastSelected or firstSelected)
    end
    scrollAfterMove = nil
end

function this.RefreshAutoCategoryEditor()
    if InventoryCompanion_AutoCategoryWindow:IsHidden() then return end
    local failed = this.AutoCategoryIntegration.NeedsRecovery()
    local awaitingSetup = this.AutoCategoryIntegration.IsAwaitingSetup()
    local inactive = not IsActive()
    local recoveryVisible = failed
    for _, name in ipairs({ "TopActionBar", "OptionsBar", "OrderTitle", "Info", "Instructions", "List", "MovementBar" }) do
        Window(name):SetHidden(recoveryVisible or inactive)
    end
    local off = Window("Enablement")
    off:SetHidden(failed or not inactive)
    if inactive or failed then
        this.RefreshEditorChrome(InventoryCompanion_AutoCategoryWindow, "autocategory", context, mode)
    end
    if inactive and not failed then
        GetControl(off, "Info"):SetText(this.GetAutoCategoryInfoText())
        local toggle = GetControl(off, "Toggle")
        toggle:SetEnabled(this.AutoCategoryIntegration.IsAvailable())
        ZO_CheckButton_SetCheckState(toggle, this.GetAutoCategoryState().configuredEnabled)
        ZO_CheckButton_SetToggleFunction(toggle, function(_, value)
            this.SetAutoCategoryIntegrationEnabled(value)
            this.RefreshAutoCategoryUI()
        end)
    end
    local recovery = Window("Recovery")
    recovery:SetHidden(not recoveryVisible)
    if recoveryVisible then
        selectedReferences = {}
        scrollAfterMove = nil
        for _, row in ipairs(rows) do row:SetHidden(true) end
        local _, message = this.AutoCategoryIntegration.GetStatus()
        GetControl(recovery, "Warning"):SetText(failed and this.AutoCategoryIntegration.GetRecoveryMessage() or message)
        for _, name in ipairs({ "BtnRetry", "BtnRepair", "BtnDetails", "BtnReset" }) do
            GetControl(recovery, name):SetHidden(not failed)
        end
        local enable = GetControl(recovery, "BtnEnableSetup")
        enable:SetHidden(not awaitingSetup or failed)
        enable:SetHandler("OnClicked", function() this.SetAutoCategoryIntegrationEnabled(true) end)
        local retry = GetControl(recovery, "BtnRetry")
        retry:SetHandler("OnClicked", function() this.AutoCategoryIntegration.RetrySynchronization() end)
        local repair = GetControl(recovery, "BtnRepair")
        repair:SetEnabled(this.AutoCategoryIntegration.CanRepairAssignments())
        repair:SetHandler("OnClicked", function() this.AutoCategoryIntegration.ShowAssignmentRepair() end)
        repair:SetHandler("OnMouseEnter", function(control)
            ShowTooltip(control, this.AutoCategoryIntegration.CanRepairAssignments()
                and "Preview removal of affected IC-owned assignments in the active AC profile, then synchronize."
                or "No specific assignment repair is available. Retry or use Show details; code defects cannot be repaired by deleting rows.")
        end)
        repair:SetHandler("OnMouseExit", HideTooltip)
        GetControl(recovery, "BtnDetails"):SetHandler("OnClicked", function()
            this.AutoCategoryIntegration.ShowRecoveryDetails()
        end)
        GetControl(recovery, "BtnReset"):SetHandler("OnClicked", function()
            this.AutoCategoryIntegration.ShowIntegrationReset()
        end)
        GetControl(recovery, "Help"):SetText(awaitingSetup and not failed
            and "Reset is complete. Integration is disabled. Enable and set up again to choose the starting arrangement."
                .. " Your IC groups and native AC categories were preserved."
            or "Retry validates your configuration. Repair previews removal of affected IC-owned assignments."
                .. " Reset integration is the last resort: it clears the selected IC profile's integration setup and ordering"
                .. " and all IC-owned assignments in the active AC profile. It requires confirmation.")
        local problems = GetControl(recovery, "Problems")
        problems:SetHidden(not failed)
        if failed then
            local label = GetControl(problems, "ScrollChildProblemRows")
            label:SetText(this.AutoCategoryIntegration.GetProblemRowsMessage())
            GetControl(problems, "ScrollChild"):SetHeight(label:GetTextHeight())
            ZO_Scroll_UpdateScrollBar(problems)
        end
        return
    end
    if inactive then return end
    Phase("RefreshAutoCategoryEditor", this.AutoCategoryIntegration.Run, function()
        local profile = this.GetAutoCategoryProfile()
        if selectionProfile ~= profile then
            selectedReferences = {}
            selectionProfile = profile
        end
        Phase("ConfigureToolbar", ConfigureToolbar)
        local contextAtRender, modeAtRender = context, mode
        PopulateList(contextAtRender, modeAtRender)
        this.RefreshEditorChrome(InventoryCompanion_AutoCategoryWindow, "autocategory", context, mode)
    end)
end

local autoCategoryScene = ZO_Scene:New("InventoryCompanion_AutoCategoryScene", SCENE_MANAGER)
autoCategoryScene:AddFragment(ZO_FadeSceneFragment:New(InventoryCompanion_AutoCategoryWindow))

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyShown", function()
    SetGameCameraUIMode(true)
    if this.AutoCategoryIntegration.NeedsRecovery() or this.AutoCategoryIntegration.IsAwaitingSetup() then
        this.RefreshAutoCategoryEditor()
    else
        Timed("open editor", nil, this.RefreshAutoCategoryEditor)
    end
    this.UpdateEditorLayout()
end)

InventoryCompanion_AutoCategoryWindow:SetHandler("OnEffectivelyHidden", function()
    this.EndEditorVisit(InventoryCompanion_AutoCategoryWindow)
    SetGameCameraUIMode(false)
    this.UpdateEditorLayout()
end)
