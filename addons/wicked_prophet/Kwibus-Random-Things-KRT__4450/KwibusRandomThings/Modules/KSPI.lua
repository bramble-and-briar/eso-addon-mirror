KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings

-- Module-local defaults wrapper
local DEFAULTS = { kspi = {
    skipIntro = true,
} }

-- Module definition and metadata
--   id: unique module identifier ("kspi")
--   tabName: display name for the settings submenu ("Other Settings")
--   defaults: default settings table for this module
KRT.KSPI = {
    id = "kspi",
    tabName = "Other Settings",
    defaults = DEFAULTS.kspi,
}

-- =========================================================
-- SavedVariables Accessor
-- =========================================================

-- Retrieves the SavedVariables table for KSPI.
function KRT.KSPI:SV()
    return KRT.GetModuleSV(self.id, self.defaults)
end

-- Convenient local accessor shorthand for KRT.KSPI:SV()
local function SV()
    return KRT.KSPI:SV()
end

-- =========================================================
-- Engine CVar Handlers (Directly modifies UserSettings.txt)
-- =========================================================

-- Sets the client engine CVar controlling pregame startup videos.
--   skip: boolean - true to skip opening videos, false to play them.
--
-- Details:
--   * 'SkipPregameVideos' is the ESO client CVar modifying UserSettings.txt.
--   * Uses pcall() for safe execution across various game patches and environments.
--   * Passing "1" skips the intro videos; passing "0" plays the intro videos.
local function ApplyCVar(skip)
    local val = skip and "1" or "0"
    if SetCVar then
        pcall(SetCVar, "SkipPregameVideos", val)
    end
end

-- Synchronizes the active engine CVar state with the user's saved preference.
-- Defaults to true (skip intro) if the saved variable is not explicitly false.
function KRT.KSPI:SyncCVar()
    local sv = SV()
    local skip = (sv and sv.skipIntro ~= nil) and sv.skipIntro or DEFAULTS.kspi.skipIntro
    ApplyCVar(skip)
end

-- Queries the current engine CVar value directly from the ESO game client.
-- Uses pcall() to safely call GetCVar without throwing runtime exceptions.
-- Returns "1" if intro videos are skipped, or "0" if they are played.
function KRT.KSPI:GetCVarStatus()
    if GetCVar then
        local ok, val = pcall(GetCVar, "SkipPregameVideos")
        if ok and (val == "1" or val == 1) then
            return "1"
        end
    end
    return "0"
end

-- Returns true if pregame intro videos are currently configured to be skipped in the engine.
function KRT.KSPI:IsIntroSkipped()
    return self:GetCVarStatus() == "1"
end

-- =========================================================
-- Lifecycle & Initialization
-- =========================================================

-- Initializes the KSPI module during addon startup.
--
-- Logic:
--   * On first load (sv.skipIntro == nil), reads the current engine CVar state
--     via IsIntroSkipped() so it preserves existing user settings from UserSettings.txt.
--   * Calls SyncCVar() to ensure UserSettings.txt matches the addon's saved setting.
function KRT.KSPI:Initialize()
    local sv = self:SV()
    if not sv then return end

    if sv.skipIntro == nil then
        sv.skipIntro = self:IsIntroSkipped()
    end
    self:SyncCVar()
end

-- =========================================================
-- Settings Menu (LibAddonMenu-2.0)
-- =========================================================

-- Generates and returns the LibAddonMenu-2.0 (LAM-2.0) submenu specification for
-- KRT's unified settings panel.
--
-- Controls included:
--   1. "Skip Pregame Intro" checkbox toggle - toggles skipping and syncs CVar.
--   2. Explanatory description - explains the direct modification of UserSettings.txt.
--   3. Dynamic real-time CVar status indicator - queries the client engine and displays
--      the active CVar state with colored formatting.
function KRT.KSPI:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Other Settings",
        controls = {
            -- 1. "Skip Pregame Intro" checkbox toggle
            {
                type = "checkbox",
                name = "Skip Pregame Intro",
                tooltip = "When ON, skips startup logo videos directly to the login screen. When OFF, restores standard intro videos.",
                getFunc = function()
                    local sv = SV()
                    if sv and sv.skipIntro ~= nil then
                        return sv.skipIntro
                    end
                    return DEFAULTS.kspi.skipIntro
                end,
                setFunc = function(val)
                    local sv = SV()
                    if sv then
                        sv.skipIntro = val
                    end
                    self:SyncCVar()
                end,
                default = DEFAULTS.kspi.skipIntro,
                width = "full",
            },
            -- 2. Explanatory description of UserSettings.txt modification
            {
                type = "description",
                text = "Controls whether the game skips the opening Bethesda and ZeniMax logo videos when launching ESO. This directly modifies the |c00FFFFSkipPregameVideos|r setting in your |c00FFFFUserSettings.txt|r.",
                width = "full",
            },
            -- 3. Dynamic real-time CVar status indicator
            {
                type = "description",
                title = "Current UserSettings.txt Status",
                text = function()
                    local skipped = self:IsIntroSkipped()
                    if skipped then
                        return "Active CVar: |c00FF00SET SkipPregameVideos \"1\" (Skipping Intro)|r"
                    else
                        return "Active CVar: |cFF3344SET SkipPregameVideos \"0\" (Playing Intro)|r"
                    end
                end,
                width = "full",
            },
        },
    }
end

-- =========================================================
-- Module Registration
-- =========================================================

-- Registers the module with KRT's core lifecycle and settings orchestrator.
KRT:RegisterModule(KRT.KSPI)
