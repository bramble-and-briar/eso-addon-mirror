--[[
    Preview.lua
    Vista previa temporal de las barras de salud, magia y aguante, la de experiencia
    y la barra de acciones mientras el menú de ajustes está abierto. No se guarda en
    SavedVariables: es solo un estado de sesión y se desactiva solo al cerrar el menú del juego.
]]

ValuesBars = ValuesBars or {}
local VB = ValuesBars

local previewActive = false
local actionBarAdded = false
local callbackRegistered = false

function VB.IsPreviewActive()
    return previewActive
end

-- Cuando el menú del juego se oculta, la vista previa se apaga sola
local function RegisterMenuCallback()
    if callbackRegistered then return end
    callbackRegistered = true

    GAME_MENU_SCENE:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_HIDDEN then
            VB.SetPreview(false)
        end
    end)
end

function VB.SetPreview(active)
    -- Estos objetos son del juego base: si alguno no existe, no se hace nada
    if not (GAME_MENU_SCENE and PLAYER_ATTRIBUTE_BARS_FRAGMENT and PLAYER_ATTRIBUTE_BARS) then
        return
    end
    if active == previewActive then return end

    previewActive = active

    if active then
        RegisterMenuCallback()
        -- Las barras pertenecen al HUD, que no se dibuja en el menú: se añaden a su escena
        GAME_MENU_SCENE:AddFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
        -- La barra de experiencia ya está en la escena, pero sin esta no sabe qué mostrar
        if PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT then
            GAME_MENU_SCENE:AddFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
        end
        -- Evita que se desvanezcan en modo automático
        PLAYER_ATTRIBUTE_BARS:ForceShow(true)

        -- La barra de acciones se oculta sola en modo automático: se fuerza con el contador del propio juego
        if ACTION_BAR_FRAGMENT and ZO_ContextualActionBar_AddReference then
            actionBarAdded = true
            GAME_MENU_SCENE:AddFragment(ACTION_BAR_FRAGMENT)
            ZO_ContextualActionBar_AddReference()
        end
        VB.RefreshAll()
    else
        PLAYER_ATTRIBUTE_BARS:ForceShow(false)
        GAME_MENU_SCENE:RemoveFragment(PLAYER_ATTRIBUTE_BARS_FRAGMENT)
        if PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT then
            GAME_MENU_SCENE:RemoveFragment(PLAYER_PROGRESS_BAR_CURRENT_FRAGMENT)
        end
        if actionBarAdded then
            actionBarAdded = false
            ZO_ContextualActionBar_RemoveReference()
            GAME_MENU_SCENE:RemoveFragment(ACTION_BAR_FRAGMENT)
        end
    end
end
