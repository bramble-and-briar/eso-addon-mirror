-- My UI - LibAddonMenu-only settings bridge. No internal menu or LibGamepad fallback.

BUI = BUI or {}
BUI.SettingsBridge = BUI.SettingsBridge or {}
local Bridge = BUI.SettingsBridge

Bridge.mode = "lam"
Bridge.panels = Bridge.panels or {}
Bridge.firstPanel = Bridge.firstPanel or nil
Bridge.groupedSections = Bridge.groupedSections or {}
Bridge.pendingSections = Bridge.pendingSections or {}
Bridge.groupedFinalized = Bridge.groupedFinalized or {}
Bridge.groupedPanelData = Bridge.groupedPanelData or {}
Bridge.groupedControls = Bridge.groupedControls or {}
Bridge.directRegistered = Bridge.directRegistered or {}
Bridge.directScheduled = Bridge.directScheduled or {}
Bridge.directPanelIds = Bridge.directPanelIds or {}

local function GetLAM()
    if rawget(_G, "LibAddonMenu2") then
        return LibAddonMenu2
    end
    local libStub = rawget(_G, "LibStub")
    if libStub then
        local ok, lam = pcall(libStub, "LibAddonMenu-2.0")
        if ok and lam then return lam end
    end
    return nil
end

local function GetLibGamepad()
    return rawget(_G, "LibGamepad")
end

local function Loc(key)
    if type(key) ~= "string" then return key end
    if BUI and BUI.Localization then
        local lang = BUI.language
        local langTable = lang and BUI.Localization[lang]
        local enTable = BUI.Localization.en
        if langTable and langTable[key] then return langTable[key] end
        if enTable and enTable[key] then return enTable[key] end
    end
    return key
end

local function TooltipFor(data)
    if data.tooltip and data.tooltip ~= "" then
        return Loc(data.tooltip)
    end
    if data.name then
        local descKey = tostring(data.name) .. "Desc"
        local text = Loc(descKey)
        if text ~= descKey then return text end
    end
    return nil
end

local function FindChoiceIndex(choices, choicesValues, value)
    if choicesValues then
        for i, v in ipairs(choicesValues) do
            if v == value then return i end
        end
    end
    if choices then
        for i, v in ipairs(choices) do
            if v == value then return i end
        end
    end
    return type(value) == "number" and value or nil
end

local function CloneOption(data)
    local out = {}
    for k, v in pairs(data) do out[k] = v end

    if out.name then out.name = Loc(out.name) end
    if out.text then out.text = Loc(out.text) end
    local tt = TooltipFor(data)
    if tt then out.tooltip = tt end
    if type(out.warning) == "string" then out.warning = Loc(out.warning) end

    -- The original Satuve menu supports dropdown setFunc(index, value) and numeric
    -- getFunc() results. LAM uses the selected value. Adapt both conventions here.
    if data.type == "dropdown" then
        local originalGet = data.getFunc
        local originalSet = data.setFunc
        local choices = data.choices
        local choicesValues = data.choicesValues

        if originalGet then
            out.getFunc = function()
                local value = originalGet()
                if type(value) == "number" and not choicesValues and choices and choices[value] ~= nil then
                    return choices[value]
                end
                return value
            end
        end

        if originalSet then
            out.setFunc = function(value)
                local index = FindChoiceIndex(choices, choicesValues, value)
                originalSet(index or value, value)
            end
        end
    end

    -- BUI has a custom "gradient" widget. Represent it in LAM as two normal
    -- color pickers so both ends of the gradient remain fully editable.
    if data.type == "gradient" then
        return {
            type = "submenu",
            name = Loc(data.name),
            controls = {
                {
                    type = "colorpicker",
                    name = Loc(data.name) .. " 1",
                    getFunc = data.getFunc,
                    setFunc = data.setFunc,
                    disabled = data.disabled,
                },
                {
                    type = "colorpicker",
                    name = Loc(data.name) .. " 2",
                    getFunc = data.getFunc2,
                    setFunc = data.setFunc2,
                    disabled = data.disabled,
                },
            },
        }
    end

    if data.type == "submenu" and data.controls then
        out.controls = {}
        for _, child in ipairs(data.controls) do
            local converted = CloneOption(child)
            if converted then table.insert(out.controls, converted) end
        end
    end

    -- Decorative texture rows are not needed in the settings/gamepad list and
    -- are not supported consistently by every LAM/Gamepad adapter version.
    if data.type == "texture" then
        return nil
    end

    return out
end

local function BuildSliderChoices(data)
    local choices, values = {}, {}
    local minValue = tonumber(data.min) or 0
    local maxValue = tonumber(data.max) or 100
    local step = tonumber(data.step) or 1
    if step <= 0 then step = 1 end

    local value = minValue
    local guard = 0
    while value <= maxValue + (step * 0.001) and guard < 1000 do
        local rounded = math.floor(value + 0.5)
        choices[#choices + 1] = tostring(rounded)
        values[#values + 1] = rounded
        value = value + step
        guard = guard + 1
    end
    return choices, values
end

local function CloneControllerSafeOption(data)
    -- LibGamepad versions used with ESO can expose a LAM slider but not always
    -- forward left/right controller changes to its setFunc. For sections that
    -- explicitly request controller-safe sliders, expose the exact same numeric
    -- range as a dropdown. It still writes the original numeric BUI.Vars value
    -- and calls the original setFunc immediately.
    if data.type == "slider" then
        local choices, values = BuildSliderChoices(data)
        local originalGet = data.getFunc
        local originalSet = data.setFunc
        return {
            type = "dropdown",
            name = Loc(data.name),
            tooltip = TooltipFor(data),
            choices = choices,
            choicesValues = values,
            getFunc = function()
                local value = originalGet and tonumber(originalGet()) or values[1]
                if value == nil then value = values[1] end
                -- Snap old/custom values to the nearest legal controller value.
                local best, bestDistance = values[1], math.huge
                for _, candidate in ipairs(values) do
                    local distance = math.abs(candidate - value)
                    if distance < bestDistance then
                        best, bestDistance = candidate, distance
                    end
                end
                return best
            end,
            setFunc = function(value)
                value = tonumber(value) or value
                if originalSet then originalSet(value) end
            end,
            disabled = data.disabled,
            warning = data.warning,
            default = data.default,
        }
    end

    if data.type == "submenu" and data.controls then
        local out = {}
        for k, v in pairs(data) do out[k] = v end
        out.name = Loc(out.name)
        out.controls = {}
        for _, child in ipairs(data.controls) do
            local converted = CloneControllerSafeOption(child)
            if converted then table.insert(out.controls, converted) end
        end
        return out
    end

    return CloneOption(data)
end

local function ConvertOptions(options, controllerSafeSliders)
    local result = {}
    for _, data in ipairs(options or {}) do
        local converted
        if controllerSafeSliders then
            converted = CloneControllerSafeOption(data)
        else
            converted = CloneOption(data)
        end
        if converted then table.insert(result, converted) end
    end
    return result
end

-- Legacy inline-flatten helper. Compatible LibGamepad versions support nested LAM
-- submenus, so the grouped Bandit UI path intentionally preserves submenu trees.
-- This helper is kept only for compatibility with older experiments and is not
-- used by FinalizeGrouped().
local function ConvertSectionOptions(options, controllerSafeSliders)
    local result = {}

    local function append(list)
        for _, data in ipairs(list or {}) do
            if data.type == "submenu" and data.controls then
                table.insert(result, {
                    type = "header",
                    name = Loc(data.name),
                })
                append(data.controls)
            else
                local converted
                if controllerSafeSliders then
                    converted = CloneControllerSafeOption(data)
                else
                    converted = CloneOption(data)
                end
                if converted then table.insert(result, converted) end
            end
        end
    end

    append(options)
    return result
end


-- Resolve strings/functions the same way LibAddonMenu/LibGamepad expect.
local function ResolveText(value)
    local current = value
    local guard = 0
    while type(current) == "function" and guard < 3 do
        local ok, result = pcall(current)
        if not ok then return "" end
        current = result
        guard = guard + 1
    end
    if type(current) == "number" and type(GetString) == "function" then
        local ok, result = pcall(GetString, current)
        if ok and result then return tostring(result) end
    end
    if current == nil then return "" end
    return tostring(current)
end

local function MakeGamepadTooltip(textValue)
    local function getText()
        return ResolveText(textValue)
    end
    if getText() == "" then return nil end
    return function(tooltipControl)
        local text = getText()
        if text ~= "" and rawget(_G, "GAMEPAD_TOOLTIPS") and GAMEPAD_TOOLTIPS.LayoutTextBlockTooltip then
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, text)
        end
    end
end

local SAFE_CHECKBOX_TEMPLATE = "SatuveXboxUI_OptionsCheckboxRow"
local SAFE_FINITE_LIST_TEMPLATE = "SatuveXboxUI_OptionsFiniteListRow"
local SAFE_SLIDER_TEMPLATE = "SatuveXboxUI_OptionsSliderRow"

local function RefreshAddonDependencies(data)
    if data and data.gamepadHasEnabledDependencies and rawget(_G, "GAMEPAD_OPTIONS") then
        GAMEPAD_OPTIONS:OnOptionWithDependenciesChanged()
    end
end

local function SafeCheckboxSetup(control, data, selected)
    control.data = data
    GAMEPAD_OPTIONS:InitializeControl(control, selected)

    local checkBox = control:GetNamedChild("Checkbox")
    if not checkBox then return end
    ZO_CheckButton_SetToggleFunction(checkBox, function(_, checked)
        if data.SetSettingOverride then
            data.SetSettingOverride(control, checked)
            data.currentChoice = checked
        end
        -- Refresh from the original BUI getter without entering SetSetting().
        ZO_Options_UpdateOption(control)
        RefreshAddonDependencies(data)
    end)
end

local function SafeFiniteListSetup(control, data, selected)
    control.data = data
    GAMEPAD_OPTIONS:InitializeControl(control, selected)

    local list = control.horizontalListObject
    if not list then return end
    list:SetOnSelectedDataChangedCallback(function(selectedData, oldData, reselectingDuringRebuild)
        if oldData == nil or reselectingDuringRebuild == true or not selectedData then return end
        if data.SetSettingOverride then
            data.SetSettingOverride(control, selectedData.value)
            data.currentChoice = selectedData.value
        end
        if data.scrollListChangedCallback then
            data.scrollListChangedCallback(selectedData, oldData)
        end
        RefreshAddonDependencies(data)
        if rawget(_G, "SCREEN_NARRATION_MANAGER") and GAMEPAD_OPTIONS:IsShowing() then
            SCREEN_NARRATION_MANAGER:QueueParametricListEntry(GAMEPAD_OPTIONS:GetCurrentList())
        end
    end)
end

local function SafeSliderSetup(control, data, selected)
    control.data = data
    GAMEPAD_OPTIONS:InitializeControl(control, selected)

    local slider = control:GetNamedChild("Slider")
    if not slider then return end
    local valueLabel = control:GetNamedChild("ValueLabel")
    local minLabel = control:GetNamedChild("MinLabel")
    local maxLabel = control:GetNamedChild("MaxLabel")

    local function UpdateLabels(value)
        local shown, minValue, maxValue = ZO_Options_GetFormattedSliderValues(data, value)
        if valueLabel then valueLabel:SetText(tostring(shown)) end
        if minLabel then minLabel:SetText(tostring(minValue)) end
        if maxLabel then maxLabel:SetText(tostring(maxValue)) end
    end

    UpdateLabels(slider:GetValue())
    slider:SetHandler("OnValueChanged", function(_, value)
        local valueFormat = data.valueFormat or "%d"
        local formatted = string.format(valueFormat, value)
        local addonValue = tonumber(formatted) or formatted
        if data.SetSettingOverride then
            data.SetSettingOverride(control, addonValue)
            data.currentChoice = addonValue
        end
        UpdateLabels(addonValue)
        RefreshAddonDependencies(data)
    end)
end

local function RegisterSafeGamepadTemplates(_, list)
    if not list or list.satuveXboxUISafeTemplates then return end
    list.satuveXboxUISafeTemplates = true

    local function ReleaseControl(control)
        control.state = nil
    end
    local function ReleaseFiniteList(control)
        if control.horizontalListObject then control.horizontalListObject:Deactivate() end
        ReleaseControl(control)
    end
    local function ReleaseSlider(control)
        if control.slider then control.slider:Deactivate() end
        ReleaseControl(control)
    end

    list:AddDataTemplate(SAFE_CHECKBOX_TEMPLATE, SafeCheckboxSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader(SAFE_CHECKBOX_TEMPLATE, SafeCheckboxSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction(SAFE_CHECKBOX_TEMPLATE, ReleaseControl)
    list:SetDataTemplateWithHeaderReleaseFunction(SAFE_CHECKBOX_TEMPLATE, ReleaseControl)

    list:AddDataTemplate(SAFE_FINITE_LIST_TEMPLATE, SafeFiniteListSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader(SAFE_FINITE_LIST_TEMPLATE, SafeFiniteListSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction(SAFE_FINITE_LIST_TEMPLATE, ReleaseFiniteList)
    list:SetDataTemplateWithHeaderReleaseFunction(SAFE_FINITE_LIST_TEMPLATE, ReleaseFiniteList)

    list:AddDataTemplate(SAFE_SLIDER_TEMPLATE, SafeSliderSetup, ZO_GamepadMenuEntryTemplateParametricListFunction)
    list:AddDataTemplateWithHeader(SAFE_SLIDER_TEMPLATE, SafeSliderSetup, ZO_GamepadMenuEntryTemplateParametricListFunction, nil, "ZO_GamepadOptionsHeaderTemplate")
    list:SetDataTemplateReleaseFunction(SAFE_SLIDER_TEMPLATE, ReleaseSlider)
    list:SetDataTemplateWithHeaderReleaseFunction(SAFE_SLIDER_TEMPLATE, ReleaseSlider)
end

local function EnsureSafeGamepadTemplates()
    if not rawget(_G, "GAMEPAD_OPTIONS") then return false end
    if not Bridge.safeTemplatesHooked then
        Bridge.safeTemplatesHooked = true
        SecurePostHook(GAMEPAD_OPTIONS, "SetupOptionsList", RegisterSafeGamepadTemplates)
    end
    if GAMEPAD_OPTIONS.optionsList then
        RegisterSafeGamepadTemplates(GAMEPAD_OPTIONS, GAMEPAD_OPTIONS.optionsList)
    end
    return true
end

local function DirectDropdownAccess(data)
    local originalGet = data.getFunc
    local originalSet = data.setFunc
    local choices = data.choices or {}
    local values = data.choicesValues

    local getFunc = function()
        local value = originalGet and originalGet() or nil
        if type(value) == "number" and not values and choices[value] ~= nil then
            return choices[value]
        end
        return value
    end

    local setFunc = function(_, value)
        if not originalSet then return end
        local index = FindChoiceIndex(choices, values, value)
        originalSet(index or value, value)
    end

    return getFunc, setFunc, (values or choices), choices
end

local function DirectSliderAsDropdown(data)
    local choices, values = BuildSliderChoices(data)
    local originalGet = data.getFunc
    local originalSet = data.setFunc
    return {
        controlType = OPTIONS_FINITE_LIST,
        text = ResolveText(Loc(data.name)),
        valid = values,
        itemText = choices,
        GetSettingOverride = function()
            local current = originalGet and tonumber(originalGet()) or values[1]
            if current == nil then return values[1] end
            local best, distance = values[1], math.huge
            for _, candidate in ipairs(values) do
                local d = math.abs(candidate - current)
                if d < distance then best, distance = candidate, d end
            end
            return best
        end,
        SetSettingOverride = function(_, value)
            if originalSet then originalSet(tonumber(value) or value) end
        end,
        disabled = data.disabled,
        gamepadCustomTooltipFunction = MakeGamepadTooltip(TooltipFor(data)),
        customTemplate = SAFE_FINITE_LIST_TEMPLATE,
    }
end

local function ShowDirectColorPicker(data)
    if not data.getFunc or not data.setFunc then return end
    local r, g, b, a = data.getFunc()
    a = a == nil and 1 or a
    local picker = rawget(_G, "COLOR_PICKER_GAMEPAD") or rawget(_G, "COLOR_PICKER")
    if picker and type(picker.Show) == "function" then
        local callback = function(nr, ng, nb, na)
            data.setFunc(nr, ng, nb, na == nil and a or na)
        end
        pcall(picker.Show, picker, callback, r or 1, g or 1, b or 1, a, ResolveText(Loc(data.name)))
    end
end

local function CreateDirectSimpleOption(data, controllerSafeSliders)
    local lib = GetLibGamepad()
    if not lib then return nil end
    local factory = lib.ComponentFactory
    local oType = data.type
    local name = ResolveText(Loc(data.name or data.title or ""))
    local tooltip = TooltipFor(data)

    if oType == "header" then
        return factory and factory.CreateSectionHeaderMarker and factory.CreateSectionHeaderMarker(name) or nil
    elseif oType == "description" then
        local title = ResolveText(Loc(data.title))
        local body = ResolveText(Loc(data.text))
        local text = title ~= "" and body ~= "" and (title .. "\n" .. body) or (title ~= "" and title or body)
        return {
            controlType = OPTIONS_INVOKE_CALLBACK,
            text = text,
            customTemplate = "LibGamepad_OptionsDescriptionRow",
            canSelect = false,
            disabled = function() return true end,
        }
    elseif oType == "checkbox" then
        return {
            controlType = OPTIONS_CHECKBOX,
            text = name,
            GetSettingOverride = data.getFunc,
            SetSettingOverride = function(_, value) if data.setFunc then data.setFunc(value) end end,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
            customTemplate = SAFE_CHECKBOX_TEMPLATE,
        }
    elseif oType == "slider" then
        if controllerSafeSliders then
            return DirectSliderAsDropdown(data)
        end
        local minValue = tonumber(data.min) or 0
        local maxValue = tonumber(data.max) or 100
        local step = tonumber(data.step)
        local gp = {
            controlType = OPTIONS_SLIDER,
            text = name,
            minValue = minValue,
            maxValue = maxValue,
            showValue = true,
            showValueMin = minValue,
            showValueMax = maxValue,
            valueFormat = (tonumber(data.decimals) or 0) > 0 and ("%." .. tostring(tonumber(data.decimals)) .. "f") or "%d",
            GetSettingOverride = data.getFunc,
            SetSettingOverride = function(_, value) if data.setFunc then data.setFunc(value) end end,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
            customTemplate = SAFE_SLIDER_TEMPLATE,
        }
        if step and step > 0 and maxValue > minValue then
            gp.gamepadValueStepPercent = (step / (maxValue - minValue)) * 100
        end
        return gp
    elseif oType == "dropdown" then
        local getFunc, setFunc, valid, itemText = DirectDropdownAccess(data)
        return {
            controlType = OPTIONS_FINITE_LIST,
            text = name,
            valid = valid,
            itemText = itemText,
            GetSettingOverride = getFunc,
            SetSettingOverride = setFunc,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
            customTemplate = SAFE_FINITE_LIST_TEMPLATE,
        }
    elseif oType == "button" then
        return {
            controlType = OPTIONS_INVOKE_CALLBACK,
            text = name,
            callback = function() if data.func then data.func() end end,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
        }
    elseif oType == "editbox" then
        return {
            controlType = OPTIONS_INVOKE_CALLBACK,
            text = name,
            callback = function()
                if rawget(_G, "LibGamepadLAM") and LibGamepadLAM.ShowEditboxDialog then
                    local option = {}
                    for k, v in pairs(data) do option[k] = v end
                    option.name = name
                    LibGamepadLAM.ShowEditboxDialog(option, data.setFunc)
                end
            end,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
        }
    elseif oType == "colorpicker" then
        return {
            controlType = OPTIONS_INVOKE_CALLBACK,
            text = name,
            callback = function() ShowDirectColorPicker(data) end,
            disabled = data.disabled,
            gamepadCustomTooltipFunction = MakeGamepadTooltip(tooltip),
            customTemplate = "LibGamepad_OptionsSubmenuRow",
        }
    elseif oType == "divider" then
        return {
            controlType = OPTIONS_INVOKE_CALLBACK,
            text = "|cebe7bc________________|r",
            canSelect = false,
            disabled = function() return true end,
        }
    elseif oType == "texture" then
        return nil
    end

    return {
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = name ~= "" and name or "[Unsupported option]",
        canSelect = false,
        disabled = function() return true end,
        gamepadCustomTooltipFunction = MakeGamepadTooltip("This option is not supported in controller mode."),
    }
end

local function BuildDirectGamepadOptions(options, controllerSafeSliders)
    local lib = GetLibGamepad()
    if not lib then return {} end
    local result = {}

    for _, data in ipairs(options or {}) do
        if data.type == "submenu" and data.controls then
            local children = BuildDirectGamepadOptions(data.controls, controllerSafeSliders)
            if #children > 0 and lib.CreateNestedSubmenuEntry then
                local entry = lib.CreateNestedSubmenuEntry(
                    ResolveText(Loc(data.name)),
                    children,
                    ResolveText(TooltipFor(data))
                )
                if entry then
                    entry.disabled = data.disabled
                    result[#result + 1] = entry
                end
            end
        elseif data.type == "gradient" then
            local synthetic = {
                {
                    type = "colorpicker",
                    name = ResolveText(Loc(data.name)) .. " 1",
                    getFunc = data.getFunc,
                    setFunc = data.setFunc,
                    disabled = data.disabled,
                },
                {
                    type = "colorpicker",
                    name = ResolveText(Loc(data.name)) .. " 2",
                    getFunc = data.getFunc2,
                    setFunc = data.setFunc2,
                    disabled = data.disabled,
                },
            }
            local children = BuildDirectGamepadOptions(synthetic, controllerSafeSliders)
            if #children > 0 and lib.CreateNestedSubmenuEntry then
                local entry = lib.CreateNestedSubmenuEntry(ResolveText(Loc(data.name)), children)
                if entry then
                    entry.disabled = data.disabled
                    result[#result + 1] = entry
                end
            end
        else
            local gpOption = CreateDirectSimpleOption(data, controllerSafeSliders)
            if gpOption then result[#result + 1] = gpOption end
        end
    end

    return result
end

local function OpenCombatLogFromGamepadMenu()
    local function OpenReport()
        if BUI and BUI.Stats and type(BUI.Stats.Toggle) == "function" then
            BUI.Stats.Toggle()
        end
    end

    -- Return all the way to the base scene. HideCurrentScene only leaves the
    -- options panel and exposes the game menu beneath it.
    local sceneManager = rawget(_G, "SCENE_MANAGER")
    if sceneManager and type(sceneManager.ShowBaseScene) == "function" then
        sceneManager:ShowBaseScene()
        if type(zo_callLater) == "function" then
            zo_callLater(OpenReport, 100)
        else
            OpenReport()
        end
    elseif sceneManager and type(sceneManager.HideCurrentScene) == "function" then
        sceneManager:HideCurrentScene()
        OpenReport()
    else
        OpenReport()
    end
end

local function RegisterDirectGrouped(panelName)
    local lib = GetLibGamepad()
    if not lib or not lib.RegisterSubmenu or Bridge.directRegistered[panelName] then return false end
    if not EnsureSafeGamepadTemplates() then return false end

    local sections = {}
    for _, section in pairs(Bridge.pendingSections[panelName] or {}) do
        local order = tonumber(section.order) or tonumber(string.match(tostring(section.name or ""), "^%s*(%d+)")) or 999
        if order >= 1 and order <= 22 then
            sections[#sections + 1] = section
        end
    end
    table.sort(sections, function(a, b)
        local ao = tonumber(a.order) or tonumber(string.match(tostring(a.name or ""), "^%s*(%d+)")) or 999
        local bo = tonumber(b.order) or tonumber(string.match(tostring(b.name or ""), "^%s*(%d+)")) or 999
        if ao == bo then return tostring(a.name or a.id) < tostring(b.name or b.id) end
        return ao < bo
    end)

    local rootOptions = {}

    -- A direct, controller-selectable entry before "1. Base Options". This is
    -- an action rather than another settings submenu: pressing A closes the
    -- settings scene and opens the existing statistics/combat-log window.
    local combatLogEntry = CreateDirectSimpleOption({
        type = "button",
        name = "Log",
        tooltip = "PanelStatistics",
        func = OpenCombatLogFromGamepadMenu,
    }, false)
    if combatLogEntry then rootOptions[#rootOptions + 1] = combatLogEntry end

    for _, section in ipairs(sections) do
        local children = BuildDirectGamepadOptions(section.options or {}, section.controllerSafeSliders == true)
        if #children > 0 and lib.CreateNestedSubmenuEntry then
            local entry = lib.CreateNestedSubmenuEntry(ResolveText(section.name or section.id or "Settings"), children)
            if entry then rootOptions[#rootOptions + 1] = entry end
        end
    end

    if #rootOptions == 0 then return false end
    local panelData = Bridge.groupedPanelData[panelName] or {}
    local displayName = ResolveText(panelData.displayName or panelData.name or "Bandit UI")
    -- RegisterSubmenu consumes the current virtual panel ID. Keep it so the
    -- Side Panel settings button can open Bandit UI directly in controller mode.
    local directPanelId = tonumber(lib.VirtualSubmenuPanelId)
    lib.RegisterSubmenu(displayName, rootOptions, "Bandit UI settings")
    if directPanelId then Bridge.directPanelIds[panelName] = directPanelId end
    Bridge.directRegistered[panelName] = true
    Bridge.mode = "gamepad-direct"
    return true
end

local function SectionOrder(section)
    if section and section.order then return tonumber(section.order) or 999 end
    local name = section and tostring(section.name or "") or ""
    return tonumber(string.match(name, "^%s*(%d+)")) or 999
end

local function QueueGroupedSection(panelName, section)
    if not section then return end
    Bridge.pendingSections[panelName] = Bridge.pendingSections[panelName] or {}
    local key = tostring(section.id or section.name or "Settings")
    Bridge.pendingSections[panelName][key] = section
    Bridge.groupedSections[panelName] = Bridge.groupedSections[panelName] or {}
    Bridge.groupedSections[panelName][key] = true
end


function Bridge.Available()
    return GetLAM() ~= nil
end

function Bridge.HasLibGamepad()
    return false
end

function Bridge.UsingDirectGamepad()
    return false
end

function Bridge.OpenDirect(panelName)
    local panelId = Bridge.directPanelIds[panelName or "BUI_BanditUI"]
    local gamepadOptions = rawget(_G, "GAMEPAD_OPTIONS")
    local sceneManager = rawget(_G, "SCENE_MANAGER")
    if not panelId or not gamepadOptions or not sceneManager or type(sceneManager.Push) ~= "function" then
        return false
    end

    gamepadOptions.currentCategory = panelId
    sceneManager:Push("gamepad_options_panel")
    return true
end

-- Collect the complete Bandit UI tree first. LibGamepad takes a deep
-- snapshot when LAM:RegisterOptionControls is called, and its automatic LAM
-- converter only recursively expands the first submenu level.  We therefore
-- use LibGamepad's native nested-submenu API when it is installed.  LAM remains
-- the fallback for keyboard/mouse-only installations.
function Bridge.RegisterGrouped(panelName, panelData, sections)
    if not GetLAM() then
        if MyUIDebug then MyUIDebug.Note("LAM", "RegisterGrouped: LibAddonMenu fehlt") end
        return nil, "lam-unavailable"
    end
    if MyUIDebug then MyUIDebug.Note("LAM", "RegisterGrouped: " .. tostring(#(sections or {})) .. " Menuegruppen") end

    Bridge.mode = "grouped-pending"
    local panelCopy = {}
    for k, v in pairs(panelData or {}) do panelCopy[k] = v end
    panelCopy.name = "My UI"
    panelCopy.displayName = "My UI"
    panelCopy.author = "Satuve, j.hhh"
    panelCopy.version = panelCopy.version or tostring(BUI.Version or "")
    panelCopy.registerForRefresh = true
    panelCopy.registerForDefaults = true
    Bridge.groupedPanelData[panelName] = panelCopy

    for _, section in ipairs(sections or {}) do
        QueueGroupedSection(panelName, section)
    end

    return true, GetLibGamepad() and "gamepad-direct" or "lam-pending"
end

function Bridge.AddGroupedSection(panelName, section)
    if not section then return false end
    QueueGroupedSection(panelName, section)

    -- Normal Satuve initialization finalizes only once after Side Panel,
    -- Minimap, Automation and Custom Bar have all supplied their sections.
    return true
end

function Bridge.FinalizeGrouped(panelName)
    if Bridge.groupedFinalized[panelName] then return true end

    -- Preferred path: build a native LibGamepad tree, but DO NOT build its
    -- virtual panels during EVENT_ADD_ON_LOADED. LibGamepad itself initializes
    -- GAMEPAD_SETTINGS_DATA / ZO_SharedOptions on EVENT_PLAYER_ACTIVATED.
    -- Creating nested panels before that point can leave the panel title visible
    -- while ESO has no usable shared option rows, which is rendered as
    -- "Unavailable". Register just after PLAYER_ACTIVATED instead.
    if false then -- LibGamepad/direct-gamepad menu path intentionally disabled; LAM only.
        if not Bridge.directScheduled[panelName] then
            Bridge.directScheduled[panelName] = true
            local eventName = "SatuveXboxUI_LibGamepad_" .. tostring(panelName)
            local function TryRegister(attempt)
                attempt = attempt or 1
                local lib = GetLibGamepad()
                local ready = lib and lib.RegisterSubmenu and lib.CreateNestedSubmenuEntry
                    and rawget(_G, "GAMEPAD_SETTINGS_DATA") and rawget(_G, "ZO_SharedOptions")
                if ready and RegisterDirectGrouped(panelName) then
                    Bridge.groupedFinalized[panelName] = true
                    return
                end
                if attempt < 12 and type(zo_callLater) == "function" then
                    zo_callLater(function() TryRegister(attempt + 1) end, 250)
                end
            end

            if rawget(_G, "EVENT_MANAGER") and rawget(_G, "EVENT_PLAYER_ACTIVATED") then
				EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
				local function RegisterAfterActivation()
					EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_PLAYER_ACTIVATED)
					if type(zo_callLater) == "function" then
						zo_callLater(function() TryRegister(1) end, 250)
					else
						TryRegister(1)
					end
				end
				if BUI.Initialization and BUI.Initialization.playerActivated then
					RegisterAfterActivation()
				else
					EVENT_MANAGER:RegisterForEvent(eventName, EVENT_PLAYER_ACTIVATED, RegisterAfterActivation)
				end
            else
                TryRegister(1)
            end
        end
        return true
    end

    -- Keyboard/LAM fallback. Register panel and options only once, after every
    -- numbered section is available, so the option snapshot is complete.
    local lam = GetLAM()
    if not lam then
        if MyUIDebug then MyUIDebug.Note("LAM", "FinalizeGrouped: LibAddonMenu fehlt") end
        return false
    end

    local sections = {}
    for _, section in pairs(Bridge.pendingSections[panelName] or {}) do
        local order = SectionOrder(section)
        if order >= 1 and order <= 22 then
            sections[#sections + 1] = section
        end
    end
    table.sort(sections, function(a, b)
        local ao, bo = SectionOrder(a), SectionOrder(b)
        if ao == bo then return tostring(a.name or a.id) < tostring(b.name or b.id) end
        return ao < bo
    end)

    local controls = {}
    for _, section in ipairs(sections) do
        controls[#controls + 1] = {
            type = "submenu",
            name = section.name or section.id or "Settings",
            controls = ConvertOptions(section.options or {}, section.controllerSafeSliders == true),
        }
    end

    local panelData = Bridge.groupedPanelData[panelName] or {
        name = "My UI",
        displayName = "My UI",
        author = "Satuve, j.hhh",
        version = tostring(BUI.Version or ""),
        registerForRefresh = true,
        registerForDefaults = true,
    }

    panelData.name = "My UI"
    panelData.displayName = "My UI"
    panelData.author = "Satuve, j.hhh"
    if MyUIDebug then MyUIDebug.Note("LAM", "Registriere Panel " .. tostring(panelName) .. " mit " .. tostring(#controls) .. " Gruppen") end
    -- On console, LAM returns nil even when the registration is successful.
    -- Never skip option controls merely because the keyboard panel is nil.
    local isConsole = type(IsKeyboardUISupported) == "function" and not IsKeyboardUISupported()
    local panel = lam:RegisterAddonPanel(panelName, panelData)
    if not panel and not isConsole then
        if MyUIDebug then MyUIDebug.Note("LAM", "PC-Panel nicht erstellt") end
        return false
    end
    lam:RegisterOptionControls(panelName, controls)

    local conversion = isConsole and lam.LHASConversion or nil
    local registered = conversion and conversion.settingTables and conversion.settingTables[panelName]
    local converted = conversion and conversion.optionControls and conversion.optionControls[panelName]
    local rowCount = isConsole and (converted and converted.indexed and #converted.indexed or 0) or #controls
    Bridge.groupedOptionCount = Bridge.groupedOptionCount or {}
    Bridge.groupedOptionCount[panelName] = rowCount
    Bridge.panels[panelName] = panel or registered
    if panel then Bridge.firstPanel = Bridge.firstPanel or panel end
    Bridge.mode = isConsole and "lam-console" or "lam"
    if isConsole and (not registered or rowCount == 0) then
        -- This error affects the settings only: HUD init is separately guarded.
        if MyUIDebug then MyUIDebug.Note("LAM", "Konsolen-Backend: Panel=" .. tostring(registered ~= nil) .. ", Zeilen=" .. tostring(rowCount) .. ". LibVotans/LibHarvensAddonSettings pruefen") end
        return false
    end
    Bridge.groupedFinalized[panelName] = true
    if MyUIDebug then MyUIDebug.Note("LAM", "My UI: " .. tostring(rowCount) .. " Einstellungszeilen registriert") end
    return true
end

function Bridge.Register(panelName, panelData, options)
    local lam = GetLAM()
    if lam then
        Bridge.mode = "lam"

        local panelCopy = {}
        for k, v in pairs(panelData or {}) do panelCopy[k] = v end
        panelCopy.name = Loc(panelCopy.name or panelName)
        panelCopy.displayName = Loc(panelCopy.displayName or panelCopy.name)
        panelCopy.name = "My UI"
        panelCopy.displayName = "My UI"
        panelCopy.author = "Satuve, j.hhh"
        panelCopy.version = panelCopy.version or tostring(BUI.Version or "")
        panelCopy.registerForRefresh = true
        panelCopy.registerForDefaults = true

        local panel = lam:RegisterAddonPanel(panelName, panelCopy)
        lam:RegisterOptionControls(panelName, ConvertOptions(options))
        Bridge.panels[panelName] = panel
        Bridge.firstPanel = Bridge.firstPanel or panel
        return panel, "lam"
    end

    return nil, "lam-unavailable"
end

function Bridge.Open()
    local lam = GetLAM()
    if lam and Bridge.firstPanel and lam.OpenToPanel then
        lam:OpenToPanel(Bridge.firstPanel)
        return true
    end
    return false
end

function Bridge.UsingLAM()
    return Bridge.mode == "lam"
end
