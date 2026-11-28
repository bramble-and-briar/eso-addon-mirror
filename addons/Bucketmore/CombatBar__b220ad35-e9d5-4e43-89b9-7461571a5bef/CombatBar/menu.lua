-- Combat Bar : LibAddonMenu設定画面(12カテゴリ・各カテゴリ先頭に説明)
-- 表示名だけを変更し、保存キー(SV内の名前)は v1.0.0 から変えていない。
local CB = CombatBar
local WM = WINDOW_MANAGER
local T = CB.T

local SV, defaults
local selectedWidget, selectedSkill
local skillNames, skillIds, widgetIds = {}, {}, {}

local function CurrentSkill()
    return selectedSkill or skillNames[1]
end

local function Preview()
    if CB.RefreshPreview then CB.RefreshPreview() end
end

local function ApplyAll()
    CB.RefreshSlots()
    CB.ApplyLayout()
    CB.RebuildWidgets()
    CB.UpdateQuickslot()
    CB.UpdateDisplay()
    Preview()
end

local function Desc(key)
    return { type = "description", text = T(key) }
end

local function Check(nameKey, key, after)
    return {
        type = "checkbox", name = T(nameKey), default = defaults[key],
        getFunc = function() return SV[key] end,
        setFunc = function(v) SV[key] = v; if after then after() end; Preview() end,
    }
end

local function Slider(nameKey, key, min, max, step, after)
    return {
        type = "slider", name = T(nameKey), min = min, max = max, step = step or 1, default = defaults[key],
        getFunc = function() return SV[key] end,
        setFunc = function(v) SV[key] = v; if after then after() end; Preview() end,
    }
end

local function Color(nameKey, key, after)
    return {
        type = "colorpicker", name = T(nameKey),
        getFunc = function() local c = SV[key]; return c[1], c[2], c[3], c[4] end,
        setFunc = function(r, g, b, a)
            local old = SV[key]
            SV[key] = { r, g, b, (old and old[4]) and a or nil }
            if after then after() end
            Preview()
        end,
    }
end

---------------------------------------------------------------
-- HP・MP・ST(3本それぞれ独立)
---------------------------------------------------------------
local function ResControls(kind, headerKey)
    local function cfg() return SV.resources[kind] end
    local function def(key) return defaults.resources[kind][key] end
    local function Apply() CB.ApplyResources(); Preview() end

    local function RCheck(nameKey, key)
        return {
            type = "checkbox", name = T(nameKey), default = def(key),
            getFunc = function() return cfg()[key] end,
            setFunc = function(v) cfg()[key] = v; Apply() end,
        }
    end
    local function RSlider(nameKey, key, min, max)
        return {
            type = "slider", name = T(nameKey), min = min, max = max, step = 1, default = def(key),
            getFunc = function() return cfg()[key] end,
            setFunc = function(v) cfg()[key] = v; Apply() end,
        }
    end
    local function RColor(nameKey, key)
        return {
            type = "colorpicker", name = T(nameKey),
            getFunc = function() local c = cfg()[key]; return c[1], c[2], c[3], c[4] end,
            setFunc = function(r, g, b, a)
                local old = cfg()[key]
                cfg()[key] = { r, g, b, (old and old[4]) and a or nil }
                Apply()
            end,
        }
    end

    return {
        { type = "header", name = T(headerKey) },
        RCheck("RES_SHOW", "enabled"),
        RSlider("RES_X", "x", -1500, 1500),
        RSlider("RES_Y", "y", -1000, 1000),
        RSlider("RES_W", "w", 60, 600),
        RSlider("RES_H", "h", 8, 80),
        RColor("RES_COLOR", "color"),
        RColor("RES_BG", "bgColor"),
        RSlider("RES_ALPHA", "alpha", 10, 100),
        RCheck("RES_VALUE", "showValue"),
        RCheck("RES_PERCENT", "showPercent"),
        RCheck("RES_LABEL", "showLabel"),
        RSlider("RES_FONT", "fontSize", 10, 36),
    }
end

---------------------------------------------------------------
-- スキル一覧
---------------------------------------------------------------
local function SlottedSkills()
    local names, ids, seen = {}, {}, {}
    for _, hb in ipairs({ CB.HB_FRONT, CB.HB_BACK }) do
        for slot = CB.FIRST_SLOT, CB.ULT_SLOT do
            local id = CB.slotIds[hb][slot] or 0
            if id > 0 and not seen[id] then
                seen[id] = true
                local name = zo_strformat("<<1>>", GetAbilityName(id))
                names[#names + 1] = name
                ids[name] = id
            end
        end
    end
    return names, ids
end

local function WidgetNames()
    local names, ids = {}, {}
    for id in pairs(SV.widgets) do
        local name = zo_strformat("<<1>>", GetAbilityName(id))
        names[#names + 1] = name
        ids[name] = id
    end
    if #names == 0 then names[1] = T("WIDGET_NONE") end
    return names, ids
end

local function WidgetField(field, fallback)
    local cfg = selectedWidget and SV.widgets[selectedWidget]
    return cfg and cfg[field] or fallback
end

local function SetWidgetField(field, v)
    local cfg = selectedWidget and SV.widgets[selectedWidget]
    if cfg then
        cfg[field] = v
        CB.RebuildWidgets()
        Preview()
    end
end

local function UpdateDropdown(ref, names)
    local dd = WM:GetControlByName(ref)
    if dd and dd.UpdateChoices then dd:UpdateChoices(names) end
end

---------------------------------------------------------------
-- メニュー本体
---------------------------------------------------------------
function CB.BuildMenu(sv)
    SV, defaults = sv, CB.defaults
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panel = {
        type = "panel", name = T("PANEL_NAME"), displayName = T("PANEL_NAME"),
        author = "private", version = CB.version, registerForRefresh = true, registerForDefaults = false,
    }
    local panelRef = LAM:RegisterAddonPanel("CombatBarPanel", panel)

    -- スロット情報は読み込み時には未確定なので、画面を開いた時に一覧を更新する
    CB.RefreshMenuChoices = function()
        CB.RefreshSlots()
        local names, ids = SlottedSkills()
        skillNames, skillIds = names, ids
        UpdateDropdown("CB_EffectSkillDropdown", names)
        UpdateDropdown("CB_AddSkillDropdown", names)
    end

    -- 設定画面を開いている間だけプレビューを出す
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(openedPanel)
            if openedPanel == panelRef then
                if CB.RefreshMenuChoices then CB.RefreshMenuChoices() end
                CB.PreviewShow()
            end
        end)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(closedPanel)
            if closedPanel == panelRef then CB.PreviewHide() end
        end)
    end

    local widgetNames
    widgetNames, widgetIds = WidgetNames()
    local addSkill

    local effectValue = {
        type = "editbox", name = T("EFFID_VALUE"), isMultiline = false,
        getFunc = function()
            local id = CurrentSkill() and skillIds[CurrentSkill()]
            return tostring((id and SV.effectOverride[id]) or "")
        end,
        setFunc = function(text)
            local id = CurrentSkill() and skillIds[CurrentSkill()]
            local n = tonumber(text)
            if id and n and n > 0 then
                SV.effectOverride[id] = zo_floor(n)
                CB.RefreshSlots()
                CB.SyncPlayerBuffs()
            end
        end,
    }
    if TEXT_TYPE_NUMERIC then effectValue.textType = TEXT_TYPE_NUMERIC end

    local resControls = {}
    resControls[#resControls + 1] = Desc("D_RES")
    for _, kind in ipairs(CB.ResourceKinds) do
        local list = ResControls(kind, "RES_" .. string.upper(kind))
        for _, c in ipairs(list) do resControls[#resControls + 1] = c end
    end

    local options = {
        { type = "submenu", name = T("SUB_GENERAL"), controls = {
            Desc("D_GENERAL"),
            Check("ENABLE_ALL", "enabled", ApplyAll),
            {
                type = "dropdown", name = T("LANGUAGE"),
                choices = { T("LANG_AUTO"), T("LANG_JP"), T("LANG_EN") }, choicesValues = { "auto", "jp", "en" },
                getFunc = function() return SV.language end,
                setFunc = function(v) SV.language = v end,
                warning = T("RELOAD_NOTE"),
            },
            Slider("PREVIEW_X", "previewX", 0, 2000, 1),
            Slider("PREVIEW_Y", "previewY", 0, 1000, 1),
        } },

        { type = "submenu", name = T("SUB_RES"), controls = resControls },

        { type = "submenu", name = T("SUB_BARS"), controls = {
            Desc("D_BARS"),
            Check("SHOW_FRONT", "showFront", CB.UpdateDisplay),
            Check("SHOW_BACK", "showBack", CB.RefreshIcons),
            Slider("BACK_X", "backOffsetX", -300, 300, 1, CB.ApplyLayout),
            Slider("BACK_Y", "backOffsetY", -300, 300, 1, CB.ApplyLayout),
            Slider("BACK_SCALE", "backScale", 40, 150, 1, CB.ApplyLayout),
            Slider("INACTIVE_ALPHA", "inactiveAlpha", 0, 100, 1, CB.RefreshIcons),
            Slider("INACTIVE_DESAT", "inactiveDesat", 0, 100, 1, CB.RefreshIcons),
            Check("MANAGE_STD", "manageStandardBar", CB.ApplyLayout),
            Slider("STD_X", "stdOffsetX", -600, 600, 1, CB.ApplyLayout),
            Slider("STD_Y", "stdOffsetY", -600, 600, 1, CB.ApplyLayout),
        } },

        { type = "submenu", name = T("SUB_TIMER"), controls = {
            Desc("D_TIMER"),
            Slider("DUR_MIN", "durationMin", 0, 30, 1),
            Slider("DUR_MAX", "durationMax", 10, 600, 1),
            Slider("TIMER_SIZE", "timerSize", 10, 40, 1, CB.ApplyLayout),
            Slider("DECIMAL_BELOW", "decimalBelow", 0, 10, 1, CB.UpdateDisplay),
            Slider("EXPIRE_START", "expireStart", 0, 10, 1, CB.UpdateDisplay),
            Color("TIMER_COLOR", "timerColor", CB.UpdateDisplay),
            Color("EXPIRE_COLOR", "expireColor", CB.UpdateDisplay),
            Check("STACK_SHOW", "showStacks", CB.UpdateDisplay),
            Slider("STACK_SIZE", "stackSize", 10, 36, 1, CB.ApplyLayout),
            Color("STACK_COLOR", "stackColor", CB.UpdateDisplay),
            Check("HL_SHOW", "showHighlight", CB.UpdateDisplay),
            Color("HL_COLOR", "highlightColor", CB.UpdateDisplay),
            Check("HL_EXPIRE", "highlightExpire", CB.UpdateDisplay),
            Color("HL_EXPIRE_COLOR", "highlightExpireColor", CB.UpdateDisplay),
        } },

        { type = "submenu", name = T("SUB_ULT"), controls = {
            Desc("D_ULT"),
            Check("ULT_VALUE", "ultShowValue", CB.UpdateDisplay),
            {
                type = "dropdown", name = T("ULT_MODE"),
                choices = { T("ULT_MODE1"), T("ULT_MODE2"), T("ULT_MODE3") }, choicesValues = { 1, 2, 3 },
                getFunc = function() return SV.ultValueMode end,
                setFunc = function(v) SV.ultValueMode = v; CB.UpdateDisplay(); Preview() end,
            },
            Slider("ULT_SIZE", "ultSize", 10, 40, 1, CB.ApplyLayout),
            Color("ULT_COLOR", "ultColor", CB.UpdateDisplay),
            Color("ULT_USABLE_COLOR", "ultUsableColor", CB.UpdateDisplay),
            Check("ULT_DURATION", "ultShowDuration", CB.UpdateDisplay),
        } },

        { type = "submenu", name = T("SUB_QS"), controls = {
            Desc("D_QS"),
            Check("QS_TIMER", "qsShowTimer", CB.UpdateQuickslot),
            Check("QS_COUNT", "qsShowCount", CB.UpdateQuickslot),
            Slider("QS_SIZE", "qsSize", 10, 40, 1, CB.ApplyLayout),
        } },

        { type = "submenu", name = T("SUB_CAST"), controls = {
            Desc("D_CAST"),
            Check("CAST_SHOW", "showCast"),
            Color("CAST_COLOR", "castColor", CB.UpdateDisplay),
        } },

        { type = "submenu", name = T("SUB_GCD"), controls = {
            Desc("D_GCD"),
            Check("GCD_ENABLE", "gcdEnabled", CB.ApplyLayout),
            Slider("GCD_X", "gcdX", 0, 3840, 1, CB.ApplyLayout),
            Slider("GCD_Y", "gcdY", 0, 2160, 1, CB.ApplyLayout),
            Slider("GCD_W", "gcdW", 2, 100, 1, CB.ApplyLayout),
            Slider("GCD_H", "gcdH", 10, 400, 1, CB.ApplyLayout),
            Color("GCD_COLOR", "gcdColor", CB.ApplyLayout),
        } },

        { type = "submenu", name = T("SUB_WIDGET"), controls = {
            Desc("D_WIDGET"),
            {
                type = "dropdown", name = T("WIDGET_ADD_SKILL"), reference = "CB_AddSkillDropdown",
                choices = {},
                getFunc = function() return addSkill or skillNames[1] end,
                setFunc = function(v) addSkill = v end,
            },
            {
                type = "button", name = T("WIDGET_ADD"),
                func = function()
                    local pick = addSkill or skillNames[1]
                    local id = pick and skillIds[pick]
                    if id and not SV.widgets[id] then
                        SV.widgets[id] = { x = 800, y = 600, size = 64, inactiveAlpha = 0 }
                        selectedWidget = id
                        CB.RebuildWidgets()
                        local names, ids = WidgetNames()
                        widgetIds = ids
                        UpdateDropdown("CB_WidgetDropdown", names)
                        Preview()
                    end
                end,
            },
            {
                type = "dropdown", name = T("WIDGET_EDIT"), reference = "CB_WidgetDropdown",
                choices = widgetNames,
                getFunc = function()
                    if selectedWidget and SV.widgets[selectedWidget] then
                        return zo_strformat("<<1>>", GetAbilityName(selectedWidget))
                    end
                    return widgetNames[1]
                end,
                setFunc = function(v) selectedWidget = widgetIds[v] end,
            },
            {
                type = "slider", name = T("WIDGET_X"), min = 0, max = 3840, step = 1, default = 800,
                getFunc = function() return WidgetField("x", 800) end,
                setFunc = function(v) SetWidgetField("x", v) end,
            },
            {
                type = "slider", name = T("WIDGET_Y"), min = 0, max = 2160, step = 1, default = 600,
                getFunc = function() return WidgetField("y", 600) end,
                setFunc = function(v) SetWidgetField("y", v) end,
            },
            {
                type = "slider", name = T("WIDGET_SIZE"), min = 24, max = 160, step = 1, default = 64,
                getFunc = function() return WidgetField("size", 64) end,
                setFunc = function(v) SetWidgetField("size", v) end,
            },
            {
                type = "slider", name = T("WIDGET_INACTIVE"), min = 0, max = 100, step = 1, default = 0,
                getFunc = function() return WidgetField("inactiveAlpha", 0) end,
                setFunc = function(v) SetWidgetField("inactiveAlpha", v) end,
            },
            {
                type = "button", name = T("WIDGET_REMOVE"),
                func = function()
                    if selectedWidget then
                        SV.widgets[selectedWidget] = nil
                        selectedWidget = nil
                        CB.RebuildWidgets()
                        local names, ids = WidgetNames()
                        widgetIds = ids
                        UpdateDropdown("CB_WidgetDropdown", names)
                        Preview()
                    end
                end,
            },
        } },

        { type = "submenu", name = T("SUB_EFFECTID"), controls = {
            Desc("D_EFFID"),
            {
                type = "dropdown", name = T("EFFID_SKILL"), reference = "CB_EffectSkillDropdown",
                choices = {},
                getFunc = function() return CurrentSkill() end,
                setFunc = function(v) selectedSkill = v end,
            },
            effectValue,
            {
                type = "button", name = T("EFFID_CLEAR"),
                func = function()
                    local id = CurrentSkill() and skillIds[CurrentSkill()]
                    if id then
                        SV.effectOverride[id] = nil
                        CB.RefreshSlots()
                        CB.SyncPlayerBuffs()
                    end
                end,
            },
            {
                type = "button", name = T("EFFID_REFRESH"),
                func = function() CB.RefreshMenuChoices() end,
            },
        } },

        { type = "submenu", name = T("SUB_DESIGN"), controls = {
            Desc("D_DESIGN"),
            Check("DESIGN_FRAME", "designFrame", ApplyAll),
            Slider("DESIGN_GLOW", "designGlow", 0, 100, 1, CB.ApplyResources),
        } },

        { type = "submenu", name = T("SUB_PRESET"), controls = {
            Desc("D_PRESET"),
            {
                type = "button", name = T("PRESET_PVE"),
                func = function()
                    for k, v in pairs(CB.presets.pve) do SV[k] = v end
                    ApplyAll()
                    d(T("PRESET_DONE"))
                end,
            },
            {
                type = "button", name = T("PRESET_PVP"),
                func = function()
                    for k, v in pairs(CB.presets.pvp) do SV[k] = v end
                    ApplyAll()
                    d(T("PRESET_DONE"))
                end,
            },
            {
                type = "button", name = T("RESET_ALL"), warning = T("RESET_ALL"),
                func = function()
                    for k in pairs(SV) do SV[k] = nil end
                    local fresh = CB.DeepCopy(CB.defaults)
                    for k, v in pairs(fresh) do SV[k] = v end
                    selectedWidget, selectedSkill = nil, nil
                    ApplyAll()
                    d(T("RESET_DONE"))
                end,
            },
        } },
    }

    LAM:RegisterOptionControls("CombatBarPanel", options)
end
