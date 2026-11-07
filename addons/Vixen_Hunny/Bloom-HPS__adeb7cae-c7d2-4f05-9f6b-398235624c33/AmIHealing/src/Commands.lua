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
    M.Print(format("%s fight | HPS %s | HPM %s | Heal Personal %s / Group %s",
        stats.active and "Current" or "Last",
        Fmt(stats.hps), Fmt(stats.hpm), Fmt(stats.healPersonal), Fmt(stats.healGroup)))
    M.Print(format("SPS %s | SPM %s | Shield %s | Personal %s / Group %s",
        Fmt(stats.sps), Fmt(stats.spm), Fmt(stats.shieldTotal), Fmt(stats.shieldPersonal),
        stats.groupMode and Fmt(stats.shieldGroup) or "- (group mode off)"))
    M.Print(format("Mitigated %s | MPS %s | MPM %s | %.1f%% of incoming",
        Fmt(stats.mitigated), Fmt(stats.mps), Fmt(stats.mpm), stats.mitigatedPct))
end

local function PrintTextureInfo()
    M.Print("Add-on folder: " .. tostring(M.GetAddOnRootPath()))
    M.Print("Texture path: " .. M.Texture("panel"))
    M.Print("Textures loaded: " .. tostring(M.UI.TexturesLoaded()))
end

local function PrintHelp()
    M.Print("/bloomhps - show healing, shielding and mitigation for the current or last fight")
    M.Print("/bloomhps textures - show where the flower textures are loaded from")
    M.Print("/bloomhps help - show this list")
end

function Commands.Register()
    SLASH_COMMANDS["/bloomhps"] = function(args)
        args = args and args:lower() or ""
        if args:match("^%s*help") then
            PrintHelp()
        elseif args:match("^%s*tex") then
            PrintTextureInfo()
        else
            PrintStats()
        end
    end
end
