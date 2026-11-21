-- ============================================================================
-- Bloom HPS - Slash commands
--   /bloomhps        print the current (or last) fight's numbers and shield total
--   /bloomhps help   list commands
-- ============================================================================

local M = HPSMeterUI
local Commands = {}
M.Commands = Commands

local format = string.format
local Fmt = M.FormatShortNumber

local function PrintStats()
    local stats = M.Data.GetStats()
    if not stats.hasFight then
        M.Print("No fight recorded yet.")
        return
    end
    local scope = stats.scope == "bg" and ("Battleground (" .. tostring(stats.bgName) .. ", " .. stats.fights .. " fights)")
        or (stats.active and "Current fight" or "Last fight")
    M.Print(format("%s | HPS %s | HPM %s | Heal Personal %s / Group %s",
        scope,
        Fmt(stats.hps), Fmt(stats.hpm), Fmt(stats.healPersonal), Fmt(stats.healGroup)))
    M.Print(format("Crit Heal %s | Crit HPS %s | %.1f%% of healing | %.0f%% crit rate",
        Fmt(stats.critHeal), Fmt(stats.critHps), stats.critHealPct, stats.critHealRate))
    M.Print(format("SPS %s | SPM %s | Shield %s | Personal %s / Group %s",
        Fmt(stats.sps), Fmt(stats.spm), Fmt(stats.shieldTotal), Fmt(stats.shieldPersonal),
        stats.groupMode and Fmt(stats.shieldGroup) or "- (group mode off)"))
    M.Print(format("Mitigated %s | MPS %s | MPM %s | %.1f%% of incoming",
        Fmt(stats.mitigated), Fmt(stats.mps), Fmt(stats.mpm), stats.mitigatedPct))
end

local function PrintTextureInfo()
    M.Print("Add-on folder: " .. tostring(M.GetAddOnRootPath()))
    M.Print("Texture path in use: " .. M.Texture("panel"))
    M.Print("Textures loaded: " .. tostring(M.UI.TexturesLoaded()))
    for _, state in ipairs(M.UI.GetProbeStates()) do
        M.Print(format("  %s -> %s", state.path, state.loaded and "loaded" or "not loaded"))
    end
end

local function PrintHelp()
    M.Print("/bloomhps - show healing, shielding and mitigation for the current or last fight")
    M.Print("/bloomhps fights [text] - saved fights whose zone, battleground, date or character contains text")
    M.Print("/bloomhps bg [text] - saved battlegrounds whose name, mode, result, date or character contains text")
    M.Print("/bloomhps bg #12 - battleground 12 and each of its fights")
    M.Print("/bloomhps textures - show where the flower textures are loaded from")
    M.Print("/bloomhps help - show this list")
end

function Commands.Register()
    SLASH_COMMANDS["/bloomhps"] = function(args)
        local cmd, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
        cmd = cmd:lower()
        if cmd == "help" then
            PrintHelp()
        elseif cmd:match("^tex") then
            PrintTextureInfo()
        elseif cmd == "fights" or cmd == "fight" then
            M.History.PrintFightSearch(rest)
        elseif cmd == "bg" or cmd == "bgs" then
            M.History.PrintBattlegroundSearch(rest)
        else
            PrintStats()
        end
    end
end
