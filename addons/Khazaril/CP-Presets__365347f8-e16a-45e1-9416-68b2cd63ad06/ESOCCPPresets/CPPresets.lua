-- CP Presets
-- One-press Champion Point presets, plus presets of your own. Open the game's Champion screen and
-- click the left stick for "CP Presets" (on keyboard, the button shows on the key strip).
--
-- The list on the left has the starter presets, then your own presets (shared by every character
-- on the account), then "Save current points as a preset". The right shows what the chosen preset
-- would do for this character, tree by tree. A applies it (press twice to confirm).
-- Your own presets: X renames, Y deletes (press twice).

local ADDON_NAME = "ESOCCPPresets"
local SCENE_NAME = "esocCPPresets"
local RENAME_DIALOG = "ESOC_CPP_RENAME"
local VERSION = "1.0.4"
local MAX_NAME = 40
local CP = ESOC_CPP

local sv
local scene, window, ui
local state = { index = nil, top = 1, confirm = false, deleteArm = nil, message = nil, success = false, awaiting = false }
local keybinds, entries

local TREE_COLOURS = {
    warfare = { 0.27, 0.50, 0.92 },
    fitness = { 0.85, 0.32, 0.27 },
    craft = { 0.36, 0.72, 0.36 },
}
local GOLD = { 0.93, 0.78, 0.42 }
local WHITE, GREY, DIM = { 1, 1, 1 }, { 0.72, 0.72, 0.72 }, { 0.5, 0.5, 0.5 }
local ORANGE, GREEN = { 1, 0.62, 0.3 }, { 0.45, 0.85, 0.45 }

local function colourText(c, text)
    return string.format("|c%02x%02x%02x%s|r", math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), tostring(text))
end

local function playerName()
    local who = "this character"
    pcall(function() who = CP.fmt(GetUnitName("player")) end)
    return who
end

local function trim(s)
    return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

---------------------------------------------------------------------------
-- The list: starter presets, your presets, and the "save" row
---------------------------------------------------------------------------
local function buildEntries()
    local list = { { kind = "header", text = "STARTER PRESETS" } }
    for _, p in ipairs(CP.presets) do list[#list + 1] = { kind = "starter", preset = p } end
    list[#list + 1] = { kind = "header", text = "YOUR PRESETS" }
    for i, p in ipairs(sv.custom) do list[#list + 1] = { kind = "custom", preset = p, slot = i } end
    list[#list + 1] = { kind = "save" }
    entries = list
end

local function firstSelectable()
    for i, e in ipairs(entries) do
        if e.kind ~= "header" then return i end
    end
    return 1
end

-- The keybind strip asks for button names as soon as the screen opens, so this must never fail.
local function current()
    if not entries or not state.index then return nil end
    return entries[state.index]
end

local function uniqueName(base)
    local taken = {}
    for _, p in ipairs(sv.custom) do taken[p.name] = true end
    for _, p in ipairs(CP.presets) do taken[p.name] = true end
    if not taken[base] then return base end
    local n = 2
    while taken[base .. " " .. n] do n = n + 1 end
    return base .. " " .. n
end

---------------------------------------------------------------------------
-- Building the screen: 1920 x 1080 gamepad UI space, everything anchored to the top-left
---------------------------------------------------------------------------
local LIST_X, LIST_Y, ROW_H, VISIBLE_ROWS = 80, 196, 58, 11

local function buildUI()
    local root = WINDOW_MANAGER:CreateControl("ESOCCPPresetsRoot", window, CT_CONTROL)
    root:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    root:SetDimensions(1920, 1080)
    local u = { root = root, rows = {}, cards = {} }

    local function tex(x, y, w, h, c, a, level)
        local t = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
        t:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        t:SetDimensions(w, h)
        t:SetColor(c[1], c[2], c[3], a or 1)
        t:SetDrawLevel(level or 1)
        return t
    end
    local function lbl(x, y, font, w, c)
        local l = WINDOW_MANAGER:CreateControl(nil, root, CT_LABEL)
        l:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        l:SetFont(font)
        if w then l:SetWidth(w) end
        l:SetColor(c[1], c[2], c[3], 1)
        l:SetDrawLevel(5)
        return l
    end

    tex(0, 0, 1920, 1080, { 0.03, 0.03, 0.05 }, 0.93, 0)
    u.title = lbl(80, 46, "ZoFontGamepad42", nil, WHITE)
    u.title:SetText("CP Presets")
    u.points = lbl(80, 110, "ZoFontGamepad27", 1760, WHITE)

    -- left: the list (a window of VISIBLE_ROWS rows that scrolls with the selection)
    for i = 1, VISIBLE_ROWS do
        local y = LIST_Y + (i - 1) * ROW_H
        u.rows[i] = {
            bg = tex(LIST_X, y, 440, ROW_H - 8, GOLD, 0.18, 1),
            bar = tex(LIST_X, y, 6, ROW_H - 8, GOLD, 1, 2),
            line = tex(LIST_X, y + ROW_H - 14, 440, 2, DIM, 0.6, 1),
            label = lbl(LIST_X + 26, y + 9, "ZoFontGamepad34", 400, GREY),
        }
        pcall(function() u.rows[i].label:SetMaxLineCount(1) end)
    end
    u.moreUp = lbl(LIST_X + 380, LIST_Y - 40, "ZoFontGamepad27", nil, DIM)
    u.moreDown = lbl(LIST_X + 380, LIST_Y + VISIBLE_ROWS * ROW_H - 4, "ZoFontGamepad27", nil, DIM)

    -- right: chosen preset and three tree cards
    local rightX = 580
    u.name = lbl(rightX, 182, "ZoFontGamepad42", 1260, GOLD)
    u.desc = lbl(rightX, 236, "ZoFontGamepad27", 1260, GREY)
    pcall(function() u.desc:SetMaxLineCount(1) end)
    local cardY, cardW, cardH, gap = 296, 400, 524, 30
    for i, key in ipairs(CP.TREE_KEYS) do
        local x, colour = rightX + (i - 1) * (cardW + gap), TREE_COLOURS[key]
        tex(x, cardY, cardW, cardH, { 1, 1, 1 }, 0.06, 1)
        tex(x, cardY, cardW, 58, colour, 0.9, 2)
        local card = {
            header = lbl(x + 20, cardY + 10, "ZoFontGamepad34", cardW - 40, WHITE),
            spent = lbl(x + 20, cardY + 72, "ZoFontGamepad27", cardW - 40, GREY),
            slots = {},
            passive = lbl(x + 20, cardY + 362, "ZoFontGamepad27", cardW - 40, GREY),
            warn = lbl(x + 20, cardY + 400, "ZoFontGamepad27", cardW - 40, ORANGE),
        }
        lbl(x + 20, cardY + 116, "ZoFontGamepad27", nil, DIM):SetText("SLOTTED STARS")
        for s = 1, 4 do
            local y = cardY + 156 + (s - 1) * 52
            card.slots[s] = {
                dot = tex(x + 22, y + 10, 14, 14, colour, 1, 3),
                label = lbl(x + 50, y, "ZoFontGamepad27", cardW - 70, WHITE),
            }
        end
        pcall(function() card.warn:SetMaxLineCount(4) end) -- never spill out of the card
        u.cards[key] = card
    end

    -- status box above the button strip
    u.statusBg = tex(rightX, 840, 1260, 120, { 1, 1, 1 }, 0.06, 1)
    u.statusBar = tex(rightX, 840, 6, 120, GOLD, 1, 2)
    u.status = lbl(rightX + 26, 856, "ZoFontGamepad27", 1210, WHITE)
    return u
end

---------------------------------------------------------------------------
-- Showing the chosen preset
---------------------------------------------------------------------------
local function setCard(card, header, spentText, slots, passiveText, warnText)
    card.header:SetText(header)
    card.spent:SetText(spentText)
    for i = 1, 4 do
        local slot, star = card.slots[i], slots[i]
        if star then
            slot.label:SetText(star.name .. "  " .. colourText({ 0.55, 0.55, 0.55 }, star.points))
            slot.label:SetColor(1, 1, 1, 1)
            slot.dot:SetHidden(false)
        else
            slot.label:SetText("empty")
            slot.label:SetColor(0.45, 0.45, 0.45, 1)
            slot.dot:SetHidden(true)
        end
    end
    card.passive:SetText(passiveText or "")
    card.warn:SetText(warnText or "")
end

local function plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
end

local function renderList()
    -- keep the selection inside the visible window
    if state.index < state.top then state.top = state.index end
    if state.index > state.top + VISIBLE_ROWS - 1 then state.top = state.index - VISIBLE_ROWS + 1 end
    if state.index <= 2 then state.top = 1 end -- show the first header when at the top
    state.top = math.max(1, math.min(state.top, math.max(1, #entries - VISIBLE_ROWS + 1)))

    for i, row in ipairs(ui.rows) do
        local e = entries[state.top + i - 1]
        local on = (state.top + i - 1 == state.index)
        row.bg:SetHidden(not on)
        row.bar:SetHidden(not on)
        row.line:SetHidden(not (e and e.kind == "header"))
        if not e then
            row.label:SetText("")
        elseif e.kind == "header" then
            row.label:SetFont("ZoFontGamepad27")
            row.label:SetText(e.text)
            row.label:SetColor(DIM[1], DIM[2], DIM[3], 1)
        else
            row.label:SetFont("ZoFontGamepad34")
            local text = e.kind == "save" and "+ Save current points" or e.preset.name
            row.label:SetText(text)
            if on then row.label:SetColor(1, 1, 1, 1)
            elseif e.kind == "save" then row.label:SetColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else row.label:SetColor(0.62, 0.62, 0.62, 1) end
        end
    end
    ui.moreUp:SetText(state.top > 1 and "more" or "")
    ui.moreDown:SetText(state.top + VISIBLE_ROWS - 1 < #entries and "more" or "")
end

local function setStatus(text, colour)
    ui.status:SetText(text)
    ui.status:SetColor(colour[1], colour[2], colour[3], 1)
    ui.statusBar:SetColor(colour[1], colour[2], colour[3], 1)
end

local function show()
    if not ui then ui = buildUI() end
    if not entries then buildEntries() end
    if not state.index or not entries[state.index] or entries[state.index].kind == "header" then
        state.index = firstSelectable()
    end
    renderList()
    local e = current()

    -- unspent points line
    local trees
    local okTrees = pcall(function() trees = CP.ReadTrees() end)
    local totalUnspent = 0
    if okTrees and trees then
        local parts = {}
        for _, key in ipairs(CP.TREE_KEYS) do
            local tree = trees[key]
            if tree then
                totalUnspent = totalUnspent + tree.unspent
                parts[#parts + 1] = colourText(TREE_COLOURS[key], tree.name) .. "  " .. tree.unspent
            end
        end
        ui.points:SetText(playerName() .. ".   Unspent points:   " .. table.concat(parts, "      "))
    else
        ui.points:SetText("Could not read your Champion points.")
    end

    -- the "save" row shows what would be saved
    if e.kind == "save" then
        ui.name:SetText("Save current points as a preset")
        ui.desc:SetText("Your presets are shared by all your characters.")
        local ok, err = pcall(function()
            local captured, capTrees = CP.Capture()
            for _, s in ipairs(CP.CaptureSummary(captured, capTrees)) do
                setCard(ui.cards[s.key], s.name, s.total > 0 and (s.total .. " points spent") or "No points spent",
                    s.slots, s.otherPoints > 0 and string.format("+ %d points in %s", s.otherPoints, plural(s.otherStars, "other star")) or "", "")
            end
        end)
        if not ok then ui.desc:SetText("Could not read your Champion points: " .. tostring(err)) end
        if state.message then
            setStatus(state.message, state.success and GREEN or ORANGE)
        else
            setStatus("Press A to save " .. playerName() .. "'s Champion points and slotted stars as a new preset.\nYou can rename it afterwards with X.", GREY)
        end
        return
    end

    local preset = e.preset
    ui.name:SetText(preset.name)
    if e.kind == "custom" then
        ui.desc:SetText(preset.desc or "Your preset.")
    else
        ui.desc:SetText(preset.desc)
    end

    local summary
    local ok, err = pcall(function()
        state.plans, state.trees, state.respec = CP.Plan(preset)
        summary = CP.Summary(state.plans, state.trees)
    end)
    local anySpend = false
    if ok then
        for _, s in ipairs(summary) do
            local spentText
            if s.respec then
                spentText = s.spent > 0 and ("Sets " .. s.spent .. " points") or "No points"
            else
                spentText = s.spent > 0 and ("Spends " .. s.spent .. " of " .. s.unspent .. " points") or "No points to spend"
            end
            if s.spent > 0 then anySpend = true end
            local warn = {}
            if #s.skipped > 0 then warn[#warn + 1] = "Unlocks with more CP: " .. table.concat(s.skipped, ", ") end
            if s.short > 0 then warn[#warn + 1] = s.short .. " points short of the saved preset" end
            if #s.missing > 0 then warn[#warn + 1] = "Not found in game: " .. table.concat(s.missing, ", ") end
            if s.notSlottable and #s.notSlottable > 0 then warn[#warn + 1] = "Can't be slotted: " .. table.concat(s.notSlottable, ", ") end
            setCard(ui.cards[s.key], s.name, spentText, s.slots,
                s.passivePoints > 0 and string.format("+ %d points in %s", s.passivePoints, plural(s.passiveStars, e.kind == "custom" and "other star" or "passive star")) or "",
                table.concat(warn, "\n"))
        end
    else
        ui.desc:SetText("Could not plan this preset: " .. tostring(err))
    end

    local text, colour = nil, GOLD
    local cost = state.respec and CP.RespecCost() or 0
    if state.message then
        text, colour = state.message, state.success and GREEN or ORANGE
    elseif state.deleteArm == state.index then
        text, colour = "Press Y again to delete " .. preset.name .. ". This can't be undone.", ORANGE
    elseif state.confirm then
        if state.respec then
            text = "Press A again to respec for " .. cost .. " gold and apply " .. preset.name .. "."
        else
            text = "Press A again to spend the points and slot the stars.\nChanging them later costs gold, like any Champion respec."
        end
    elseif state.respec then
        text = string.format("This preset moves points this character has already spent, so it needs a respec: %d gold (you have %d).\nPress A to use it.", cost, CP.Gold())
        colour = CP.Gold() >= cost and GOLD or ORANGE
    elseif ok and not anySpend then
        text, colour = (totalUnspent == 0 and "No unspent Champion points. " or "Nothing to spend. ") .. "A will still slot the stars.", GREY
    else
        text, colour = "Press A to use " .. preset.name .. ".   LB / RB: choose a preset.", GREY
    end
    setStatus(text, colour)
end

local function refresh()
    if keybinds then pcall(function() KEYBIND_STRIP:UpdateKeybindButtonGroup(keybinds) end) end
    show()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function resetPrompts()
    state.confirm, state.deleteArm, state.message, state.success = false, nil, nil, false
end

local function move(delta)
    if not entries then return end
    local i = state.index or firstSelectable()
    repeat
        i = (i - 1 + delta) % #entries + 1
    until entries[i].kind ~= "header"
    state.index = i
    resetPrompts()
    refresh()
end

-- New characters must spend their attribute points before the game accepts Champion purchases.
local function attributeHint()
    local ok, n = pcall(GetAttributeUnspentPoints)
    if ok and type(n) == "number" and n > 0 then
        return "\nYou have " .. n .. " unspent attribute point" .. (n == 1 and "" or "s") ..
            ". Spend " .. (n == 1 and "it" or "them") .. " first (Character menu), then try again."
    end
    return ""
end

local function reasonText(reason)
    if type(reason) == "string" then return reason end
    local why = tostring(reason)
    pcall(function() why = GetString("SI_CHAMPIONPURCHASERESULT", reason) end)
    return why
end

local function savePreset()
    local preset = CP.Capture()
    local cp = 0
    pcall(function() cp = GetPlayerChampionPointsEarned() end)
    local who = playerName()
    preset.name = uniqueName(who .. " " .. cp .. " CP")
    local when = ""
    pcall(function() when = ", " .. GetDateStringFromTimestamp(GetTimeStamp()) end)
    preset.desc = "Saved from " .. who .. " (" .. cp .. " CP" .. when .. ")."
    sv.custom[#sv.custom + 1] = preset
    buildEntries()
    for i, e in ipairs(entries) do
        if e.preset == preset then state.index = i end
    end
    resetPrompts()
    state.message, state.success = "Saved as \"" .. preset.name .. "\". Press X to rename it.", true
    refresh()
end

local function applyPreset()
    if not state.confirm then
        resetPrompts()
        state.confirm = true
        refresh()
        return
    end
    state.confirm, state.success = false, false
    local ok, sent, reason = pcall(CP.Apply, state.plans, state.trees, state.respec)
    if not ok then
        state.message = "Something went wrong: " .. tostring(sent)
    elseif not sent then
        state.message = "The game won't allow it right now: " .. reasonText(reason) .. attributeHint()
    else
        state.message, state.awaiting = "Sent to the game...", true
    end
    refresh()
end

local function primary()
    local e = current()
    if not e then return end
    if e.kind == "save" then savePreset() else applyPreset() end
end

local function deletePreset()
    local e = current()
    if not e or e.kind ~= "custom" then return end
    if state.deleteArm ~= state.index then
        resetPrompts()
        state.deleteArm = state.index
        refresh()
        return
    end
    for i, p in ipairs(sv.custom) do
        if p == e.preset then table.remove(sv.custom, i) break end
    end
    buildEntries()
    if not entries[state.index] or entries[state.index].kind == "header" then state.index = nil end
    if state.index == nil then state.index = firstSelectable() end
    resetPrompts()
    state.message, state.success = "Deleted " .. e.preset.name .. ".", true
    refresh()
end

local function onPurchaseResult(_, result)
    if not state.awaiting then return end
    state.awaiting = false
    if result == CHAMPION_PURCHASE_SUCCESS then
        state.message, state.success = "Done! Points spent and stars slotted.", true
    else
        state.message, state.success = "The game refused: " .. reasonText(result) .. attributeHint(), false
    end
    if ui and not ui.root:IsHidden() then pcall(refresh) end
end

---------------------------------------------------------------------------
-- Renaming: the game's own gamepad text dialog (brings up the console keyboard)
---------------------------------------------------------------------------
local renameTarget, renameText
local renameReady = false

local function commitRename()
    local name = trim(renameText):sub(1, MAX_NAME)
    if renameTarget and name ~= "" and name ~= renameTarget.name then
        renameTarget.name = name
        state.message, state.success = "Renamed to \"" .. name .. "\".", true
    end
    renameTarget = nil
    pcall(function() ZO_Dialogs_ReleaseDialogOnButtonPress(RENAME_DIALOG) end)
    refresh()
end

local function registerRenameDialog()
    if renameReady then return true end
    local ok = pcall(function()
        ZO_Dialogs_RegisterCustomDialog(RENAME_DIALOG, {
            gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
            setup = function(dialog) dialog:setupFunc() end,
            blockDialogReleaseOnPress = true,
            title = { text = "Rename preset" },
            parametricList = {
                {
                    template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                    templateData = {
                        nameField = true,
                        textChangedCallback = function(control) renameText = control:GetText() end,
                        setup = function(control, data, selected)
                            control.highlight:SetHidden(not selected)
                            control.editBoxControl.textChangedCallback = data.textChangedCallback
                            control.editBoxControl:SetMaxInputChars(MAX_NAME)
                            control.editBoxControl:SetText(renameText or "")
                        end,
                        callback = function(dialog)
                            local target = dialog.entryList:GetTargetControl()
                            target.editBoxControl:TakeFocus()
                        end,
                    },
                },
                {
                    template = "ZO_GamepadMenuEntryTemplate",
                    templateData = {
                        text = "Save name",
                        setup = ZO_SharedGamepadEntry_OnSetup,
                        callback = function() commitRename() end,
                    },
                },
            },
            buttons = {
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = SI_DIALOG_CANCEL,
                    callback = function()
                        renameTarget = nil
                        ZO_Dialogs_ReleaseDialogOnButtonPress(RENAME_DIALOG)
                    end,
                },
                {
                    keybind = "DIALOG_PRIMARY",
                    text = SI_GAMEPAD_SELECT_OPTION,
                    callback = function(dialog)
                        local data = dialog.entryList:GetTargetData()
                        if data and data.callback then data.callback(dialog) end
                    end,
                },
            },
            noChoiceCallback = function() renameTarget = nil end,
        })
    end)
    renameReady = ok
    return ok
end

local function canRename()
    local e = current()
    return e and e.kind == "custom" and IsInGamepadPreferredMode() and type(ZO_Dialogs_ShowGamepadDialog) == "function"
end

local function rename()
    local e = current()
    if not canRename() then return end
    resetPrompts()
    if not registerRenameDialog() then
        state.message = "Renaming isn't available here."
        refresh()
        return
    end
    renameTarget, renameText = e.preset, e.preset.name
    local ok, err = pcall(ZO_Dialogs_ShowGamepadDialog, RENAME_DIALOG, { preset = e.preset })
    if not ok then
        state.message = "Couldn't open the rename box: " .. tostring(err)
        refresh()
    end
end

---------------------------------------------------------------------------
-- Window, scene, keybinds, up/down
---------------------------------------------------------------------------
local function createScene()
    window = WINDOW_MANAGER:CreateTopLevelWindow("ESOCCPPresetsWindow")
    window:SetAnchorFill(GuiRoot)
    window:SetHidden(true)

    scene = ZO_Scene:New(SCENE_NAME, SCENE_MANAGER)
    if IsInGamepadPreferredMode() then
        scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    else
        scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    end
    scene:AddFragment(ZO_SimpleSceneFragment:New(window))

    local function isCustom()
        local e = current()
        return e and e.kind == "custom"
    end
    keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        KEYBIND_STRIP:GetDefaultGamepadBackButtonDescriptor(),
        {
            name = function()
                local e = current()
                if e and e.kind == "save" then return "Save" end
                return state.confirm and "Confirm" or "Use preset"
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = primary,
        },
        { name = "Rename", keybind = "UI_SHORTCUT_SECONDARY", callback = rename, visible = canRename },
        {
            name = function() return state.deleteArm and "Confirm delete" or "Delete" end,
            keybind = "UI_SHORTCUT_TERTIARY",
            callback = deletePreset,
            visible = isCustom,
        },
        { name = "Up", keybind = "UI_SHORTCUT_LEFT_SHOULDER", callback = function() move(-1) end },
        { name = "Down", keybind = "UI_SHORTCUT_RIGHT_SHOULDER", callback = function() move(1) end },
    }

    -- No d-pad/stick scrolling: on console, DIRECTIONAL_INPUT reads IsKeyDown, which is private to
    -- the game's own code and raises a UI error from an add-on. LB / RB move through the list.

    scene:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWING then
            -- build the list first: adding the keybinds draws their names, which read the selection
            resetPrompts()
            buildEntries()
            if not state.index or not entries[state.index] or entries[state.index].kind == "header" then
                state.index = firstSelectable()
            end
            KEYBIND_STRIP:AddKeybindButtonGroup(keybinds)
            local ok, err = pcall(show)
            if not ok and ui then pcall(setStatus, "Something went wrong: " .. tostring(err), ORANGE) end
        elseif newState == SCENE_HIDDEN then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(keybinds)
        end
    end)
end

local function open()
    if not scene then createScene() end
    if SCENE_MANAGER:IsShowing(SCENE_NAME) then return end
    SCENE_MANAGER:Push(SCENE_NAME)
end

---------------------------------------------------------------------------
-- The "CP Presets" button on the game's Champion screen (left stick on gamepad)
---------------------------------------------------------------------------
local openButton = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    {
        name = "CP Presets",
        keybind = "UI_SHORTCUT_QUATERNARY",
        gamepadPreferredKeybind = "UI_SHORTCUT_LEFT_STICK",
        callback = function()
            local ok, err = pcall(open)
            if not ok then pcall(function() d("[CP Presets] " .. tostring(err)) end) end
        end,
    },
}

-- The Champion screen pushes its own keybind state while it shows. A group added without a state
-- index goes to the BOTTOM of that stack (a saved, hidden state), so the button must be added to the
-- Champion screen's own state: CHAMPION_PERKS.keybindStripId, which is the live (top) state.
local hooked, addedToState = {}, nil
local function championStripState()
    local id
    pcall(function() id = CHAMPION_PERKS and CHAMPION_PERKS.keybindStripId end)
    if not id then pcall(function() id = KEYBIND_STRIP:GetTopKeybindStateIndex() end) end
    return id
end

local function removeOpenButton()
    if addedToState == nil then return end
    local stateIndex = addedToState
    addedToState = nil
    pcall(function() KEYBIND_STRIP:RemoveKeybindButtonGroup(openButton, stateIndex) end)
end

local function hookChampionScene(sceneObj)
    if not sceneObj or hooked[sceneObj] then return end
    hooked[sceneObj] = true
    sceneObj:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_SHOWN then
            removeOpenButton()
            local stateIndex = championStripState()
            local ok = pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(openButton, stateIndex) end)
            if ok then addedToState = stateIndex or false end
        elseif newState == SCENE_HIDING then
            removeOpenButton()
        end
    end)
end

local function hookChampionScreens()
    local function get(name) local ok, s = pcall(function() return SCENE_MANAGER:GetScene(name) end) return ok and s or nil end
    hookChampionScene(GAMEPAD_CHAMPION_PERKS_SCENE or get("gamepad_championPerks_root"))
    hookChampionScene(CHAMPION_PERKS_SCENE or get("championPerks"))
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local function onLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    sv = ZO_SavedVars:NewAccountWide("ESOCCPPresets_SV", 1, nil, { custom = {} })
    sv.custom = sv.custom or {}
    hookChampionScreens()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CHAMPION_PURCHASE_RESULT, onPurchaseResult)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
        hookChampionScreens() -- in case the Champion screen was created late
        if not sv.toldWhereToFind then
            sv.toldWhereToFind = true
            pcall(function()
                ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, "CP Presets " .. VERSION .. ": open the Champion screen and click the left stick.")
            end)
        end
    end)
    pcall(function() SLASH_COMMANDS["/cppresets"] = open end) -- PC only; consoles have no chat commands
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onLoaded)

-- for the test harness
CP._test = { open = open, move = move, primary = primary, delete = deletePreset, rename = rename,
             commitRename = function(text) renameText = text commitRename() end, state = state,
             entries = function() return entries end, ui = function() return ui end,
             openButton = openButton, onPurchaseResult = onPurchaseResult }
