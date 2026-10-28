--[[
    BlockPooky Menu System - LibAddonMenu Integration

    This module handles the in-game settings menu for BlockPooky using LibAddonMenu-2.0.
    It provides a comprehensive UI for configuring all addon features including:
    - Block warning settings and triggers
    - Custom cooldown bars configuration
    - UI customization options
    - Debug tools for ability/effect investigation

    The menu is accessible via the slash command: /blockpooky
--]]

--[[ basic initialization -------------------------------------------------------------------------------------------]]
BlockPooky = BlockPooky or {}
local BlockPooky = BlockPooky

-- LibAddonMenu integration for settings UI
local BlockPooky_LAM = LibAddonMenu2
-- Window Manager for UI control access
local BlockPooky_WM = GetWindowManager()
-- Currently selected cooldown bar in the dropdown menu
local BlockPooky_selectedCooldownBar
-- Array of available cooldown bar names for dropdown choices
local BlockPooky_CooldownBars = {}
-- Currently selected threat ability (its ID) in the ability text-label dropdown
local BlockPooky_selectedThreatAbilityId
-- Dropdown choices ("Name (id)") for threat abilities, kept in sync with THREAT_ABILITY_IDS
local BlockPooky_ThreatAbilityChoices = {}

--[[ ui menu - cooldown bar validation helpers ---------------------------------------------------------------------]]

---Validates if a cooldown bar is currently selected and valid
---@return boolean true if a valid cooldown bar is selected
function BlockPooky.ValidSelectedCooldownBar()
    return BlockPooky_selectedCooldownBar ~= nil and BlockPooky_selectedCooldownBar ~= "" and
        BlockPooky_selectedCooldownBar ~= '<none>'
end

---Gets the ability ID for the currently selected cooldown bar
---@return number|nil ability ID if valid, nil otherwise
function BlockPooky.ValidCooldownAbilityId()
    if BlockPooky.ValidSelectedCooldownBar() then
        local abilityId = BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].abilityId
        if abilityId ~= "" then
            return abilityId
        end
    end
    return nil
end

---Gets the name of the currently selected cooldown bar
---@return string cooldown bar name or '<none>' if invalid
function BlockPooky.ValidSelectedCooldownBarName()
    if BlockPooky.ValidSelectedCooldownBar() then
        return BlockPooky_selectedCooldownBar
    end
    return '<none>'
end

---Gets the cleaned ability name for the currently selected cooldown bar
---@return string ability name or empty string if invalid
function BlockPooky.ValidCooldownAbilityName()
    local abilityId = BlockPooky.ValidCooldownAbilityId()
    if abilityId ~= nil then
        return BlockPooky.CleanAbilityName(abilityId)
    end
    return ''
end

---Checks if the currently selected cooldown bar is set to show
---@return boolean true if the cooldown bar should be shown
function BlockPooky.ValidCooldownShow()
    if BlockPooky.ValidSelectedCooldownBar() then
        return BlockPooky.GetShowCooldownBar(BlockPooky_selectedCooldownBar)
    end
    return false
end

function BlockPooky.UpdateCooldownBarDropdown(name)
    BlockPooky_selectedCooldownBar = name
    local cooldownBarDropdown = BlockPooky_WM:GetControlByName('CooldownBarDropdown')
    if cooldownBarDropdown ~= nil then
        cooldownBarDropdown:UpdateChoices(BlockPooky_CooldownBars)
    end
end

--[[ ui menu - threat alert ability label helpers ----------------------------------------------------------------]]

---(Re)builds the "Name (id)" dropdown choices for threat abilities, in place.
---Reads from config.threatalert.abilities (the same source RebuildThreatAbilityList
---uses) so it is correct even when the menu is built before THREAT_ABILITY_IDS exists.
---@return table the shared dropdown choices list
function BlockPooky.GetThreatAbilityChoices()
    ZO_ClearTable(BlockPooky_ThreatAbilityChoices)
    local seen = {}
    for _, id in ipairs(BlockPooky.config.threatalert.abilities or {}) do
        if not seen[id] then
            seen[id] = true
            table.insert(BlockPooky_ThreatAbilityChoices, BlockPooky.CleanAbilityName(id) .. " (" .. id .. ")")
        end
    end
    if #BlockPooky_ThreatAbilityChoices == 0 then
        table.insert(BlockPooky_ThreatAbilityChoices, '<none>')
    end
    return BlockPooky_ThreatAbilityChoices
end

---Checks whether a valid threat ability is selected in the text-label dropdown
---@return boolean true if an ability is selected
function BlockPooky.ValidSelectedThreatAbility()
    return BlockPooky_selectedThreatAbilityId ~= nil and BlockPooky_selectedThreatAbilityId ~= ""
end

---Gets the ID of the currently selected threat ability for label assignment
---@return number|nil ability ID, nil when nothing is selected
function BlockPooky.ValidThreatLabelAbilityId()
    if BlockPooky.ValidSelectedThreatAbility() then
        return BlockPooky_selectedThreatAbilityId
    end
    return nil
end

---Gets the dropdown choice string of the currently selected threat ability
---@return string "Name (id)" or '<none>' when nothing is selected
function BlockPooky.ValidThreatLabelAbilityChoice()
    local id = BlockPooky.ValidThreatLabelAbilityId()
    if id then
        return BlockPooky.CleanAbilityName(id) .. " (" .. id .. ")"
    end
    return '<none>'
end

---Syncs the text-label dropdown after threat abilities are added or removed
---Keeps the preferred selection when it is still present, otherwise selects the first ability.
---@param preferredId number|nil ability ID to keep selected when still listed
function BlockPooky.RefreshThreatAbilityDropdown(preferredId)
    BlockPooky.GetThreatAbilityChoices()
    local keep = preferredId
    if keep == nil then keep = BlockPooky_selectedThreatAbilityId end
    if keep == nil and BlockPooky.THREAT_ABILITY_IDS and #BlockPooky.THREAT_ABILITY_IDS > 0 then
        keep = BlockPooky.THREAT_ABILITY_IDS[1]
    end
    local found = false
    if keep ~= nil and BlockPooky.THREAT_ABILITY_IDS then
        for _, id in ipairs(BlockPooky.THREAT_ABILITY_IDS) do
            if id == keep then
                found = true
                break
            end
        end
    end
    BlockPooky_selectedThreatAbilityId = found and keep or nil
    local dropdown = BlockPooky_WM:GetControlByName('ThreatAlertLabelAbilityDropdown')
    if dropdown ~= nil then
        dropdown:UpdateChoices(BlockPooky_ThreatAbilityChoices)
    end
end

---Builds the "Ability Text Labels" submenu controls.
---LibAddonMenu requires submenu `controls` to be a table (not a function), so this is
---called once at panel build time; live dropdown changes go through RefreshThreatAbilityDropdown.
---@return table LAM control list
function BlockPooky.GetThreatAlertAbilityLabelControls()
    return {
        {
            type = "description",
            title = "Ability Text Labels",
            text =
            "Show a center label when a threat ability is detected. Each ability can have its own custom text; leave the text empty to show the ability's name instead.",
        },
        {
            type = "checkbox",
            name = "Show Text on Overlay",
            tooltip =
            "Show a center label (ability name or your custom text) together with the overlay. Disable to keep the texture-only overlay.",
            default = true,
            getFunc = function() return BlockPooky.config.threatalert.showLabel ~= false end,
            setFunc = function(newValue) BlockPooky.config.threatalert.showLabel = newValue end,
        },
        {
            type = "dropdown",
            name = "Select Ability",
            tooltip = "Choose the threat ability to assign custom text to.",
            choices = BlockPooky.GetThreatAbilityChoices(),
            getFunc = function() return BlockPooky.ValidThreatLabelAbilityChoice() end,
            setFunc = function(value)
                if value ~= '<none>' and BlockPooky.THREAT_ABILITY_IDS then
                    for i, choice in ipairs(BlockPooky_ThreatAbilityChoices) do
                        if choice == value then
                            BlockPooky_selectedThreatAbilityId = BlockPooky.THREAT_ABILITY_IDS[i]
                            break
                        end
                    end
                else
                    BlockPooky_selectedThreatAbilityId = nil
                end
            end,
            reference = 'ThreatAlertLabelAbilityDropdown'
        },
        {
            type = "editbox",
            name = "Custom Text",
            tooltip =
            "Custom text shown in the center of the screen when this ability is detected. Leave empty to show the ability's name instead.",
            getFunc = function()
                local id = BlockPooky.ValidThreatLabelAbilityId()
                if id and BlockPooky.config.threatalert.labels then
                    return BlockPooky.config.threatalert.labels[id] or ""
                end
                return ""
            end,
            setFunc = function(value)
                local id = BlockPooky.ValidThreatLabelAbilityId()
                if id then
                    if not BlockPooky.config.threatalert.labels then
                        BlockPooky.config.threatalert.labels = {}
                    end
                    local text = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if text == "" then
                        BlockPooky.config.threatalert.labels[id] = nil
                    else
                        BlockPooky.config.threatalert.labels[id] = text
                    end
                end
            end,
            isMultiline = false,
        },
    }
end

--[[ ui menu - element position helpers ---------------------------------------------------------------------------]]

---Position a control at absolute screen coordinates (TOPLEFT-based, same format as saved positions)
---@param control table|nil
---@param left number|nil
---@param top number|nil
local function SetControlScreenPosition(control, left, top)
    if control == nil then
        return
    end
    if control:GetAnchor() ~= nil then
        control:ClearAnchors()
    end
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left or 0, top or 0)
end

---Append an X/Y slider pair to position a UI element via the menu
---@param controls table LAM control list to append to
---@param label string element display name shown on the sliders
---@param getPos function returns position table with .left/.top (may be nil)
---@param setPos function stores the new position (left, top)
---@param getControl function|nil returns the UI control to move live (may be nil)
local function AddPositionSliders(controls, label, getPos, setPos, getControl)
    local screenW, screenH = GuiRoot:GetDimensions()
    screenW = math.max(screenW or 0, 1)
    screenH = math.max(screenH or 0, 1)

    local function Current()
        local pos = getPos()
        if pos == nil or pos.left == nil or pos.top == nil then
            -- Fall back to the control's actual position (e.g. not yet saved)
            local control = getControl and getControl()
            if control then
                return control:GetLeft() or 0, control:GetTop() or 0
            end
            return 0, 0
        end
        return pos.left, pos.top
    end

    -- Clamp to the slider range: elements can be off-screen (position > screen size)
    local function ClampX(x) return math.max(0, math.min(x or 0, screenW)) end
    local function ClampY(y) return math.max(0, math.min(y or 0, screenH)) end

    table.insert(controls, {
        type    = "slider",
        name    = label .. " - X Position",
        tooltip = "Horizontal position in pixels from the left screen edge.",
        min     = 0,
        max     = screenW,
        step    = 1,
        getFunc = function()
            local l, t = Current(); return ClampX(l)
        end,
        setFunc = function(value)
            local l, t = Current()
            setPos(value, t)
            SetControlScreenPosition(getControl and getControl(), value, t)
        end,
    })
    table.insert(controls, {
        type    = "slider",
        name    = label .. " - Y Position",
        tooltip = "Vertical position in pixels from the top screen edge.",
        min     = 0,
        max     = screenH,
        step    = 1,
        getFunc = function()
            local l, t = Current(); return ClampY(t)
        end,
        setFunc = function(value)
            local l, t = Current()
            setPos(l, value)
            SetControlScreenPosition(getControl and getControl(), l, value)
        end,
    })
end

function BlockPooky.UpdateCooldownAbilityName()
    local cooldownAbilityName = BlockPooky_WM:GetControlByName('CooldownAbilityName')
    if cooldownAbilityName ~= nil and cooldownAbilityName.data ~= nil then
        cooldownAbilityName.data.text = BlockPooky.ValidCooldownAbilityName()
        cooldownAbilityName:UpdateValue()
    end
end

function BlockPooky.GetCooldownBarControls()
    for name, config in pairs(BlockPooky.config.cooldownbar) do
        table.insert(BlockPooky_CooldownBars, name)
        if not BlockPooky_selectedCooldownBar then
            BlockPooky_selectedCooldownBar = name
        end
    end
    local controls = {
        {
            type = "editbox",
            name = "Add Custom Cooldown Bar",
            tooltip = "Type a name and press Enter to add a new cooldown bar.",
            getFunc = function() return "" end,
            setFunc = function(name)
                if name ~= "" and name ~= '<none>' then
                    -- d("ADD Bar" .. tostring(name))
                    local config = BlockPooky.AddCooldownBar(name)
                    BlockPooky.InitCooldownBarUI(name)
                    table.insert(BlockPooky_CooldownBars, name)
                    BlockPooky.UpdateCooldownBarDropdown(name)
                end
            end,
            isMultiline = false
        },
        {
            type = "dropdown",
            name = "Select Cooldown Bar",
            choices = BlockPooky_CooldownBars,
            getFunc = function() return BlockPooky.ValidSelectedCooldownBarName() end,
            setFunc = function(value)
                if value ~= '<none>' and value ~= "" then
                    BlockPooky_selectedCooldownBar = value
                    BlockPooky.UpdateCooldownAbilityName()
                end
            end,
            reference = 'CooldownBarDropdown'
        },
        {
            type = "description",
            title = "Cooldown Ability",
            text = BlockPooky.ValidCooldownAbilityName(),
            reference = 'CooldownAbilityName'
        },
        {
            type    = "checkbox",
            name    = "Show Cooldown Bar",
            default = false,
            getFunc = function() return BlockPooky.ValidCooldownShow() end,
            setFunc = function(newValue)
                if BlockPooky.ValidSelectedCooldownBar() and newValue ~= BlockPooky.GetShowCooldownBar(BlockPooky_selectedCooldownBar) then
                    if newValue then
                        BlockPooky.InitCooldownBarUI(BlockPooky_selectedCooldownBar)
                    end
                    BlockPooky.UpdateCooldownBarUsage(BlockPooky_selectedCooldownBar, newValue)
                end
            end
        },
        {
            type = "dropdown",
            name = "Cooldown Bar Type",
            choices = { "ability", "effect" },
            getFunc = function()
                if BlockPooky.ValidSelectedCooldownBar() then
                    local type = BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].type
                    if type == nil then type = "ability" end
                    return type
                else
                    return "ability"
                end
            end,
            setFunc = function(newValue)
                if BlockPooky.ValidSelectedCooldownBar() and newValue ~= BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].type then
                    BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].type = newValue
                end
            end
        },
        {
            type = "editbox",
            name = "Ability ID",
            getFunc = function()
                if BlockPooky.ValidSelectedCooldownBar() then
                    return BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].abilityId
                end
                return '<none>'
            end,
            setFunc = function(value)
                if BlockPooky.ValidSelectedCooldownBar() and value ~= '<none>' then
                    BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].abilityId = value
                    BlockPooky.UpdateCooldownAbilityName()
                end
            end
        },
        {
            type = "colorpicker",
            name = "Cooldown Bar Color",
            tooltip = "Set the color for this cooldown bar.",
            getFunc = function()
                if BlockPooky.ValidSelectedCooldownBar() then
                    if BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].color ~= nil then
                        return unpack(BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].color)
                    end
                end
                return 1, 0, 1, 1
            end,
            setFunc = function(r, g, b, a)
                if BlockPooky.ValidSelectedCooldownBar() then
                    BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].color = { r, g, b, a }
                    BlockPooky.SetCooldownBarColour(BlockPooky_selectedCooldownBar)
                end
            end
        },
        {
            type = "slider",
            name = "Cooldown Duration",
            tooltip = "Duration of the cooldown in seconds.",
            min = 0,
            max = 50,
            step = 0.5,
            getFunc = function()
                if BlockPooky.ValidSelectedCooldownBar() then
                    return BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].cooldown
                end
                return 0
            end,
            setFunc = function(value)
                if BlockPooky.ValidSelectedCooldownBar() and value ~= '<none>' then
                    BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar].cooldown = value
                end
            end,
            default = 1000,
            warning = "ignored when based on an effect"
        },
        {
            type = "button",
            name = "Remove Cooldown Bar",
            tooltip = "Delete this cooldown bar permanently.",
            func = function()
                if BlockPooky.ValidSelectedCooldownBar() then
                    -- d("remove bar: " .. tostring(BlockPooky_selectedCooldownBar))
                    BlockPooky.RemoveCooldownBar(BlockPooky_selectedCooldownBar)
                    for i, choice in ipairs(BlockPooky_CooldownBars) do
                        if choice == BlockPooky_selectedCooldownBar then
                            table.remove(BlockPooky_CooldownBars, i)
                            break
                        end
                    end
                    BlockPooky.UpdateCooldownBarDropdown(BlockPooky_CooldownBars[1])
                end
            end,
            warning = "This action cannot be undone!",
        }
    }

    -- Position sliders for the currently selected cooldown bar
    AddPositionSliders(controls,
        "Selected Bar Position",
        function()
            if BlockPooky.ValidSelectedCooldownBar() then
                return BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar]
            end
            return nil
        end,
        function(left, top)
            if BlockPooky.ValidSelectedCooldownBar() then
                local cfg = BlockPooky.config.cooldownbar[BlockPooky_selectedCooldownBar]
                cfg.left = left
                cfg.top = top
            end
        end,
        function()
            if BlockPooky.ValidSelectedCooldownBar() and BlockPooky.cooldownbar and BlockPooky.cooldownbar[BlockPooky_selectedCooldownBar] then
                return BlockPooky.cooldownbar[BlockPooky_selectedCooldownBar].bar
            end
            return nil
        end)

    return controls
end

function BlockPooky.GetTriggerAbilityControls()
    local controls = {}
    for idx = #BlockPooky.predefinedTriggerAbilities, 1, -1 do
        local id = BlockPooky.predefinedTriggerAbilities[idx]
        local name = BlockPooky.CleanAbilityName(id)
        local checkbox = {
            type = "checkbox",
            name = name,
            getFunc = function() return BlockPooky.config.triggerAbilities[name] end,
            setFunc = function(value)
                BlockPooky.config.triggerAbilities[name] = value
                BlockPooky.RebuildTriggerAbilities()
            end,
            default = true
        }
        table.insert(controls, checkbox)
    end
    return controls
end

---Build the menu controls for positioning all UI elements via sliders
---This is an alternative to dragging: useful when an element has moved off-screen
---(e.g. after a resolution change).
---@return table LAM control list
function BlockPooky.GetElementPositionControls()
    local controls = {
        {
            type = "description",
            title = "Element Positions",
            text =
            "Position values are in pixels from the top-left screen corner. Use these sliders as an alternative to dragging - especially useful when an element has moved off-screen.",
        },
    }

    AddPositionSliders(controls, "Block Pooky",
        function() return BlockPooky.config end,
        function(left, top)
            BlockPooky.config.left = left; BlockPooky.config.top = top
        end,
        function() return BlockPookyIndicator end)

    AddPositionSliders(controls, "Pooky Blocking",
        function() return BlockPooky.config.blocking end,
        function(left, top)
            BlockPooky.config.blocking.left = left; BlockPooky.config.blocking.top = top
        end,
        function() return BlockingPookyIndicator end)

    AddPositionSliders(controls, "Vigor Hint",
        function() return BlockPooky.config.vigorUI end,
        function(left, top)
            BlockPooky.config.vigorUI.left = left; BlockPooky.config.vigorUI.top = top
        end,
        function() return VigorIndicator end)

    AddPositionSliders(controls, "CC Immunity Bar",
        function() return BlockPooky.config.ccBarPosition end,
        function(left, top)
            if BlockPooky.config.ccBarPosition == nil then BlockPooky.config.ccBarPosition = {} end
            BlockPooky.config.ccBarPosition.left = left
            BlockPooky.config.ccBarPosition.top = top
        end,
        function() return BlockPooky.ccBar end)

    AddPositionSliders(controls, "Active CC Bar",
        function() return BlockPooky.config.ccDebuffPosition end,
        function(left, top)
            if BlockPooky.config.ccDebuffPosition == nil then BlockPooky.config.ccDebuffPosition = {} end
            BlockPooky.config.ccDebuffPosition.left = left
            BlockPooky.config.ccDebuffPosition.top = top
        end,
        function() return BlockPooky.ccDebuffBar end)

    AddPositionSliders(controls, "Negate Warning",
        function() return BlockPooky.config.negate end,
        function(left, top)
            if BlockPooky.config.negate == nil then BlockPooky.config.negate = {} end
            BlockPooky.config.negate.left = left
            BlockPooky.config.negate.top = top
        end,
        function() return BlockPooky.negateWarning end)

    AddPositionSliders(controls, "HoT Counter",
        function() return BlockPooky.config.hotBarPosition end,
        function(left, top)
            if BlockPooky.config.hotBarPosition == nil then BlockPooky.config.hotBarPosition = {} end
            BlockPooky.config.hotBarPosition.left = left
            BlockPooky.config.hotBarPosition.top = top
        end,
        function() return BlockPooky.hotBar end)

    return controls
end

---Build the color pickers for the Active CC Bar (one per CC type)
---@return table LAM control list
function BlockPooky.GetCCDebuffColorControls()
    local controls = {}
    for _, typeKey in ipairs(BlockPooky.ccDebuffOrder) do
        local info = BlockPooky.ccDebuffInfo[typeKey]
        table.insert(controls, {
            type = "colorpicker",
            name = info.text .. " Color",
            tooltip = "Set the color for the " .. info.text .. " display on the Active CC Bar.",
            getFunc = function()
                if BlockPooky.config.ccDebuffColors and BlockPooky.config.ccDebuffColors[typeKey] then
                    return unpack(BlockPooky.config.ccDebuffColors[typeKey])
                end
                return unpack(info.color)
            end,
            setFunc = function(r, g, b, a)
                if not BlockPooky.config.ccDebuffColors then BlockPooky.config.ccDebuffColors = {} end
                BlockPooky.config.ccDebuffColors[typeKey] = { r, g, b, a }
                if BlockPooky.GetActiveCCDebuffType() == typeKey then
                    BlockPooky.SetCCDebuffBarColor(typeKey)
                end
            end
        })
    end
    return controls
end

---intialize the addon settings menue
function BlockPooky.InitAddonMenu()
    local function AddToNumberList(value)
        local num = tonumber(value)
        if num then
            table.insert(BlockPooky.config.customAbilityIds, num)
            table.sort(BlockPooky.config.customAbilityIds)
            BlockPooky.RebuildTriggerAbilities()
        else
            d("Invalid input. Please enter a valid number.")
        end
    end
    local function GenerateNumberListText()
        if #BlockPooky.config.customAbilityIds == 0 then
            return "No values added yet."
        end
        local texts = {}
        for _, abilityId in ipairs(BlockPooky.config.customAbilityIds) do
            local abilityName = BlockPooky.CleanAbilityName(abilityId)
            table.insert(texts, abilityName .. "(" .. abilityId .. ")")
        end
        return table.concat(texts, ", ")
    end

    local menuOptions = {
        type                = "panel",
        name                = BlockPooky.name,
        displayName         = BlockPooky.name,
        author              = BlockPooky.author,
        version             = tostring(BlockPooky.version),
        slashCommand        = "/blockpooky",
        registerForRefresh  = true,
        registerForDefaults = true,
    }

    local dataTable = {
        {
            type = "description",
            title = "Meridias Vanguard Block Pooky Addon",
            text = "Information about the BlockPooky addon.",
            tooltip = "Information about the BlockPooky addon.",
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Block Warning",
            text = "Settings for block warning notifications.",
            tooltip = "Settings for block warning notifications.",
        },
        {
            type    = "checkbox",
            name    = "Show Central Screen Message",
            tooltip = "Display a message in the center of the screen.",
            default = false,
            getFunc = function() return BlockPooky.config.useCSA end,
            setFunc = function(newValue) BlockPooky.config.useCSA = newValue end,
        },
        {
            type    = "checkbox",
            name    = "Play Sound",
            default = true,
            getFunc = function() return BlockPooky.config.playSound end,
            setFunc = function(newValue) BlockPooky.config.playSound = newValue end,
        },
        {
            type    = "checkbox",
            name    = "Show UI Frame",
            default = true,
            getFunc = function() return BlockPooky.config.useFrame end,
            setFunc = function(newValue) BlockPooky.config.useFrame = newValue end,
        },
        {
            type    = "checkbox",
            name    = "Show Game Chat Warning",
            tooltip = "Show warning messages in the game chat.",
            default = true,
            getFunc = function() return BlockPooky.config.chatWarn end,
            setFunc = function(newValue) BlockPooky.config.chatWarn = newValue end,
        },
        {
            type    = "checkbox",
            name    = "Send Pull Warning to Group",
            tooltip = "Send a warning to your group when you are pulled. This feature uses LibGroupBroadcast.",
            default = true,
            getFunc = function() return BlockPooky.config.groupMessaging end,
            setFunc = function(newValue)
                BlockPooky.config.groupMessaging = newValue
                if newValue then
                    BlockPooky.InitGroupMessaging()
                else
                    BlockPooky.StopGroupMessaging()
                end
            end,
        },
        {
            type = "description",
            title = "Note",
            text =
            "Toggling this off/on stops/starts sending and showing group warnings immediately, but the LibGroupBroadcast registration is only fully removed after a UI reload (/reloadui).",
        },
        {
            type = "button",
            name = "Reload UI to Fully Apply",
            tooltip =
            "Runs /reloadui so the group messaging registration is fully removed (when disabled) or freshly registered (when enabled).",
            func = function() ReloadUI("ingame") end,
            warning = "This reloads the UI and closes your current menu.",
        },
        {
            type    = "checkbox",
            name    = "Send Pull Warning Only for ROA/DC",
            tooltip = "Only send group messages for Rush of Agony or Dark Convergence pulls.",
            default = true,
            getFunc = function() return BlockPooky.config.msgPullAbilitiesOnly end,
            setFunc = function(newValue) BlockPooky.config.msgPullAbilitiesOnly = newValue end,
        },
        {
            type = "submenu",
            name = "Notification Durations",
            tooltip = "Customize how long notifications are displayed.",
            controls = {
                {
                    type = "slider",
                    name = "UI Frame Message Duration",
                    tooltip = "How long the UI frame message is displayed (ms).",
                    min = 1000,
                    max = 9000,
                    step = 10,
                    getFunc = function() return BlockPooky.config.cooldown end,
                    setFunc = function(value) BlockPooky.config.cooldown = value end,
                    default = 5000,
                },
                {
                    type = "slider",
                    name = "Central Screen Message Duration",
                    tooltip = "How long the center screen message is displayed (ms).",
                    min = 1000,
                    max = 9000,
                    step = 10,
                    getFunc = function() return BlockPooky.config.msgLifeSpan end,
                    setFunc = function(value) BlockPooky.config.msgLifeSpan = value end,
                    default = 1000,
                }
            }
        },
        {
            type = "submenu",
            name = "Select Trigger Abilities",
            tooltip =
            "Choose which abilities will trigger block warnings. Pull effects (Dark Convergence, Rush of Agony) fire when the effect lands on you; gap closers (Critical Rush, Stampede, ...) fire when they hit you.",
            controls = BlockPooky.GetTriggerAbilityControls()
        },
        {
            type = "submenu",
            name = "Custom Trigger Abilities",
            tooltip =
            "Add custom ability IDs. Effects are matched by ID and name; damage abilities (charges) are matched by ID when they hit you. Changes apply immediately, no reload needed.",
            controls = {
                {
                    type = "editbox",
                    name = "Add Custom Ability ID",
                    tooltip =
                    "Type an ability ID and press Enter to add. Damage abilities must be added with the ID of the hit that lands on you (use Incoming Damage Investigation to find it).",
                    getFunc = function() return "" end,
                    setFunc = function(value) AddToNumberList(value) end,
                    isMultiline = false,
                },
                {
                    type = "description",
                    title = "Current List",
                    text = function()
                        return GenerateNumberListText()
                    end
                },
                {
                    type = "button",
                    name = "Clear Ability ID List",
                    tooltip = "Remove all ability IDs from the list.",
                    func = function()
                        BlockPooky.config.customAbilityIds = {}
                        BlockPooky.RebuildTriggerAbilities()
                    end,
                    warning = "This action cannot be undone!",
                }
            }
        },
        {
            type = "button",
            name = "Reload Group Members",
            tooltip = "Reload the list of current group members.",
            func = function() BlockPooky.LoadGroupMembers() end,
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Hints",
            text = "Settings for hint notifications.",
            tooltip = "Settings for hint notifications.",
        },
        {
            type    = "checkbox",
            name    = "Show DC Ready Hint",
            default = false,
            tooltip = "Show a CSA message when Dark Convergence is ready.",
            getFunc = function() return BlockPooky.config.dcHint end,
            setFunc = function(newValue)
                BlockPooky.config.dcHint = newValue
                BlockPooky.HintsEventRegisterUpdate()
            end,
        },
        {
            type    = "checkbox",
            name    = "Show ROA Ready Hint",
            tooltip = "Show a CSA message when Rush of Agony is ready.",
            default = false,
            getFunc = function() return BlockPooky.config.roaHint end,
            setFunc = function(newValue)
                BlockPooky.config.roaHint = newValue
                BlockPooky.HintsEventRegisterUpdate()
            end,
        },
        {
            type    = "checkbox",
            name    = "Show Blocking Hint",
            tooltip = "Show a UI frame message when you are blocking.",
            default = true,
            getFunc = function() return BlockPooky.config.blocking.show end,
            setFunc = function(newValue)
                BlockPooky.config.blocking.show = newValue
                BlockPooky.SetUseBlocking()
            end,
        },
        {
            type    = "checkbox",
            name    = "Show Vigor Recast Hint",
            tooltip = "Show a Vigor hint after 8 seconds and a blinking hint after 16 seconds if not recast.",
            default = false,
            getFunc = function() return BlockPooky.config.vigorHint end,
            setFunc = function(newValue)
                BlockPooky.config.vigorHint = newValue
                BlockPooky.HintsEventRegisterUpdate()
            end
        },
        {
            type    = "checkbox",
            name    = "Show Negate Warning",
            tooltip = "Warn when standing in an enemy Negate Magic field.",
            default = false,
            getFunc = function() return BlockPooky.config.negate.show end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.negate.show then
                    BlockPooky.config.negate.show = newValue
                    BlockPooky.NegateEventRegisterUpdate()
                end
            end
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Bars",
            text = "Settings for bar indicators.",
            tooltip = "Settings for bar indicators.",
        },
        {
            type = "checkbox",
            name = "Show Active CC Bar",
            tooltip =
            "Display a bar showing the highest-priority crowd control currently affecting you (Stun > Fear > Disorient > Silence > Stagger).",
            default = true,
            getFunc = function() return BlockPooky.config.showCCDebuff end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.showCCDebuff then
                    BlockPooky.config.showCCDebuff = newValue
                    BlockPooky.CCDebuffEventRegisterUpdate()
                    if not newValue then
                        BlockPooky.HideCCDebuffBar()
                    end
                end
            end,
        },
        {
            type = "checkbox",
            name = "Show Active CC Bar CSA",
            tooltip =
            "Display a center screen message (e.g. \"STUNNED!\") when a hard CC (stun/fear/disorient) lands on you, so you notice it even if you miss the bar.",
            default = true,
            getFunc = function() return BlockPooky.config.ccDebuffCSA end,
            setFunc = function(newValue)
                BlockPooky.config.ccDebuffCSA = newValue
            end,
        },
        {
            type = "submenu",
            name = "Active CC Bar Colors",
            tooltip = "Set the color for each CC type shown on the Active CC Bar.",
            controls = BlockPooky.GetCCDebuffColorControls(),
        },
        {
            type    = "checkbox",
            name    = "Show CC Immunity Bar",
            tooltip = "Display a bar when you have CC immunity.",
            default = false,
            getFunc = function() return BlockPooky.config.CCImmunityHint end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.CCImmunityHint then
                    BlockPooky.config.CCImmunityHint = newValue
                    BlockPooky.CCEventRegisterUpdate()
                end
            end,
        },
        {
            type    = "checkbox",
            name    = "Show HoT Counter",
            tooltip =
            "Display counter for active Healing-over-Time effects (Update 49 cap: 8). Counted live from the game's buff list, so all HoT sources are covered automatically.",
            default = false,
            getFunc = function() return BlockPooky.config.showHoTCounter end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.showHoTCounter then
                    BlockPooky.config.showHoTCounter = newValue
                    BlockPooky.HoTEventRegisterUpdate()
                end
            end,
        },
        {
            type = "submenu",
            name = "Custom Cooldown Bars",
            tooltip = "Track custom cooldowns for abilities and effects.",
            controls = BlockPooky.GetCooldownBarControls(),
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Threat Alert",
            text = "Settings for full-screen threat warning overlay.",
            tooltip = "Settings for full-screen threat warning overlay.",
        },
        {
            type    = "checkbox",
            name    = "Enable Threat Alert",
            tooltip = "Show a full-screen overlay when dangerous threat abilities are cast.",
            default = false,
            getFunc = function() return BlockPooky.config.threatalert.show end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.threatalert.show then
                    BlockPooky.config.threatalert.show = newValue
                    if newValue then
                        BlockPooky.RegisterThreatAlert()
                    else
                        BlockPooky.UnRegisterThreatAlert()
                    end
                end
            end,
        },
        {
            type    = "checkbox",
            name    = "PvP Only",
            tooltip = "Only show overlay during PvP combat.",
            default = true,
            getFunc = function() return BlockPooky.config.threatalert.pvpOnly end,
            setFunc = function(newValue) BlockPooky.config.threatalert.pvpOnly = newValue end,
        },
        {
            type = "dropdown",
            name = "Overlay Texture",
            tooltip = "Choose the texture/color for the overlay. Requires addon reload (/reloadui) to apply.",
            choices = { "reddot.dds", "explosion.dds", "gold.dds", "Indigo.dds", "lemon.dds", "red.dds" },
            getFunc = function() return BlockPooky.config.threatalert.texture or "reddot.dds" end,
            setFunc = function(value)
                BlockPooky.config.threatalert.texture = value
                d("Texture changed to: " .. value .. " (will apply on next addon reload)")
            end,
            warning = "Reload the addon with /reloadui to apply texture changes"
        },
        {
            type = "slider",
            name = "Overlay Opacity",
            tooltip = "Adjust the visibility of the overlay (0.1 = subtle, 0.5 = very visible).",
            min = 0.1,
            max = 0.8,
            step = 0.05,
            getFunc = function() return BlockPooky.config.threatalert.alpha or 0.3 end,
            setFunc = function(value)
                BlockPooky.config.threatalert.alpha = value
                BlockPooky.UpdateThreatAlertAlpha()
            end,
            default = 0.3,
        },
        {
            type = "submenu",
            name = "Threat Alert Abilities",
            tooltip = "Configure which abilities trigger the overlay.",
            controls = {
                {
                    type = "description",
                    title = "Threat Abilities",
                    text = "Add or remove abilities that trigger the threat alert warning.",
                },
                {
                    type = "editbox",
                    name = "Add Ability ID",
                    tooltip = "Enter an ability ID and press Enter to add it.",
                    getFunc = function() return "" end,
                    setFunc = function(value)
                        local id = tonumber(value)
                        if id and id > 0 then
                            BlockPooky.AddThreatAbility(id)
                            BlockPooky.RefreshThreatAbilityDropdown(id)
                            d("Added ability ID: " .. id)
                        else
                            d("Invalid ability ID. Please enter a number.")
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "slider",
                    name = "Overlay Duration (seconds)",
                    tooltip = "How long the overlay is displayed when triggered.",
                    min = 1,
                    max = 30,
                    step = 0.5,
                    getFunc = function() return (BlockPooky.config.threatalert.duration or 8000) / 1000 end,
                    setFunc = function(value)
                        BlockPooky.config.threatalert.duration = value * 1000
                    end,
                    default = 8,
                },
                {
                    type = "slider",
                    name = "Overlay Cooldown (seconds)",
                    tooltip = "Minimum time between overlay triggers to prevent spam.",
                    min = 0.5,
                    max = 10,
                    step = 0.5,
                    getFunc = function() return (BlockPooky.config.threatalert.cooldown or 5000) / 1000 end,
                    setFunc = function(value)
                        BlockPooky.config.threatalert.cooldown = value * 1000
                    end,
                    default = 5,
                },
                {
                    type = "description",
                    title = "Current Threat Abilities:",
                    text = function()
                        -- Ensure threat abilities are initialized
                        if not BlockPooky.THREAT_ABILITY_IDS then
                            return "Threat alerts not initialized yet."
                        end
                        if #BlockPooky.THREAT_ABILITY_IDS == 0 then
                            return "No abilities configured."
                        end
                        local duration = (BlockPooky.config.threatalert.duration or 8000) / 1000
                        local texts = { "Duration: " .. duration .. "s\n" }
                        for _, id in ipairs(BlockPooky.THREAT_ABILITY_IDS) do
                            local name = BlockPooky.CleanAbilityName(id)
                            table.insert(texts, name .. " (" .. id .. ")")
                        end
                        return table.concat(texts, "\n")
                    end
                },
                {
                    type = "button",
                    name = "Remove Last Ability",
                    tooltip = "Remove the most recently added ability (including defaults).",
                    func = function()
                        if BlockPooky.config.threatalert.abilities and #BlockPooky.config.threatalert.abilities > 0 then
                            table.remove(BlockPooky.config.threatalert.abilities)
                            BlockPooky.RebuildThreatAbilityList()
                            BlockPooky.RefreshThreatAbilityDropdown(nil)
                            d("Ability removed.")
                        else
                            d("No abilities to remove.")
                        end
                    end,
                },
                {
                    type = "button",
                    name = "Clear All Abilities",
                    tooltip = "Remove ALL threat abilities (default and custom).",
                    func = function()
                        BlockPooky.config.threatalert.abilities = {}
                        BlockPooky.RebuildThreatAbilityList()
                        BlockPooky.RefreshThreatAbilityDropdown(nil)
                        d("All abilities cleared.")
                    end,
                    warning = "This will remove ALL abilities including Dark Convergence and Rush of Agony!",
                }
            }
        },
        {
            type = "submenu",
            name = "Ability Text Labels",
            tooltip = "Assign custom text to individual threat abilities, shown when they are detected.",
            controls = BlockPooky.GetThreatAlertAbilityLabelControls(),
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Stamina Low Warning",
            text = "Settings for stamina depletion overlay warning.",
            tooltip = "Settings for stamina depletion overlay warning.",
        },
        {
            type    = "checkbox",
            name    = "Enable Stamina Low Warning",
            tooltip = "Show a full-screen overlay when stamina drops below threshold.",
            default = false,
            getFunc = function() return BlockPooky.config.staminalow.show end,
            setFunc = function(newValue)
                if newValue ~= BlockPooky.config.staminalow.show then
                    BlockPooky.config.staminalow.show = newValue
                    if newValue then
                        BlockPooky.RegisterStaminaLow()
                    else
                        BlockPooky.UnRegisterStaminaLow()
                    end
                end
            end,
        },
        {
            type    = "slider",
            name    = "Stamina Threshold",
            tooltip = "Stamina value below which the overlay appears.",
            min     = 1000,
            max     = 20000,
            step    = 500,
            getFunc = function() return BlockPooky.config.staminalow.threshold or 5000 end,
            setFunc = function(newValue) BlockPooky.config.staminalow.threshold = newValue end,
        },
        {
            type    = "slider",
            name    = "Minimum Opacity (at threshold)",
            tooltip = "Opacity when stamina is at your threshold.",
            min     = 0.0,
            max     = 1.0,
            step    = 0.05,
            getFunc = function() return BlockPooky.config.staminalow.minAlpha or 0.3 end,
            setFunc = function(newValue) BlockPooky.config.staminalow.minAlpha = newValue end,
        },
        {
            type    = "slider",
            name    = "Maximum Opacity (at 0 stamina)",
            tooltip = "Opacity when stamina reaches 0.",
            min     = 0.0,
            max     = 1.0,
            step    = 0.05,
            getFunc = function() return BlockPooky.config.staminalow.maxAlpha or 0.72 end,
            setFunc = function(newValue) BlockPooky.config.staminalow.maxAlpha = newValue end,
        },
        {
            type = "button",
            name = "Reset to Defaults",
            tooltip = "Reset all stamina low warning settings to defaults.",
            func = function()
                BlockPooky.ResetStaminaLowDefaults()
            end,
        },
        {
            type = "divider",
        },
        {
            type = "description",
            title = "Settings",
            text = "Settings",
        },
        {
            type = "submenu",
            name = "Customize UI",
            controls = {
                {
                    type    = "checkbox",
                    name    = "Lock UI (to move it)",
                    default = false,
                    getFunc = function() return BlockPooky.config.lockedUI end,
                    setFunc = function(newValue) BlockPooky.SetUiLock(newValue) end,
                },
                {
                    type    = "button",
                    name    = "Reset to default position",
                    tooltip = "Reset all UI elements to their default positions.",
                    func    = function() BlockPooky.ResetPosition() end,
                },
                {
                    type = "submenu",
                    name = "Element Positions",
                    tooltip =
                    "Set element positions via sliders (alternative to dragging). Useful if elements moved off-screen.",
                    controls = BlockPooky.GetElementPositionControls(),
                },
                {
                    type = "divider",
                },
                {
                    type = "slider",
                    name = "UI Font Size",
                    tooltip = "Font size for UI frames.",
                    min = 20,
                    max = 100,
                    step = 1,
                    getFunc = function() return BlockPooky.config.fontSize end,
                    setFunc = function(value)
                        BlockPooky.config.fontSize = value; BlockPooky.setBlockPookyFont()
                    end,
                    default = 45,
                },
                {
                    type = "divider",
                    tooltip = "Visual divider for menu sections.",
                },
                {
                    type = "slider",
                    name = "UI Big Font Size",
                    tooltip = "Font size for UI frames.",
                    min = 20,
                    max = 100,
                    step = 1,
                    getFunc = function() return BlockPooky.config.bigFontSize end,
                    setFunc = function(value)
                        BlockPooky.config.bigFontSize = value; BlockPooky.setBlockPookyFont()
                    end,
                    default = 45,
                },
                {
                    type = "divider",
                }
                ,
                {
                    type = "colorpicker",
                    name = "Block Warning Color",
                    tooltip = "Set the color for the Block Pooky! UI frame.",
                    getFunc = function()
                        if BlockPooky.config.color then
                            return unpack(BlockPooky.config.color)
                        end
                        return 0.627, 0.129, 0.157, 1.0
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.color = { r, g, b, a }
                        BlockPooky.SetColor()
                    end
                },
                {
                    type = "colorpicker",
                    name = "Blocking Hint Color",
                    tooltip = "Set the color for the Blocking UI frame.",
                    getFunc = function()
                        if BlockPooky.config.blocking.color then
                            return unpack(BlockPooky.config.blocking.color)
                        end
                        return 0.980, 0.655, 0.0, 1.0
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.blocking.color = { r, g, b, a }
                        BlockPooky.SetBlockingColor()
                    end
                },
                {
                    type = "colorpicker",
                    name = "Vigor Hint Color",
                    tooltip = "Set the color for the Vigor hint UI frame.",
                    getFunc = function()
                        if BlockPooky.config.vigorUI.color then
                            return unpack(BlockPooky.config.vigorUI.color)
                        end
                        return 0.0, 0.533, 1.0, 1.0
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.vigorUI.color = { r, g, b, a }
                        BlockPooky.SetVigorHintColor()
                    end
                },
                {
                    type = "colorpicker",
                    name = "CC Immunity Bar Color (Hard CC)",
                    tooltip =
                    "Set the color for HARD CC immunity (stun/knockdown/fear/disorient) on the CC Immunity bar.",
                    getFunc = function()
                        if BlockPooky.config.ccBarColor then
                            return unpack(BlockPooky.config.ccBarColor)
                        end
                        return 0, 1, 0, 1
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.ccBarColor = { r, g, b, a }
                        BlockPooky.SetCCBarColor()
                    end
                },
                {
                    type = "colorpicker",
                    name = "CC Immunity Bar Color (Soft CC)",
                    tooltip =
                    "Set the color for SOFT CC immunity (snares/immobilizes) on the CC Immunity bar. The bar blends both colors while hard and soft immunity are active at the same time.",
                    getFunc = function()
                        if BlockPooky.config.ccBarSoftColor then
                            return unpack(BlockPooky.config.ccBarSoftColor)
                        end
                        return 0, 0.75, 1, 1
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.ccBarSoftColor = { r, g, b, a }
                        BlockPooky.SetCCBarSoftColor()
                    end
                },
                {
                    type = "colorpicker",
                    name = "Negate Warning Color",
                    tooltip = "Set the color for the Negate warning.",
                    getFunc = function()
                        if BlockPooky.config.negate then
                            return unpack(BlockPooky.config.negate.color)
                        end
                        return 1, 0, 0, 1
                    end,
                    setFunc = function(r, g, b, a)
                        BlockPooky.config.negate.color = { r, g, b, a }
                        BlockPooky.SetNegateWarningColor()
                    end
                }
            }
        },
        {
            type = "submenu",
            name = "Combat Visuals",
            tooltip = "Adjust maximum values for AOE brightness and outlines.",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Custom Combat Visuals",
                    tooltip =
                    "Enable to use custom values for AOE brightness and outlines. Disable to reset to defaults.",
                    getFunc = function() return BlockPooky.config.combatVisualsEnabled or false end,
                    setFunc = function(newValue)
                        BlockPooky.config.combatVisualsEnabled = newValue
                        -- Defensive: ensure ZO_SharedOptions_SettingsData exists before calling
                        if ZO_SharedOptions_SettingsData then
                            if newValue then
                                BlockPooky.SetMaxAOEBrightness(BlockPooky.config.MaxAOEBrightness or 500)
                                BlockPooky.SetMaxOutlineThickness(BlockPooky.config.MaxOutlineThickness or 2000)
                                BlockPooky.SetMaxTargetOutlineIntensity(BlockPooky.config.MaxTargetOutlineIntensity or
                                    2000)
                            else
                                BlockPooky.ResetMaxAOEBrightness()
                                BlockPooky.ResetMaxOutlineThickness()
                                BlockPooky.ResetMaxTargetOutlineIntensity()
                            end
                        else
                            d("Combat Visuals: ZO_SharedOptions_SettingsData is not available.")
                        end
                    end,
                    default = false,
                },
                {
                    type = "slider",
                    name = "Max AOE Brightness",
                    tooltip =
                    "Sets the maximum AOE brightness. This controls the slider found in Settings > Gameplay > Combat > Friendly/Enemy Monster Tells Brightness.",
                    min = 50,
                    max = 2000,
                    step = 10,
                    getFunc = function() return BlockPooky.config.MaxAOEBrightness or 500 end,
                    setFunc = function(value)
                        BlockPooky.config.MaxAOEBrightness = value
                        if BlockPooky.config.combatVisualsEnabled then
                            BlockPooky.SetMaxAOEBrightness(value)
                        end
                    end,
                    default = 500,
                },
                {
                    type = "slider",
                    name = "Max Outline Thickness",
                    tooltip =
                    "Sets the maximum outline thickness. This controls the slider found in Settings > Nameplates > In-World > Glow Thickness.",
                    min = 100,
                    max = 4000,
                    step = 10,
                    getFunc = function() return BlockPooky.config.MaxOutlineThickness or 2000 end,
                    setFunc = function(value)
                        BlockPooky.config.MaxOutlineThickness = value
                        if BlockPooky.config.combatVisualsEnabled then
                            BlockPooky.SetMaxOutlineThickness(value)
                        end
                    end,
                    default = 2000,
                },
                {
                    type = "slider",
                    name = "Max Target Outline Intensity",
                    tooltip =
                    "Sets the maximum target outline intensity. This controls the slider found in Settings > Nameplates > In-World > Target Glow Intensity.",
                    min = 100,
                    max = 4000,
                    step = 10,
                    getFunc = function() return BlockPooky.config.MaxTargetOutlineIntensity or 2000 end,
                    setFunc = function(value)
                        BlockPooky.config.MaxTargetOutlineIntensity = value
                        if BlockPooky.config.combatVisualsEnabled then
                            BlockPooky.SetMaxTargetOutlineIntensity(value)
                        end
                    end,
                    default = 2000,
                },
                {
                    type = "button",
                    name = "Reset Custom Combat Visuals",
                    tooltip = "Reset all combat visual values to their defaults.",
                    func = function()
                        BlockPooky.config.MaxAOEBrightness = 500
                        BlockPooky.config.MaxOutlineThickness = 2000
                        BlockPooky.config.MaxTargetOutlineIntensity = 2000
                        BlockPooky.SetMaxAOEBrightness(500)
                        BlockPooky.SetMaxOutlineThickness(2000)
                        BlockPooky.SetMaxTargetOutlineIntensity(2000)
                    end,
                    warning = "This will reset all values to their defaults.",
                },
                {
                    type = "divider",
                    tooltip = "Visual divider for menu sections.",
                },
                {
                    type = "description",
                    title = "RGB AOE Settings",
                    text = "RGB AOE color cycling settings.",
                    tooltip = "RGB AOE color cycling settings.",
                },
                {
                    type = "checkbox",
                    name = "Enable RGB AOE",
                    tooltip = "Enable or disable BlockPooky RGB AOE color cycling (can also use /blockpookyrgb in chat)",
                    getFunc = function() return BlockPooky.config.AOERGBEnabled end,
                    setFunc = function(value)
                        BlockPooky.config.AOERGBEnabled = value
                        BlockPooky.SetAOERGBState(value, false)
                    end,
                },
                {
                    type = "colorpicker",
                    name = "Default AOE Color",
                    tooltip = "The color that your AoEs will return to when RGB AOE is disabled.",
                    warning = "Disable RGB AOE (above) before changing this or it may act weirdly.",
                    getFunc = function()
                        local c = BlockPooky.config.AOERGBDefaultColor or string.format("%02x%02x%02x", 255, 0, 0)
                        return tonumber("0x" .. c:sub(1, 2)) / 255, tonumber("0x" .. c:sub(3, 4)) / 255,
                            tonumber("0x" .. c:sub(5, 6)) / 255
                    end,
                    setFunc = function(red, green, blue, a)
                        local newColor = string.format("%02x%02x%02x", red * 255, green * 255, blue * 255)
                        BlockPooky.config.AOERGBDefaultColor = newColor
                        SetSetting(SETTING_TYPE_COMBAT, COMBAT_SETTING_MONSTER_TELLS_ENEMY_COLOR, newColor)
                    end,
                },
                {
                    type = "slider",
                    name = "Cycle Speed",
                    tooltip = "The rate at which the colors cycle (lower is faster)",
                    min = 10,
                    max = 75,
                    step = 1,
                    getFunc = function() return BlockPooky.config.AOERGBSpeed or 50 end,
                    setFunc = function(value)
                        BlockPooky.config.AOERGBSpeed = value
                        BlockPooky.SetAOERGBState(false, false)
                        BlockPooky.SetAOERGBState(true, false)
                    end,
                },
                {
                    type = "checkbox",
                    name = "Turbo Mode",
                    tooltip = "Enable to double the color cycle speed.",
                    warning = "May be distracting during combat!",
                    getFunc = function() return BlockPooky.config.AOERGBTurbo == 2 end,
                    setFunc = function(value)
                        BlockPooky.config.AOERGBTurbo = value and 2 or 1
                    end,
                },
            }
        },
        {
            type = "divider",
            tooltip = "Visual divider for menu sections.",
        },
        {
            type = "description",
            title = "Messages",
            text = "Customize notification messages.",
            tooltip = "Customize notification messages.",
        },
        {
            type = "submenu",
            name = "Customize Messages",
            tooltip = "Customize all in-game messages and labels.",
            controls = {
                {
                    type = "editbox",
                    name = "Block Warning",
                    tooltip = "Message shown when an incoming pull ability is detected.",
                    getFunc = function() return BlockPooky.config.messages.blockWarning end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.blockWarning = value
                            BlockPooky.UpdateUILabels()
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Blocking Hint",
                    tooltip = "Message shown when player is actively blocking.",
                    getFunc = function() return BlockPooky.config.messages.blockingHint end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.blockingHint = value
                            BlockPooky.UpdateUILabels()
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Vigor Hint",
                    tooltip = "Message shown for Vigor recasting hints.",
                    getFunc = function() return BlockPooky.config.messages.vigorHint end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.vigorHint = value
                            BlockPooky.UpdateUILabels()
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "DC Ready Message",
                    tooltip = "Center screen message when Dark Convergence is ready.",
                    getFunc = function() return BlockPooky.config.messages.dcReady end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.dcReady = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "ROA Ready Message",
                    tooltip = "Center screen message when Rush of Agony is ready.",
                    getFunc = function() return BlockPooky.config.messages.roaReady end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.roaReady = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Mount Ready Message",
                    tooltip = "Message shown when it's safe to mount in Cyrodiil.",
                    getFunc = function() return BlockPooky.config.messages.mountReady end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.mountReady = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "CC Immunity Bar Label",
                    tooltip = "Label text shown on the CC immunity bar.",
                    getFunc = function() return BlockPooky.config.messages.ccImmunity end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.ccImmunity = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Stun CSA Message",
                    tooltip = "Center screen message shown when you are stunned.",
                    getFunc = function() return BlockPooky.config.messages.ccStun end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.ccStun = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Fear CSA Message",
                    tooltip = "Center screen message shown when you are feared.",
                    getFunc = function() return BlockPooky.config.messages.ccFear end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.ccFear = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Disorient CSA Message",
                    tooltip = "Center screen message shown when you are disoriented.",
                    getFunc = function() return BlockPooky.config.messages.ccDisorient end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.ccDisorient = value
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Negate Warning",
                    tooltip = "Message shown when standing in enemy Negate Magic field.",
                    getFunc = function() return BlockPooky.config.messages.negateWarning end,
                    setFunc = function(value)
                        if value ~= "" then
                            BlockPooky.config.messages.negateWarning = value
                            if BlockPooky.negateWarningLabel then
                                BlockPooky.negateWarningLabel:SetText(value)
                            end
                        end
                    end,
                    isMultiline = false,
                },
                {
                    type = "button",
                    name = "Reset to Defaults",
                    tooltip = "Restore all messages to their default values.",
                    func = function()
                        BlockPooky.config.messages.blockWarning = BlockPooky.defaultMessages.blockWarning
                        BlockPooky.config.messages.blockingHint = BlockPooky.defaultMessages.blockingHint
                        BlockPooky.config.messages.vigorHint = BlockPooky.defaultMessages.vigorHint
                        BlockPooky.config.messages.dcReady = BlockPooky.defaultMessages.dcReady
                        BlockPooky.config.messages.roaReady = BlockPooky.defaultMessages.roaReady
                        BlockPooky.config.messages.mountReady = BlockPooky.defaultMessages.mountReady
                        BlockPooky.config.messages.ccImmunity = BlockPooky.defaultMessages.ccImmunity
                        BlockPooky.config.messages.ccStun = BlockPooky.defaultMessages.ccStun
                        BlockPooky.config.messages.ccFear = BlockPooky.defaultMessages.ccFear
                        BlockPooky.config.messages.ccDisorient = BlockPooky.defaultMessages.ccDisorient
                        BlockPooky.config.messages.negateWarning = BlockPooky.defaultMessages.negateWarning
                        BlockPooky.config.messages.allMounted = BlockPooky.defaultMessages.allMounted
                        BlockPooky.config.messages.allCanMount = BlockPooky.defaultMessages.allCanMount
                        BlockPooky.config.messages.pookyUnmounted = BlockPooky.defaultMessages.pookyUnmounted
                        BlockPooky.UpdateUILabels()
                        if BlockPooky.negateWarningLabel then
                            BlockPooky.negateWarningLabel:SetText(BlockPooky.defaultMessages.negateWarning)
                        end
                    end,
                }
            }
        },
        {
            type = "submenu",
            name = "Group Mount Notifications",
            tooltip = "Group-wide mount status messages shown while you are in a group.",
            controls = {
                {
                    type = "description",
                    title = "Group Mount Notifications",
                    text =
                    "Simple group-wide mount messages shown while you are in a group. No extra UI is added \226\128\148 they reuse the existing mount notification style. Leave a message empty to disable that message.",
                },
                {
                    type    = "checkbox",
                    name    = "Enable Group Mount Messages",
                    tooltip =
                    "Show group-wide mount messages while grouped. The lightweight poll only runs while grouped (it also powers the personal \"Pooky you can MOUNT!\" reminder), so it costs nothing when solo.",
                    default = false,
                    getFunc = function() return BlockPooky.config.groupMountNotify end,
                    setFunc = function(newValue)
                        if newValue ~= BlockPooky.config.groupMountNotify then
                            BlockPooky.config.groupMountNotify = newValue
                            BlockPooky.UpdateMountPollRegistration()
                        end
                    end,
                },
                {
                    type    = "checkbox",
                    name    = "Show Mount Traffic Light (beta)",
                    tooltip =
                    "Shows a small single light while grouped: green = all mounted, yellow = all can mount, red = at least one Pooky unmounted. Drag to reposition.",
                    default = false,
                    getFunc = function() return BlockPooky.config.showMountLight end,
                    setFunc = function(newValue)
                        if newValue ~= BlockPooky.config.showMountLight then
                            BlockPooky.config.showMountLight = newValue
                        end
                    end,
                },
                {
                    type = "button",
                    name = "Reset Traffic Light Position",
                    tooltip = "Reset the traffic light to its default position.",
                    func = function() BlockPooky.ResetMountLightPosition() end,
                },
                {
                    type = "editbox",
                    name = "All Mounted Message",
                    tooltip = "Shown when every online group member in your zone is mounted. Leave empty to disable.",
                    getFunc = function() return BlockPooky.config.messages.allMounted end,
                    setFunc = function(value)
                        BlockPooky.config.messages.allMounted = value
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "All Can Mount Message",
                    tooltip =
                    "Shown when every online group member in your zone is off mount and out of combat. Leave empty to disable.",
                    getFunc = function() return BlockPooky.config.messages.allCanMount end,
                    setFunc = function(value)
                        BlockPooky.config.messages.allCanMount = value
                    end,
                    isMultiline = false,
                },
                {
                    type = "editbox",
                    name = "Pooky Unmounted Message",
                    tooltip = "Shown when a group member (not you) dismounts. Leave empty to disable.",
                    getFunc = function() return BlockPooky.config.messages.pookyUnmounted end,
                    setFunc = function(value)
                        BlockPooky.config.messages.pookyUnmounted = value
                    end,
                    isMultiline = false,
                },
            }
        },
        {
            type = "divider",
            tooltip = "Visual divider for menu sections.",
        },
        {
            type = "submenu",
            name = "Debug Tools",
            tooltip = "Enable investigation of abilities and effects.",
            controls = {
                {
                    type    = "checkbox",
                    name    = "Enable Ability Investigation",
                    default = false,
                    getFunc = function() return BlockPooky.config.investigate end,
                    setFunc = function(newValue) BlockPooky.config.investigate = newValue end,
                },
                {
                    type    = "checkbox",
                    name    = "Enable Effect Investigation",
                    default = false,
                    getFunc = function() return BlockPooky.config.investigateEffects end,
                    setFunc = function(newValue) BlockPooky.config.investigateEffects = newValue end,
                },
                {
                    type    = "checkbox",
                    name    = "Enable Incoming Damage Investigation",
                    tooltip =
                    "Logs every hit that lands on you as Name | ID | Source. Use it to find charge/gap-closer IDs, which never show up in ability investigation.",
                    default = false,
                    getFunc = function() return BlockPooky.config.investigateDamage end,
                    setFunc = function(newValue) BlockPooky.config.investigateDamage = newValue end,
                }
            }
        }
    }
    --
    BlockPooky.panel = BlockPooky_LAM:RegisterAddonPanel(BlockPooky.name .. "Options", menuOptions)
    BlockPooky_LAM:RegisterOptionControls(BlockPooky.name .. "Options", dataTable)
end
