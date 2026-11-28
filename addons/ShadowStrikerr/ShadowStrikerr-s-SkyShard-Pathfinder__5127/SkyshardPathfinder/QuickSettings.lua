local addon = SkyshardPathfinder
local window, ownsCursor, refresh
local createWindow
local dragEvent = "SkyshardPathfinderQuickSettingsDrag"

local quickOptions = {
    { "Show ground trail", "Ground arrows" },
    { "Show colored trail dots on AUI minimap", "AUI minimap dots" },
    { "Ground trail destinations", "Trail destinations" },
    { "Maximum SkyShard trail distance", "Maximum distance" },
    { "Include collected SkyShards in trails", "Include collected SkyShards" },
    { "Show distance panel (expanded)", "Show distance panel (expanded)", 327 },
    { "Show collapsed SkyShard icon", "Show collapsed SkyShard icon", 363 },
}

local function stopDrag()
    window:SetHandler("OnUpdate", nil)
    EVENT_MANAGER:UnregisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP)
end

function addon.CloseQuickSettings()
    if not window or window:IsHidden() then return end
    stopDrag()
    window:SetHidden(true)
    if ownsCursor and HUD_UI_SCENE:IsShowing() and not SCENE_MANAGER:IsShowing("gameMenuInGame") then
        SetGameCameraUIMode(false)
    end
    ownsCursor = false
end

function addon.ToggleQuickSettings()
    if window and not window:IsHidden() then
        addon.CloseQuickSettings()
        return
    end
    if not createWindow then
        d("[SkyShard Pathfinder] Quick settings requires LibAddonMenu-2.0.")
        return
    end
    if not window then createWindow() end
    refresh()
    ownsCursor = not HUD_UI_SCENE:IsShowing()
    if ownsCursor then SetGameCameraUIMode(true) end
    window:SetHidden(false)
end

function addon.RegisterQuickSettings(options, openSettings, openKeybindings, position)
    createWindow = function()
        local manager = WINDOW_MANAGER
        window = manager:CreateTopLevelWindow("SkyshardPathfinderQuickSettings")
        window:SetDimensions(460, 411)
        if position.x and position.y then
            window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, position.x, position.y)
        else
            window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        end
        window:SetClampedToScreen(true)
        window:SetDrawTier(DT_HIGH)
        window:SetMouseEnabled(true)
        window:SetHidden(true)

        local backdrop = manager:CreateControl(nil, window, CT_BACKDROP)
        backdrop:SetAnchorFill(window)
        backdrop:SetCenterColor(.035, .055, .08, .98)
        backdrop:SetEdgeColor(.27, .45, .5, 1)
        backdrop:SetEdgeTexture("", 1, 1, 1)

        local function label(text, x, y, font)
            local control = manager:CreateControl(nil, window, CT_LABEL)
            control:SetAnchor(TOPLEFT, window, TOPLEFT, x, y)
            control:SetFont(font)
            control:SetText(text)
            return control
        end

        local function button(id, text, x, y, width, callback)
            local control = manager:CreateControlFromVirtual(
                "SkyshardPathfinderQuick" .. id, window, "ZO_DefaultButton")
            control:SetDimensions(width, 30)
            control:SetAnchor(TOPLEFT, window, TOPLEFT, x, y)
            control:SetText(text)
            control:SetHandler("OnClicked", callback)
            return control
        end

        local title = label("SkyShard Pathfinder", 20, 17, "ZoFontWinH3")
        title:SetColor(.52, .9, .93, 1)
        local header = manager:CreateControl(nil, window, CT_CONTROL)
        header:SetAnchor(TOPLEFT, window, TOPLEFT)
        header:SetDimensions(346, 48)
        header:SetMouseEnabled(true)
        header:SetHandler("OnMouseDown", function(_, button)
            if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            local mouseX, mouseY = GetUIMousePosition()
            local offsetX, offsetY = window:GetLeft() - mouseX, window:GetTop() - mouseY
            window:SetHandler("OnUpdate", function()
                local x, y = GetUIMousePosition()
                window:ClearAnchors()
                window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
                    x + offsetX - GuiRoot:GetLeft(), y + offsetY - GuiRoot:GetTop())
            end)
            EVENT_MANAGER:RegisterForEvent(dragEvent, EVENT_GLOBAL_MOUSE_UP, function(_, released)
                if released ~= MOUSE_BUTTON_INDEX_LEFT then return end
                position.x = window:GetLeft() - GuiRoot:GetLeft()
                position.y = window:GetTop() - GuiRoot:GetTop()
                stopDrag()
            end)
        end)
        button("Close", "Close", 352, 12, 88, addon.CloseQuickSettings)

        local refreshRows = {}
        local optionByName = {}
        for _, option in ipairs(options) do optionByName[option.name] = option end
        for index, entry in ipairs(quickOptions) do
            local option = optionByName[entry[1]]
            local y = entry[3] or (56 + (index - 1) * 36)
            label(entry[2], 20, y + 5, "ZoFontGame")
            local function choiceIndex()
                for i, value in ipairs(option.choicesValues) do
                    if value == option.getFunc() then return i end
                end
                return 1
            end
            local valueButton = button("Value" .. index, "", 275, y, 165, function()
                if option.type == "checkbox" then
                    option.setFunc(not option.getFunc())
                else
                    option.setFunc(option.choicesValues[choiceIndex() % #option.choices + 1])
                end
                refresh()
            end)
            refreshRows[index] = function()
                local value
                if option.type == "checkbox" then
                    value = option.getFunc() and "On" or "Off"
                else
                    value = option.choices[choiceIndex()]
                end
                valueButton:SetText(value)
            end
        end
        refresh = function()
            for _, update in ipairs(refreshRows) do update() end
        end

        button("ResetTarget", "Clear target", 20, 244, 420, function()
            addon.ClearSelectedShard()
        end)
        button("FullSettings", "Full settings", 20, 287, 200, function()
            addon.CloseQuickSettings()
            openSettings()
        end)
        button("Keybindings", "Keybindings", 240, 287, 200, function()
            addon.CloseQuickSettings()
            openKeybindings()
        end)
    end
end
