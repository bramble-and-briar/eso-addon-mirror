-- Skillbound_Settings.lua : settings panel (LibAddonMenu-2.0, optional).

local B = Skillbound
local L = B.L

function B.OpenSettings()
    if B.settingsPanel then
        LibAddonMenu2:OpenToPanel(B.settingsPanel)
    else
        B.Print(L("NO_LAM"))
    end
end

local function Changed()
    B.callbacks:FireCallbacks("SettingsChanged")
end

local function Check(section, key, textKey, tipKey)
    return {
        type = "checkbox",
        name = L(textKey),
        tooltip = tipKey and L(tipKey) or nil,
        getFunc = function() return (section and B.sv[section] or B.sv)[key] end,
        setFunc = function(v)
            (section and B.sv[section] or B.sv)[key] = v
            Changed()
        end,
    }
end

-- auto repair / recharge (the same switches and sliders as on the Gear check page)
local function Fix(key, textKey, tipKey)
    return {
        type = "checkbox",
        name = L(textKey),
        tooltip = L(tipKey),
        getFunc = function() return B.sv.fix[key] == true end,
        setFunc = function(v)
            B.sv.fix[key] = v
            B.Fix.SettingsChanged()
            Changed()
        end,
    }
end

local function FixSlider(getter, setter, textKey, tipKey)
    return {
        type = "slider",
        name = L(textKey),
        tooltip = L(tipKey),
        min = B.Fix.MIN_AT, max = B.Fix.MAX_AT, step = 5,
        getFunc = getter,
        setFunc = function(v)
            setter(v)
            B.Fix.SettingsChanged()
            Changed()
        end,
    }
end

function B.InitSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end
    B.settingsPanel = LAM:RegisterAddonPanel("SkillboundSettings", {
        type = "panel",
        name = L("TITLE"),
        displayName = B.Colorize(B.COLOR.theme, L("TITLE")),
        author = "|c00C8FFbrianmit|r",   -- cyan, like Command Codex / Set Hunter / Questbound
        version = B.VERSION,
        registerForRefresh = true,
    })
    LAM:RegisterOptionControls("SkillboundSettings", {
        { type = "description", text = L("SET_INTRO") },

        {
            type = "dropdown",
            name = L("SET_ANIM"),
            tooltip = L("SET_ANIM_TT"),
            choices = { L("SET_ANIM_FULL"), L("SET_ANIM_SUBTLE"), L("SET_ANIM_OFF") },
            choicesValues = { "full", "subtle", "off" },
            getFunc = function() return B.sv.anim end,
            setFunc = function(v)
                B.sv.anim = v
                Changed()
            end,
        },

        -- (0.6.7 review: grouped by what you'd look for: wearing / food and dungeons / gear /
        -- repair / prebuff / the button)
        { type = "header", name = L("SET_HDR_WEAR") },
        Check(nil, "askWear", "SET_ASK_WEAR", "SET_ASK_WEAR_TT"),
        Check(nil, "showChanges", "CHANGES_ALWAYS", "CHANGES_ALWAYS_TT"),
        Check(nil, "announce", "SET_ANNOUNCE", "SET_ANNOUNCE_TT"),
        Check(nil, "quietSwap", "SET_QUIET", "SET_QUIET_TT"),

        { type = "header", name = L("SET_HDR_FOOD") },
        Check(nil, "eatFood", "SET_EAT", "SET_EAT_TT"),
        {
            type = "slider",
            name = L("SET_RENEW"),
            tooltip = L("SET_RENEW_TT"),
            min = 0, max = 30, step = 1,
            getFunc = function() return B.sv.foodRenewMin or 0 end,
            setFunc = function(v) B.sv.foodRenewMin = v end,
        },
        Check(nil, "readyCard", "SET_READY", "SET_READY_TT"),

        { type = "header", name = L("SET_HDR_GEAR") },
        Check(nil, "refillPoison", "SET_POISON", "SET_POISON_TT"),
        Check(nil, "marks", "SET_MARKS", "SET_MARKS_TT"),
        Check(nil, "lockGear", "SET_LOCK", "SET_LOCK_TT"),

        { type = "header", name = L("SET_HDR_FIX") },
        Fix("autoRepair", "FIX_AUTO_REPAIR", "FIX_AUTO_REPAIR_TT"),
        FixSlider(B.Fix.RepairAt, B.Fix.SetRepairAt, "FIX_AT_REPAIR", "FIX_AT_REPAIR_TT"),
        Fix("autoCharge", "FIX_AUTO_CHARGE", "FIX_AUTO_CHARGE_TT"),
        FixSlider(B.Fix.ChargeAt, B.Fix.SetChargeAt, "FIX_AT_CHARGE", "FIX_AT_CHARGE_TT"),

        { type = "header", name = L("SET_HDR_PREBUFF") },
        { type = "description", text = L("PRE_INFO_TT") },
        {
            type = "slider",
            name = L("SET_PRE_TIME"),
            tooltip = L("SET_PRE_TIME_TT"),
            min = 5, max = 30, step = 1,
            getFunc = function() return B.sv.prebuff.restoreAfter or 12 end,
            setFunc = function(v) B.sv.prebuff.restoreAfter = v end,
        },

        { type = "header", name = L("SET_HDR_BUTTON") },
        {
            type = "checkbox",
            name = L("SET_LAUNCHER"),
            tooltip = L("SET_LAUNCHER_TT"),
            getFunc = function() return not B.sv.launcher.hidden end,
            setFunc = function(v)
                B.sv.launcher.hidden = not v
                Changed()
            end,
        },
        Check("launcher", "combatHide", "SET_LAUNCHER_COMBAT", "SET_LAUNCHER_COMBAT_TT"),
        {
            type = "slider",
            name = L("SET_SLOTS"),
            tooltip = L("SET_SLOTS_TT"),
            min = 0, max = B.MAX_FAV, step = 1,
            getFunc = function() return B.sv.launcher.slots end,
            setFunc = function(v)
                B.sv.launcher.slots = v
                Changed()
            end,
        },
        {
            type = "colorpicker",
            name = L("SET_COLOR"),
            tooltip = L("SET_COLOR_TT"),
            getFunc = function() local c = B.sv.theme return c.r, c.g, c.b end,
            setFunc = function(r, g, b)
                B.sv.theme = { r = r, g = g, b = b }
                B.ApplyTheme()
                Changed()
            end,
        },
        {
            type = "button",
            name = L("SET_RESET_POS"),
            tooltip = L("SET_RESET_POS_TT"),
            func = function()
                B.sv.launcher.x, B.sv.launcher.y = nil, nil
                B.sv.window.x, B.sv.window.y = nil, nil
                B.sv.places = {}
                B.callbacks:FireCallbacks("PositionsReset")
            end,
        },
        {
            type = "button",
            name = L("SET_TOUR"),
            tooltip = L("SET_TOUR_TT"),
            func = function()
                -- (back to the game first: the window would stay on top of the settings menu)
                if SCENE_MANAGER and SCENE_MANAGER.ShowBaseScene then SCENE_MANAGER:ShowBaseScene() end
                B.Later(B.UI.StartTour, 400)
            end,
        },
    })
end
