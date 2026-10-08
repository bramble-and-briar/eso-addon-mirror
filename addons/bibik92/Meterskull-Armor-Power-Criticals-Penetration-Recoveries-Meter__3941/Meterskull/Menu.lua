--------------------------------------------------------------------------------
-- LIBADDONMENU2 CONFIGURATION
--------------------------------------------------------------------------------
local LAM2 = LibAddonMenu2

--------------------------------------------------------------------------------
-- MODULE INITIALIZATION (called from Meterskull.lua)
--------------------------------------------------------------------------------
local function InitializeMenu(MS)
    if not MS then return end

    --------------------------------------------------------------------------------
    -- DONATION FUNCTION
    --------------------------------------------------------------------------------
    function MS.Donate()
        SCENE_MANAGER:Show('mailSend')
        zo_callLater(function()
            if ZO_MailSendToField then
                ZO_MailSendToField:SetText("@bibik92")
            end
            if ZO_MailSendSubjectField then
                ZO_MailSendSubjectField:SetText("Donation for Meterskull")
            end
            if ZO_MailSendBodyField then
                ZO_MailSendBodyField:SetText("Thank you for considering donating to the development of this project")
                ZO_MailSendBodyField:TakeFocus()
            end
        end, 250)
    end

    --------------------------------------------------------------------------------
    -- BUILD MENU FUNCTION
    --------------------------------------------------------------------------------
    function MS.BuildMenu()
    local optionsData = {}

    optionsData[#optionsData + 1] = {
        type = "description",
        text = "|cd9d9d9Meterskull is an advanced real-time UI meter for Armor, Power Damage, Critical Chance/Damage/Resistance, Penetration and Recoveries.|r"
    }

    optionsData[#optionsData + 1] = {
        type    = "checkbox",
        name    = "Account-wide Settings",
        tooltip = "Use the same settings for all characters on this megaserver. Reload required.",
        getFunc = function()
            return MS.accountDb.sharedSettings.accountWideSettings
        end,
        setFunc = function(value)
            if value == MS.accountDb.sharedSettings.accountWideSettings then
                return
            end
            MS.accountDb.sharedSettings.accountWideSettings = value
            if value then
                MS.db = MS.accountDb
            else
                MS.db = ZO_SavedVars:NewCharacterIdSettings("MeterskullSettings", 1, nil, MS.defaults, GetWorldName())
            end
            ReloadUI()
        end,
        default = MS.defaults.sharedSettings.accountWideSettings,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = "UI Locked",
        tooltip = "Lock or unlock the UI elements.",
        getFunc = function() return MS.db.sharedSettings.uiLocked end,
        setFunc = function(value)
            MS.db.sharedSettings.uiLocked = value
        end,
        default = MS.defaults.sharedSettings.uiLocked,
    }

    optionsData[#optionsData + 1] = {
        type = "checkbox",
        name = "Show Only During Combat",
        tooltip = "Show enabled UI modules during combat, then wait 5 seconds before fading them out. When disabled, they are also shown out of combat. Previews remain visible without fades in this settings panel.",
        getFunc = function() return MS.db.sharedSettings.combatOnly end,
        setFunc = function(value)
            MS.db.sharedSettings.combatOnly = value
            MS.CancelCombatHideCooldown()
            if _G.Meterskull_UpdateUIVisibility then
                _G.Meterskull_UpdateUIVisibility()
            end
        end,
        default = MS.defaults.sharedSettings.combatOnly,
    }

    -- Helper: toggle module + update LAM2 preview directly (fragment system does not
    -- affect controls during LAM2 preview since the scene is not "hud"/"hudui").
    local function ToggleModule(mod, value)
        mod:ToggleVisibility(value)
        if mod.uiRefs and mod.uiRefs.main then
            local sceneName = SCENE_MANAGER:GetCurrentScene() and SCENE_MANAGER:GetCurrentScene():GetName()
            local inLAMPreview = (sceneName ~= "hud" and sceneName ~= "hudui")
            if inLAMPreview then
                mod.uiRefs.main:SetHidden(not value)
            end
        end
    end

    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "|ceea92cModules|r",
        controls = {
            { type = "checkbox", name = "Show Armor UI",              getFunc = function() return MS.db.sharedSettings.showArmorskull       end, setFunc = function(value) ToggleModule(MS.modules.armorskull,       value) end, default = MS.defaults.sharedSettings.showArmorskull },
            { type = "checkbox", name = "Show Hybrid Armor UI",       getFunc = function() return MS.db.sharedSettings.showHybridarmorskull end, setFunc = function(value) ToggleModule(MS.modules.hybridarmorskull, value) end, default = MS.defaults.sharedSettings.showHybridarmorskull },
            { type = "checkbox", name = "Show Power UI",              getFunc = function() return MS.db.sharedSettings.showPowerskull       end, setFunc = function(value) ToggleModule(MS.modules.powerskull,       value) end, default = MS.defaults.sharedSettings.showPowerskull },
            { type = "checkbox", name = "Show Criticals UI",          getFunc = function() return MS.db.sharedSettings.showCritskull        end, setFunc = function(value) ToggleModule(MS.modules.critskull,        value) end, default = MS.defaults.sharedSettings.showCritskull },
            { type = "checkbox", name = "Show Critical Resistance UI", getFunc = function() return MS.db.sharedSettings.showCritresiskull   end, setFunc = function(value) ToggleModule(MS.modules.critresiskull,   value) end, default = MS.defaults.sharedSettings.showCritresiskull },
            { type = "checkbox", name = "Show Penetration UI",        getFunc = function() return MS.db.sharedSettings.showPenskull         end, setFunc = function(value) ToggleModule(MS.modules.penskull,         value) end, default = MS.defaults.sharedSettings.showPenskull },
            { type = "checkbox", name = "Show Health Recovery UI",    getFunc = function() return MS.db.sharedSettings.showHealthskull      end, setFunc = function(value) ToggleModule(MS.modules.healthskull,      value) end, default = MS.defaults.sharedSettings.showHealthskull },
            { type = "checkbox", name = "Show Magicka Recovery UI",   getFunc = function() return MS.db.sharedSettings.showMagskull         end, setFunc = function(value) ToggleModule(MS.modules.magskull,         value) end, default = MS.defaults.sharedSettings.showMagskull },
            { type = "checkbox", name = "Show Stamina Recovery UI",   getFunc = function() return MS.db.sharedSettings.showStamskull        end, setFunc = function(value) ToggleModule(MS.modules.stamskull,        value) end, default = MS.defaults.sharedSettings.showStamskull },
        },
    }

    -- Extra Settings
    optionsData[#optionsData + 1] = { type = "header", name = "|c40e080Settings|r" }

    optionsData[#optionsData + 1] = {
        type = "dropdown",
        name = "Animation Duration",
        tooltip = "Set the speed of animations for all modules",
        choices = { "Fast", "Standard", "Slow", "Off" },
        choicesValues = { "fast", "standard", "slow", "off" },
        getFunc = function()
            return MS.db.sharedSettings.animationDuration
        end,
        setFunc = function(value)
            MS.db.sharedSettings.animationDuration = value
        end,
        default = "standard",
    }

    -- Background Colors
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "Background Colors",
        controls = {
            { type = "description", text = [[|cd9d9d9Configure the background color and transparency for each UI module.|r ]] },
            { type = "colorpicker", name = "Armor UI Color", getFunc = function() return unpack(MS.db.armorskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.armorskull.settings.backgroundColor={r,g,b,a}; if MS.modules.armorskull.uiRefs then MS.modules.armorskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.armorskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Hybrid Armor UI Color", getFunc = function() return unpack(MS.db.hybridarmorskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.hybridarmorskull.settings.backgroundColor={r,g,b,a}; if MS.modules.hybridarmorskull.uiRefs then MS.modules.hybridarmorskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.hybridarmorskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Power UI Color", getFunc = function() return unpack(MS.db.powerskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.powerskull.settings.backgroundColor={r,g,b,a}; if MS.modules.powerskull.uiRefs then MS.modules.powerskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.powerskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Criticals UI Color", getFunc = function() return unpack(MS.db.critskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.critskull.settings.backgroundColor={r,g,b,a}; if MS.modules.critskull.uiRefs then MS.modules.critskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.critskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Critical Resistance UI Color", getFunc = function() return unpack(MS.db.critresiskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.critresiskull.settings.backgroundColor={r,g,b,a}; if MS.modules.critresiskull.uiRefs then MS.modules.critresiskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.critresiskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Penetration UI Color", getFunc = function() return unpack(MS.db.penskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.penskull.settings.backgroundColor={r,g,b,a}; if MS.modules.penskull.uiRefs then MS.modules.penskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.penskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Health Recovery UI Color", getFunc = function() return unpack(MS.db.healthskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.healthskull.settings.backgroundColor={r,g,b,a}; if MS.modules.healthskull.uiRefs then MS.modules.healthskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.healthskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Magicka Recovery UI Color", getFunc = function() return unpack(MS.db.magskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.magskull.settings.backgroundColor={r,g,b,a}; if MS.modules.magskull.uiRefs then MS.modules.magskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.magskull.settings.backgroundColor)} },
            { type = "colorpicker", name = "Stamina Recovery UI Color", getFunc = function() return unpack(MS.db.stamskull.settings.backgroundColor) end, setFunc = function(r,g,b,a) MS.db.stamskull.settings.backgroundColor={r,g,b,a}; if MS.modules.stamskull.uiRefs then MS.modules.stamskull.uiRefs.bg:SetCenterColor(r,g,b,a) end end, default={unpack(MS.defaults.stamskull.settings.backgroundColor)} },
        },
    }

    -- Border and Text Opacity
    local opacityModules = {
        { key = "armorskull",       name = "Armor UI" },
        { key = "hybridarmorskull", name = "Hybrid Armor UI" },
        { key = "powerskull",       name = "Power UI" },
        { key = "critskull",        name = "Criticals UI" },
        { key = "critresiskull",    name = "Critical Resistance UI" },
        { key = "penskull",         name = "Penetration UI" },
        { key = "healthskull",      name = "Health Recovery UI" },
        { key = "magskull",         name = "Magicka Recovery UI" },
        { key = "stamskull",        name = "Stamina Recovery UI" },
    }

    local function MakeOpacityControls(settingKey, description, tooltip)
        local controls = {
            { type = "description", text = "|cd9d9d9" .. description .. "|r" },
        }
        for _, moduleInfo in ipairs(opacityModules) do
            local key = moduleInfo.key
            controls[#controls + 1] = {
                type = "slider",
                name = moduleInfo.name .. " Opacity (%)",
                tooltip = tooltip,
                min = 0, max = 100, step = 1,
                getFunc = function() return MS.db[key].settings[settingKey] end,
                setFunc = function(value)
                    MS.db[key].settings[settingKey] = value
                    if MS.modules[key] then MS.modules[key]:ApplyOpacity() end
                end,
                default = MS.defaults[key].settings[settingKey],
            }
        end
        return controls
    end

    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "Border Opacity",
        controls = MakeOpacityControls("borderOpacity",
            "Adjust the border opacity for each UI module (Default = 50%). Set to 0% to hide the border.",
            "Border opacity from 0% (invisible) to 100% (fully opaque). Does not affect the background or text."),
    }

    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "Text Opacity",
        controls = MakeOpacityControls("textOpacity",
            "Adjust the opacity of numbers and labels for each UI module (Default = 100%).",
            "Numbers and labels opacity from 0% (invisible) to 100% (original opacity). Applied together with existing color transparency."),
    }

    -- Custom Scales
    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "Custom Scales",
        controls = {
            {
                type = "description",
                text = [[|cd9d9d9Adjust the display size of each UI module by setting a custom scale percentage (Default = 20%).|r]]
            },
            { type = "slider", name = "Armor UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.armorskull.settings.customScale end,
              setFunc = function(v) MS.db.armorskull.settings.customScale = v; if MS.modules.armorskull then MS.modules.armorskull:CustomScale(v) end end,
              default = MS.defaults.armorskull.settings.customScale },
            { type = "slider", name = "Hybrid Armor UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.hybridarmorskull.settings.customScale end,
              setFunc = function(v) MS.db.hybridarmorskull.settings.customScale = v; if MS.modules.hybridarmorskull then MS.modules.hybridarmorskull:CustomScale(v) end end,
              default = MS.defaults.hybridarmorskull.settings.customScale },
            { type = "slider", name = "Power UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.powerskull.settings.customScale end,
              setFunc = function(v) MS.db.powerskull.settings.customScale = v; if MS.modules.powerskull then MS.modules.powerskull:CustomScale(v) end end,
              default = MS.defaults.powerskull.settings.customScale },
            { type = "slider", name = "Criticals UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.critskull.settings.customScale end,
              setFunc = function(v) MS.db.critskull.settings.customScale = v; if MS.modules.critskull then MS.modules.critskull:CustomScale(v) end end,
              default = MS.defaults.critskull.settings.customScale },
            { type = "slider", name = "Critical Resistance UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.critresiskull.settings.customScale end,
              setFunc = function(v) MS.db.critresiskull.settings.customScale = v; if MS.modules.critresiskull then MS.modules.critresiskull:CustomScale(v) end end,
              default = MS.defaults.critresiskull.settings.customScale },
            { type = "slider", name = "Penetration UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.penskull.settings.customScale end,
              setFunc = function(v) MS.db.penskull.settings.customScale = v; if MS.modules.penskull then MS.modules.penskull:CustomScale(v) end end,
              default = MS.defaults.penskull.settings.customScale },
            { type = "slider", name = "Health Recovery UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.healthskull.settings.customScale end,
              setFunc = function(v) MS.db.healthskull.settings.customScale = v; if MS.modules.healthskull then MS.modules.healthskull:CustomScale(v) end end,
              default = MS.defaults.healthskull.settings.customScale },
            { type = "slider", name = "Magicka Recovery UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.magskull.settings.customScale end,
              setFunc = function(v) MS.db.magskull.settings.customScale = v; if MS.modules.magskull then MS.modules.magskull:CustomScale(v) end end,
              default = MS.defaults.magskull.settings.customScale },
            { type = "slider", name = "Stamina Recovery UI Scale", min = 0, max = 100, step = 1,
              getFunc = function() return MS.db.stamskull.settings.customScale end,
              setFunc = function(v) MS.db.stamskull.settings.customScale = v; if MS.modules.stamskull then MS.modules.stamskull:CustomScale(v) end end,
              default = MS.defaults.stamskull.settings.customScale },
        },
    }

    -- Color Alert Notifications
    optionsData[#optionsData + 1] = { type = "header", name = "|c40e080Color Alert Notifications|r" }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = [[|cd9d9d9Set a threshold and color for Resistances, Power, Criticals, Penetration, Recoveries. If your stat meets or exceeds the threshold, the color applies.|r]]
    }

    local function MakeAlertsSubmenu(prefix, tableRef, defaultRef)
        local controls = {}
        for i = 1, #defaultRef do
            controls[#controls + 1] = {
                type = "editbox",
                name = prefix .. " Level #" .. i,
                tooltip = prefix .. " level for threshold #" .. i,
                getFunc = function() return tostring(tableRef[i].level) end,
                setFunc = function(value)
                    local numericValue = tonumber(value) or 0
                    tableRef[i].level = numericValue
                end,
                default = tostring(defaultRef[i].level),
                width = "half",
            }
            controls[#controls + 1] = {
                type = "colorpicker",
                name = prefix .. " Color #" .. i,
                tooltip = "Color for threshold #" .. i,
                getFunc = function() return unpack(tableRef[i].color) end,
                setFunc = function(r, g, b, a) tableRef[i].color = { r, g, b, a } end,
                default = { unpack(defaultRef[i].color) },
                width = "half",
            }
        end
        return controls
    end

    optionsData[#optionsData + 1] = {
        type = "submenu",
        name = "Color Alert Settings",
        controls = {
            { type = "submenu", name = "Physical Resist (|cB2B2B2Armor UI|r)", reference="Physical_Resistance_Options_Submenu", controls = MakeAlertsSubmenu("Physical Resist", MS.db.armorskull.settings.levels.physical, MS.defaults.armorskull.settings.levels.physical) },
            { type = "submenu", name = "Spell Resist (|cB2B2B2Armor UI|r)",    reference="Spell_Resistance_Options_Submenu",  controls = MakeAlertsSubmenu("Spell Resist",    MS.db.armorskull.settings.levels.spell,    MS.defaults.armorskull.settings.levels.spell) },
            { type = "submenu", name = "Lowest Resist (|cB2B2B2Hybrid Armor UI|r)", reference="Hybrid_Resist_Options_Submenu", controls = MakeAlertsSubmenu("Lowest Resist", MS.db.hybridarmorskull.settings.levels.lowestResist, MS.defaults.hybridarmorskull.settings.levels.lowestResist) },
            { type = "submenu", name = "Power (|cB2B2B2Power UI|r)",           reference="Power_Options_Submenu",           controls = MakeAlertsSubmenu("Power",           MS.db.powerskull.settings.levels.power,           MS.defaults.powerskull.settings.levels.power) },
            { type = "submenu", name = "Critical Chance (|cB2B2B2Criticals UI|r)", reference="Crit_Chance_Options_Submenu", controls = MakeAlertsSubmenu("Crit Chance", MS.db.critskull.settings.levels.critChance, MS.defaults.critskull.settings.levels.critChance) },
            { type = "submenu", name = "Critical Damage (|cB2B2B2Criticals UI|r)", reference="Crit_Damage_Options_Submenu", controls = MakeAlertsSubmenu("Crit Damage", MS.db.critskull.settings.levels.critDamage, MS.defaults.critskull.settings.levels.critDamage) },
            { type = "submenu", name = "Critical Resistance (|cB2B2B2Critical Resistance UI|r)",reference="Crit_Resistance_Options_Submenu", controls = MakeAlertsSubmenu("Critical Resistance", MS.db.critresiskull.settings.levels.critResist, MS.defaults.critresiskull.settings.levels.critResist) },
            { type = "submenu", name = "Penetration (|cB2B2B2Penetration UI|r)", reference="Penetration_Options_Submenu", controls = MakeAlertsSubmenu("Penetration", MS.db.penskull.settings.levels.penetration, MS.defaults.penskull.settings.levels.penetration) },
            { type = "submenu", name = "Health Recovery (|cB2B2B2Health UI|r)",  reference="Health_Recovery_Options_Submenu",  controls = MakeAlertsSubmenu("Health Recovery", MS.db.healthskull.settings.levels.recovery, MS.defaults.healthskull.settings.levels.recovery) },
            { type = "submenu", name = "Magicka Recovery (|cB2B2B2Magicka UI|r)",reference="Magicka_Recovery_Options_Submenu", controls = MakeAlertsSubmenu("Magicka Recovery", MS.db.magskull.settings.levels.recovery, MS.defaults.magskull.settings.levels.recovery) },
            { type = "submenu", name = "Stamina Recovery (|cB2B2B2Stamina UI|r)",reference="Stamina_Recovery_Options_Submenu", controls = MakeAlertsSubmenu("Stamina Recovery", MS.db.stamskull.settings.levels.recovery, MS.defaults.stamskull.settings.levels.recovery) },
        },
    }

    optionsData[#optionsData + 1] = { type = "header", name = "|c40e080Performance|r" }
    optionsData[#optionsData + 1] = {
        type = "description",
        text = [[|cd9d9d9Milliseconds for the loop that re-renders the meter values. Larger is less frequent updates.|r]]
    }
    optionsData[#optionsData + 1] = {
        type = "slider",
        name = "Render Interval (Default: 1000ms)",
        min = 500, max = 2000, step = 50,
        getFunc = function() return MS.db.sharedSettings.renderTick end,
        setFunc = function(value)
            MS.db.sharedSettings.renderTick = value
            for _, mod in pairs(MS.modules) do
                mod:UpdateRenderTick()
            end
        end,
        default = MS.defaults.sharedSettings.renderTick,
    }

    local panelData = {
        type    = "panel",
        name    = "Meter|cB2B2B2skull|r",
        author  = "|cCCFF00bibik92|r",
        version = MS.version,
        feedback = "https://www.esoui.com/downloads/info3941-MeterskullArmorPowerCriticalsPenetrationRecoveriesMeter.html",
        donation = MS.Donate,
    }
    local myPanel = LAM2:RegisterAddonPanel("MeterskullOptions", panelData)
    LAM2:RegisterOptionControls("MeterskullOptions", optionsData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
        if panel == myPanel then
            _G.Meterskull_OnLAMPanelOpened()
        else
            MS.lamPreviewActive = false
            if MS_ArmorskullUI then MS_ArmorskullUI:SetHidden(true) end
            if MS_HybridarmorskullUI then MS_HybridarmorskullUI:SetHidden(true) end
            if MS_PowerskullUI then MS_PowerskullUI:SetHidden(true) end
            if MS_CritskullUI then MS_CritskullUI:SetHidden(true) end
            if MS_PenskullUI then MS_PenskullUI:SetHidden(true) end
            if MS_HealthskullUI then MS_HealthskullUI:SetHidden(true) end
            if MS_MagskullUI then MS_MagskullUI:SetHidden(true) end
            if MS_StamskullUI then MS_StamskullUI:SetHidden(true) end
            if MS_CritresiskullUI then MS_CritresiskullUI:SetHidden(true) end
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == myPanel then
            _G.Meterskull_OnLAMPanelClosed()
            zo_callLater(function()
                if _G.Meterskull_UpdateUIVisibility then
                    _G.Meterskull_UpdateUIVisibility()
                end
            end, 100)
        end
    end)
end
end  -- Close InitializeMenu function

_G.Meterskull_InitializeMenu = InitializeMenu
