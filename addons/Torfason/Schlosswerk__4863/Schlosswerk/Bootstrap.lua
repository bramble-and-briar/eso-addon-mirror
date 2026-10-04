Schlosswerk = Schlosswerk or {}
local SW = Schlosswerk

SW.name = "Schlosswerk"
SW.displayName = "|c7FC7FFSchlosswerk|r"
SW.version = "2.0.0"
SW.addOnVersion = 200
SW.savedVariablesName = "SchlosswerkSavedVariables"
SW.savedVariablesVersion = 1
SW.textureRoot = "Schlosswerk/Textures/"

SW.defaultSettings = {
    selectionMode = "fixed",
    fixedStyle = "classic",
    pinLights = false,
    avoidImmediateRepeat = true,
    randomPool = {
        original = false,
        classic = true,
        dremora = true,
        dwemer = true,
        holz = true,
        nord = true,
        orsimer = true,
    },
    lastRandomStyle = nil,
}

function SW:IsLockpickSceneShowing()
    return SCENE_MANAGER
        and (SCENE_MANAGER:IsShowing("lockpickKeyboard") or SCENE_MANAGER:IsShowing("lockpickGamepad"))
end

function SW:Print(message)
    d(string.format("|c7FC7FFSchlosswerk|r: %s", tostring(message)))
end
