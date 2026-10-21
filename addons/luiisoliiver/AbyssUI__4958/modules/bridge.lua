NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI

-- Bridge: Minimap (DS_3) into AbyssUI. Chat removed.
NagaMapUI = NagaMapUI or {}

NagaMapUI.Settings = NagaMapUI.Settings or {}
local S = NagaMapUI.Settings
local defaults = {
    style = "ds3",
    chat = false,
    fonts = { ds3 = "default" },
}
local db
function S.Get()
    if not db then
        NagaMapUI.SavedVariables.MigrateLegacy()
        db = ZO_SavedVars:NewAccountWide(NagaMapUI.SavedVariables.NAME, 1, nil, defaults, GetWorldName())
        if db.style ~= "ds3" and db.style ~= "none" and db.style ~= "diablo" and db.style ~= "wow" then
            db.style = "ds3"
        end
    end
    return db
end
function S.Style() S.Get() return "ds3" end
function S.StyleEnabled() return true end
function S.Enabled(key) return S.Get()[key] ~= false end
function S.FontFace() return nil end
function S.Initialize() S.Get() end

NAGA_UI.OnAddonLoaded(function()
    if not NagaMapUI.SavedVariables then return end

    S.Initialize()

    if NagaMapUI.Theme and NagaMapUI.Theme.Configure then
        NagaMapUI.Theme.Configure()
    end

    if NagaMapUI.Minimap and NagaMapUI.Minimap.Initialize then
        NagaMapUI.Minimap.Initialize()
    end
end)
