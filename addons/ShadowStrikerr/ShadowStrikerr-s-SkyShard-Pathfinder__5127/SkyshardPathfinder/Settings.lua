local addon = SkyshardPathfinder
local styleNames = { "Crystal Chevron", "Broad Arrowhead", "Faceted Shard", "Flat Chevron", "Double Chevron", "Needle Arrow", "ESO Default" }
local groundStyles = { "chevron", "arrowhead", "shard", "flat-chevron", "double-chevron", "needle-arrow", "eso" }
local mapStyleNames = { "ESO Default", "Crystal Chevron", "Broad Arrowhead", "Faceted Shard",
    "Ringed Diamond", "Beacon Crystal", "Delve Marker" }
local mapStyles = { "ESO", "Chevron", "Arrowhead", "Shard", "RingedDiamond", "BeaconCrystal", "DelveMarker" }
local groundDropdown = "SkyshardPathfinderGroundStyleDropdown"
local mapDropdown = "SkyshardPathfinderMapStyleDropdown"

local function createPreview(dropdown, offset)
    local preview = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_TEXTURE)
    preview:SetDimensions(36, 36)
    preview:SetAnchor(RIGHT, dropdown.combobox, LEFT, offset, 0)
    preview:SetDrawLayer(DL_OVERLAY)
    return preview
end

local function colorPicker(label, colors, key, onChange, disabled)
    return {
        type = "colorpicker",
        name = label,
        disabled = disabled,
        getFunc = function()
            local rgb = colors[key]
            return rgb[1], rgb[2], rgb[3], 1
        end,
        setFunc = function(r, g, b)
            colors[key] = { r, g, b }
            if onChange then onChange(key) end
        end,
    }
end

local function openKeybindings()
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() and KEYBINDINGS_SCENE_GAMEPAD then
        SCENE_MANAGER:Push("keybindings_gamepad")
        return
    end

    local controlsName = GetString(SI_GAME_MENU_CONTROLS)
    local keybindingsName = GetString(SI_GAME_MENU_KEYBINDINGS)
    local attempts = 0
    local function selectKeybindings()
        if not SCENE_MANAGER:IsShowing("gameMenuInGame") then return end
        local menu = ZO_GameMenu_InGame and ZO_GameMenu_InGame.gameMenu
        local tree = menu and menu.navigationTree
        local standard, addonPanel
        if tree and tree.ExecuteOnSubTree and tree.SelectNode then
            tree:ExecuteOnSubTree(nil, function(node)
                local data = node.data
                if data and data.categoryName == controlsName then
                    if data.name == keybindingsName then standard = node end
                    if libAddonKeybinds and data.name == "Addon Keybinds" then addonPanel = node end
                end
            end)
        end
        local target = addonPanel or standard
        if target then
            tree:SelectNode(target)
            local keybinder = VOTANS_KEYBINDER
            if keybinder and keybinder.searchBox and keybinder.FilterTextChanged then
                keybinder.searchBox:SetText("SkyShard Pathfinder")
                keybinder:FilterTextChanged()
            end
        elseif attempts < 9 then
            attempts = attempts + 1
            zo_callLater(selectKeybindings, 100)
        else
            d("[SkyShard Pathfinder] Open Controls > Keybindings and find SkyShard Pathfinder.")
        end
    end

    SCENE_MANAGER:Show("gameMenuInGame")
    zo_callLater(selectKeybindings, 100)
end

function addon.RegisterIconSettings(settings, selectStyle, updateTrail)
    local library = LibAddonMenu2
    if not library then return end

    local panelId = "SkyshardPathfinderOptions"
    local panel = library:RegisterAddonPanel(panelId, {
        type = "panel",
        name = "SkyShard Pathfinder",
        displayName = "SkyShard Pathfinder",
        author = "ShadowStrikerr",
        version = "0.4.24",
        website = "https://www.esoui.com/downloads/fileinfo.php?id=5127",
        registerForRefresh = true,
    })
    local groundPreview, confirmationPreview, uncollectedPreview, collectedPreview
    function addon.UpdateGroundIconPreview()
        if not groundPreview then return end
        local texture = addon.GetIconTexture(settings.icon)
        local near = settings.groundColors.near
        local collected = settings.groundColors.collected
        groundPreview:SetTexture(texture)
        groundPreview:SetColor(near[1], near[2], near[3], 1)
        confirmationPreview:SetTexture(texture)
        confirmationPreview:SetColor(collected[1], collected[2], collected[3], 1)
    end
    local function updateMapPreviews()
        if not uncollectedPreview then return end
        local texture, r, g, b = addon.GetMapPinAppearance(settings, false)
        uncollectedPreview:SetTexture(texture)
        uncollectedPreview:SetColor(r, g, b, 1)
        texture, r, g, b = addon.GetMapPinAppearance(settings, true)
        collectedPreview:SetTexture(texture)
        collectedPreview:SetColor(r, g, b, 1)
    end
    local function createPreviews(createdPanel)
        if createdPanel ~= panel then return end
        CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", createPreviews)
        local groundRow = _G[groundDropdown]
        groundPreview = createPreview(groundRow, -46)
        confirmationPreview = createPreview(groundRow, -6)
        addon.UpdateGroundIconPreview()
        local row = _G[mapDropdown]
        uncollectedPreview = createPreview(row, -46)
        collectedPreview = createPreview(row, -6)
        updateMapPreviews()
    end
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", createPreviews)

    local function mapAppearanceChanged(colorKey)
        updateMapPreviews()
        addon.RefreshMapPins(settings, colorKey)
    end

    local function usesNativeIcons()
        return settings.mapIcon == "ESO"
    end

    local function mapSlider(name, key, min, max, tooltip)
        return {
            type = "slider", name = name, min = min, max = max, step = 1, tooltip = tooltip,
            getFunc = function() return settings[key] end,
            setFunc = function(value)
                if settings[key] == value then return end
                settings[key] = value
                addon.RefreshMapPins(settings)
            end,
        }
    end

    local options = {
        {
            type = "button",
            name = "Quick settings",
            func = function() addon.ToggleQuickSettings() end,
        },
        {
            type = "button",
            name = "Keybindings",
            tooltip = "Open ESO's keybinding settings to assign Pathfinder shortcuts.",
            func = openKeybindings,
        },
        {
            type = "checkbox",
            name = "Show distance panel (expanded)",
            tooltip = "Show the distance and destination panel during gameplay.",
            default = true,
            getFunc = function() return settings.showDistancePanel ~= false end,
            setFunc = function(value) settings.showDistancePanel = value end,
        },
        {
            type = "checkbox",
            name = "Show collapsed SkyShard icon",
            tooltip = "Show a clickable SkyShard icon while guidance is paused. Use your chat command with panel to resume when the icon is hidden.",
            default = true,
            getFunc = function() return settings.showCollapsedIcon ~= false end,
            setFunc = function(value)
                settings.showCollapsedIcon = value
                addon.RefreshResumeIcon()
            end,
        },
        {
            type = "editbox",
            name = "Chat command (default /ssp)",
            reference = "SkyshardPathfinderSlashCommandEditBox",
            tooltip = "Enter your preferred command with or without a slash. Clear the box to restore /ssp.",
            getFunc = function() return settings.slashCommand end,
            setFunc = function(value)
                addon.SetSlashCommand(value)
                local control = SkyshardPathfinderSlashCommandEditBox
                if control and control.editbox then control.editbox:SetText(settings.slashCommand) end
            end,
        },
        {
            type = "checkbox",
            name = "Announce selected targets in chat",
            tooltip = "Print the destination and SkyShard hint when you select a target.",
            default = true,
            getFunc = function() return settings.announceTargets ~= false end,
            setFunc = function(value) settings.announceTargets = value end,
        },
        {
            type = "checkbox",
            name = "Show ground trail",
            tooltip = "Guide to the nearest uncollected SkyShard on your current map.",
            getFunc = function() return settings.autoTrail end,
            setFunc = function(value)
                if settings.autoTrail == value then return end
                settings.autoTrail = value
                updateTrail()
            end,
        },
        {
            type = "checkbox",
            name = "Keep arrows visible through terrain",
            tooltip = "Prevents rocks and slopes from hiding arrows. Turn off to let terrain cover arrows behind it.",
            getFunc = function() return settings.visibleThroughTerrain end,
            setFunc = function(value) settings.visibleThroughTerrain = value end,
        },
        {
            type = "checkbox",
            name = "Follow walked paths",
            tooltip = "Remember walks on your current map and connect them where they meet on the same level.",
            getFunc = function() return settings.followWalkedPaths end,
            setFunc = function(value)
                settings.followWalkedPaths = value
                updateTrail()
            end,
        },
        {
            type = "checkbox",
            name = "Allow direct arrows beyond walked paths",
            tooltip = "Allow arrows to point straight at a shard where a recorded walk is unavailable. A straight bearing may cross an obstacle.",
            getFunc = function() return settings.allowDirectFallback end,
            setFunc = function(value) settings.allowDirectFallback = value end,
            disabled = function() return not settings.followWalkedPaths end,
        },
        {
            type = "checkbox",
            name = "Show colored trail dots on AUI minimap",
            tooltip = "Shows Pathfinder trails on AUI's minimap when available. AUI is optional.",
            getFunc = function() return settings.minimapTrail end,
            setFunc = function(value)
                settings.minimapTrail = value
                if not value then addon.HideMinimapTrail() end
            end,
        },
        {
            type = "checkbox",
            name = "Directional arrows only (no trail dots)",
            tooltip = "Keep the ground arrows while hiding Pathfinder's trail dots, map pins, and distance panel. Turn this off to restore your previous pin settings.",
            getFunc = function() return settings.arrowsOnly end,
            setFunc = function(value)
                if settings.arrowsOnly == value then return end
                settings.arrowsOnly = value
                addon.UpdateMapPinVisibility(settings)
            end,
        },
        {
            type = "dropdown",
            name = "Ground trail destinations",
            tooltip = "Nearby bearings share a trail. Each destination has its own direct distance.",
            choices = { "All eligible", "Nearest only", "Nearest 3", "Nearest 5" },
            choicesValues = { 0, 1, 3, 5 },
            getFunc = function() return settings.trailLimit end,
            setFunc = function(value) settings.trailLimit = value end,
        },
        {
            type = "dropdown",
            name = "Maximum SkyShard trail distance",
            tooltip = "Filter ground arrows, minimap trail dots, and the distance panel by straight-line distance to the SkyShard.",
            choices = { "All", "Max 100m", "Max 500m" },
            choicesValues = { 0, 100, 500 },
            default = 0,
            getFunc = function() return settings.trailMaxDistance or 0 end,
            setFunc = function(value) settings.trailMaxDistance = value end,
        },
        {
            type = "checkbox",
            name = "Include collected SkyShards in trails",
            tooltip = "Turn on when leading a SkyShard run to guide players to shards you've already collected.",
            getFunc = function() return settings.includeCollectedInTrails end,
            setFunc = function(value)
                if settings.includeCollectedInTrails == value then return end
                settings.includeCollectedInTrails = value
                updateTrail()
            end,
        },
        {
            type = "dropdown",
            name = "Ground trail icon",
            reference = groundDropdown,
            tooltip = "Left previews the very-close color. Right previews the collection confirmation color.",
            choices = styleNames,
            choicesValues = groundStyles,
            getFunc = function() return settings.icon end,
            setFunc = selectStyle,
        },
        {
            type = "dropdown",
            name = "World-map pin style",
            reference = mapDropdown,
            tooltip = "The left preview is uncollected. The right preview is collected.",
            choices = mapStyleNames,
            choicesValues = mapStyles,
            getFunc = function() return settings.mapIcon end,
            setFunc = function(style)
                if settings.mapIcon == style then return end
                settings.mapIcon = style
                mapAppearanceChanged()
            end,
        },
        mapSlider("Map pin size", "pinSize", 20, 70, "Adjust the size of Pathfinder pins."),
        mapSlider("Map pin layer", "pinLayer", 10, 200, "Higher layers draw above more map symbols."),
        colorPicker("Uncollected map pin color", settings, "uncollectedColor", mapAppearanceChanged, usesNativeIcons),
        colorPicker("Collected map pin color", settings, "collectedColor", mapAppearanceChanged, usesNativeIcons),
        {
            type = "checkbox",
            name = "Show uncollected SkyShards on the map",
            getFunc = function() return settings.showUncollected end,
            setFunc = function(value)
                if settings.showUncollected == value then return end
                settings.showUncollected = value
                addon.UpdateMapPinVisibility(settings)
            end,
        },
        {
            type = "checkbox",
            name = "Show collected SkyShards on the map",
            getFunc = function() return settings.showCollected end,
            setFunc = function(value)
                if settings.showCollected == value then return end
                settings.showCollected = value
                addon.UpdateMapPinVisibility(settings)
            end,
        },
        { type = "header", name = "Ground trail colors" },
        colorPicker("Very close (0-100 m)", settings.groundColors, "near", addon.UpdateGroundIconPreview),
        colorPicker("Nearby (over 100-500 m)", settings.groundColors, "middle"),
        colorPicker("Distant (over 500 m)", settings.groundColors, "far"),
        colorPicker("Recently collected (brief flash)", settings.groundColors, "collected", addon.UpdateGroundIconPreview),
    }
    library:RegisterOptionControls(panelId, options)
    function addon.OpenSettings()
        library:OpenToPanel(panel)
    end
    addon.RegisterQuickSettings(options, addon.OpenSettings, openKeybindings, settings.quickSettingsPosition)
end
