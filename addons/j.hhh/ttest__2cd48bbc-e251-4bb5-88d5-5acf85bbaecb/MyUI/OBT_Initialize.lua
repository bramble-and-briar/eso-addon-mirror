local OBT = OffBalanceTracker

---------------------------------------------------------------------------
-- PORT SAVED VARIABLES
---------------------------------------------------------------------------
function OBT.PortSavedVariables()
    local OldToNew = {
        ["textColorTimer"]  = "ColorTextTimer",
        ["textColorBoss"]   = "ColorTextBoss",
        ["textColorUptime"] = "ColorTextUptime",
        ["colorIdle"]       = "ColorIdle",
        ["colorActive"]     = "ColorActive",
        ["colorImmune"]     = "ColorImmune",
    }

    for oldKey, newKey in pairs(OldToNew) do
        if OBT.SV[oldKey] ~= nil then
            OBT.SV[newKey] = OBT.SV[oldKey]
            OBT.SV[oldKey] = nil
        end
    end
end

---------------------------------------------------------------------------
-- INIT ADDON / SAVED VARS
---------------------------------------------------------------------------
function OBT.Initialize()
    -- FETCH LOCALIZED ABILITY NAMES FROM API ONE TIME ON START
    OBT.debuffName = GetAbilityName(62988)
    OBT.immuneName = GetAbilityName(134599)
    OBT.cleanDebuffName = zo_strformat("<<1>>", OBT.debuffName)
    OBT.cleanImmuneName = zo_strformat("<<1>>", OBT.immuneName)

    OBT.isConsole = IsConsoleUI()
    OBT.SV = ZO_SavedVars:NewAccountWide(OBT.SVName, OBT.SVVersion, GetWorldName(), OBT.Default)

    -- PORT OLD SETTINGS
    OBT.PortSavedVariables()

    OBT.CreateGuiElements()
    -- Settings are embedded in My UI through BUI.SettingsBridge.

    if OBT.SV.offsetX ~= OBT.Default.offsetX or OBT.SV.offsetY ~= OBT.Default.offsetY then
        OBT.PARENT:ClearAnchors()
        OBT.PARENT:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, OBT.SV.offsetX, OBT.SV.offsetY)
    else
        OBT.SetDefaultPosition()
    end

    math.randomseed(GetGameTimeMilliseconds())
    math.random() math.random() math.random()

    if OBT.SV.enableAddon then
        OBT.Enable()
    end
end

---------------------------------------------------------------------------
-- SLASH COMMAND
---------------------------------------------------------------------------
-- My UI manages position using its PlayStation Move Frames editor.

---------------------------------------------------------------------------
-- LOADED
---------------------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent("MyUI_OffBalanceInitialize", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
    if addonName == "MyUI" then
        OBT.Initialize()
        EVENT_MANAGER:UnregisterForEvent("MyUI_OffBalanceInitialize", EVENT_ADD_ON_LOADED)
    end
end)