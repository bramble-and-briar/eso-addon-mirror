local addonName = "WardrobeShortcutHUD"
local directions = { "SE", "E", "NE", "N", "NW", "W", "SW", "S" }
local actionNames = { [2] = "First", [3] = "Second", [4] = "Previous", [5] = "Current", [6] = "Next" }
local offsets = { [4] = -1, [5] = 0, [6] = 1 }

local function GetPage(wardrobe)
    local selection = wardrobe.selection
    if not selection or not selection.zone or not wardrobe.setups then
        return nil
    end
    local zonePages = wardrobe.setups[selection.zone.tag]
    return zonePages and zonePages[selection.pageId]
end

local function GetDestination(action, currentIndex, count)
    if action == 2 or action == 3 then
        return action - 1
    end
    local index = currentIndex + offsets[action]
    if index > count then
        return 1
    elseif index < 1 then
        return count
    end
    return index
end

local function GetName(page, index)
    local preset = page and page[index]
    if preset and type(preset.name) == "string" and preset.name ~= "" then
        return preset.name
    end
    return "(no saved setup)"
end

local function BuildText(wardrobe, lastConfirmed)
    local settings = wardrobe.settings
    local page = GetPage(wardrobe)
    local lines = { "WARDROBE SHORTCUTS", "Last confirmed: " .. (lastConfirmed or "-") }
    if not settings or not settings.quickslotsEnabled or type(settings.quickslots) ~= "table" then
        lines[#lines + 1] = "Enable Wardrobe quickslot bindings"
        return table.concat(lines, "\n")
    end

    local count = 0
    for _ in pairs(page or {}) do
        count = count + 1
    end
    for slot, direction in ipairs(directions) do
        local action = settings.quickslots[slot]
        if actionNames[action] then
            local index = GetDestination(action, wardrobe.currentIndex or 0, count)
            local destination = index > 0 and GetName(page, index) or "(no saved setup)"
            lines[#lines + 1] = string.format("%s  %s: %s", direction, actionNames[action], destination)
        end
    end
    if #lines == 2 then
        lines[#lines + 1] = "Bind a shortcut in Wizard's Wardrobe"
    end
    return table.concat(lines, "\n")
end

local function GetWheelText(wardrobe, wheel)
    local settings = wardrobe.settings
    if not settings or not settings.quickslotsEnabled or type(settings.quickslots) ~= "table"
        or not wheel:IsInteracting() or wheel:GetHotbarCategory() ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        return nil
    end

    local entry = wheel.menu.selectedEntry
    local slot = entry and entry.data and entry.data.slotNum
    local action = slot and settings.quickslots[slot]
    if not actionNames[action] then
        return nil
    end

    local page = GetPage(wardrobe)
    local count = 0
    for _ in pairs(page or {}) do
        count = count + 1
    end
    local index = GetDestination(action, wardrobe.currentIndex or 0, count)
    return "Wardrobe - " .. actionNames[action] .. ": " .. GetName(page, index)
end

local function CreateWheelPreview(wardrobe)
    local wheel = UTILITY_WHEEL_GAMEPAD
    local actionLabel = wheel and wheel.menu and wheel.menu.actionLabel
    if not actionLabel then
        return
    end

    local overlay = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. "WheelPreview")
    overlay:SetDimensions(480, 110)
    overlay:SetAnchor(CENTER, actionLabel, CENTER, 0, 0)
    overlay:SetMouseEnabled(false)
    overlay:SetDrawTier(DT_HIGH)
    overlay:SetHidden(true)

    local background = WINDOW_MANAGER:CreateControl(addonName .. "WheelPreviewBackground", overlay, CT_BACKDROP)
    background:SetAnchorFill(overlay)
    background:SetDrawLayer(DL_BACKGROUND)
    background:SetCenterColor(0.035, 0.035, 0.045, 1)

    local label = WINDOW_MANAGER:CreateControl(addonName .. "WheelPreviewText", overlay, CT_LABEL)
    label:SetAnchorFill(overlay)
    label:SetFont("ZoFontGamepad27")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 0.92, 0.74, 1)

    local previousText
    EVENT_MANAGER:RegisterForUpdate(addonName .. "WheelPreview", 100, function()
        local text = GetWheelText(wardrobe, wheel)
        if text ~= previousText then
            label:SetText(text or "")
            overlay:SetHidden(text == nil)
            previousText = text
        end
    end)
end

local function CreateEditorWheel(wardrobe)
    local library = LibHarvensAddonSettings
    local menuName = wardrobe.consoleControl and wardrobe.consoleControl.menuName
    if not library or not menuName then
        return
    end

    local panel = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. "EditorWheel")
    panel:SetDimensions(440, 400)
    panel:SetAnchor(CENTER, GuiRoot, CENTER, 330, 0)
    panel:SetDrawTier(DT_HIGH)
    panel:SetHidden(true)

    local background = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
    background:SetAnchorFill(panel)
    background:SetCenterColor(0.04, 0.06, 0.08, 0.97)

    local function CreateLabel(parent, width, height)
        local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
        label:SetDimensions(width, height)
        label:SetFont("ZoFontGamepad22")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return label
    end

    local heading = CreateLabel(panel, 280, 56)
    heading:SetAnchor(CENTER, panel, CENTER)
    local tiles = {}
    for slot, direction in ipairs(directions) do
        local angle = (2 - slot) * math.pi / 4
        local tile = WINDOW_MANAGER:CreateControl(nil, panel, CT_BACKDROP)
        tile:SetDimensions(96, 52)
        tile:SetAnchor(CENTER, panel, CENTER, math.cos(angle) * 150, math.sin(angle) * 138)
        local label = CreateLabel(tile, 96, 52)
        label:SetAnchor(CENTER, tile, CENTER)
        tiles[slot] = { background = tile, label = label, direction = direction }
    end

    local slotPicker, actionPicker
    EVENT_MANAGER:RegisterForUpdate(addonName .. "EditorWheel", 100, function()
        local scene = library.scene
        local list = library.list
        local row = scene and scene:IsShowing() and list and list:GetSelectedData()
        if not row or (row.labelText ~= "Select Quickslot" and row.labelText ~= "Select Action") then
            panel:SetHidden(true)
            return
        end

        if not slotPicker or not actionPicker then
            slotPicker = nil
            for _, menu in ipairs(library.addons) do
                if menu.name == menuName then
                    for _, setting in ipairs(menu.settings) do
                        if setting.labelText == "Select Quickslot" then
                            slotPicker = setting
                        elseif setting.labelText == "Select Action" then
                            actionPicker = setting
                        end
                    end
                    break
                end
            end
        end
        if not slotPicker or (row ~= slotPicker and row ~= actionPicker) then
            panel:SetHidden(true)
            return
        end

        local item = slotPicker.getFunction()
        local selected = item and item.data
        local bindings = wardrobe.settings.quickslots
        heading:SetText(selected and ("Quickslot " .. selected .. "  " .. directions[selected]) or "Quickslot bindings")
        for slot, tile in ipairs(tiles) do
            local action = actionNames[bindings[slot]]
            tile.label:SetText(tile.direction .. "\n" .. (action or "Unbound"))
            if selected == slot then
                tile.background:SetCenterColor(0.24, 0.42, 0.42, 1)
            else
                tile.background:SetCenterColor(0.10, 0.14, 0.18, 1)
            end
        end
        panel:SetHidden(false)
    end)
end
local function Initialize()
    local wardrobe = WizardsWardrobe
    if not wardrobe or not wardrobe.callbackManager then
        return
    end

    CreateEditorWheel(wardrobe)
    CreateWheelPreview(wardrobe)

    local panel = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. "Panel")
    panel:SetDimensions(340, 300)
    panel:SetAnchor(RIGHT, GuiRoot, RIGHT, -42, 92)
    panel:SetHidden(true)

    local label = WINDOW_MANAGER:CreateControl(addonName .. "Text", panel, CT_LABEL)
    label:SetAnchor(TOPLEFT, panel, TOPLEFT, 10, 10)
    label:SetDimensions(320, 280)
    label:SetFont("ZoFontGamepad27")
    label:SetColor(1, 0.92, 0.74, 1)

    local lastConfirmed
    local previousText
    local function Refresh()
        local text = BuildText(wardrobe, lastConfirmed)
        if text ~= previousText then
            label:SetText(text)
            previousText = text
        end
    end

    wardrobe.callbackManager:RegisterCallback("WW_OnSetupSwapSuccess", function()
        local status = WizardsWardrobePanelBottomLabel
        lastConfirmed = status and status:GetText() or nil
        Refresh()
    end)

    local fragment = ZO_SimpleSceneFragment:New(panel)
    fragment:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            Refresh()
            EVENT_MANAGER:RegisterForUpdate(addonName, 500, Refresh)
        elseif newState == SCENE_FRAGMENT_HIDING then
            EVENT_MANAGER:UnregisterForUpdate(addonName)
        end
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, function(_, loadedName)
    if loadedName ~= addonName then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
    Initialize()
end)
