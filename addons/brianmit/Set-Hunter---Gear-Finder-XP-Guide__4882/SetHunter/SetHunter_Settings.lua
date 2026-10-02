-- SetHunter_Settings.lua : settings panel (LibAddonMenu-2.0)

local S = SetHunter
local L = S.L

local PANEL = "SetHunterSettings"

function S.OpenSettings()
    if S.settingsPanel then
        LibAddonMenu2:OpenToPanel(S.settingsPanel)
    else
        S.Print(L("NO_LAM"))
    end
end

local function Check(key, textKey, tipKey, def, setFn, disabled)
    return {
        type = "checkbox",
        name = L(textKey),
        tooltip = tipKey and L(tipKey) or nil,
        getFunc = function() return S.sv[key] end,
        setFunc = setFn or function(v) S.sv[key] = v end,
        default = def,
        disabled = disabled,
    }
end

function S.InitSettings()
    local lam = LibAddonMenu2
    if not lam then return end
    local sv = S.sv
    local noAlert = function() return not sv.dropAlert end

    S.settingsPanel = lam:RegisterAddonPanel(PANEL, {
        type = "panel",
        name = L("TITLE"),
        displayName = L("TITLE"),
        author = "|c00C8FFbrianmit|r",   -- cyan, like Command Codex
        version = "1.0.1",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    lam:RegisterOptionControls(PANEL, {
        { type = "description", text = L("SET_INFO") },

        { type = "header", name = L("SET_HDR_BUTTON") },
        {
            type = "checkbox",
            name = L("SET_BUTTON"),
            tooltip = L("SET_BUTTON_TT"),
            getFunc = function() return not sv.launcherHidden end,
            setFunc = S.SetLauncherShown,
            default = true,
        },
        Check("launcherCompact", "SET_COMPACT", "SET_COMPACT_TT", false, S.SetLauncherCompact),
        Check("launcherCombatHide", "SET_COMBAT_HIDE", "SET_COMBAT_HIDE_TT", true, S.SetLauncherCombatHide),
        Check("bagButton", "SET_BAG_BUTTON", "SET_BAG_BUTTON_TT", true, S.SetBagButtonShown),
        { type = "button", name = L("SET_RESET_POS"), tooltip = L("SET_RESET_POS_TT"), func = S.ResetPosition, width = "half" },
        { type = "button", name = L("SET_RESET_SIZE"), tooltip = L("SET_RESET_SIZE_TT"), func = S.ResetSize, width = "half" },
        Check("bankOpen", "SET_BANK_OPEN", "SET_BANK_OPEN_TT", true),

        { type = "header", name = L("SET_HDR_ALERTS") },
        Check("dropAlert", "SET_DROP", "SET_DROP_TT", true),
        Check("dropSound", "SET_DROP_SOUND", nil, true, nil, noAlert),
        Check("dropOnlyNew", "SET_DROP_NEW", "SET_DROP_NEW_TT", false, nil, noAlert),
        Check("announce", "SET_ANNOUNCE", "ANNOUNCE_TT", true, S.SetAnnounce),

        { type = "header", name = L("SET_HDR_LISTS") },
        Check("missingOnly", "SET_MISSING", "MISSING_ONLY_TT", false, S.SetMissingOnly),

        { type = "header", name = L("SET_HDR_RUNS") },
        Check("runSummary", "SET_SUMMARY", "SET_SUMMARY_TT", true),
    })
end
