-- Nombres de las asignaciones de teclas (Controles > NW Interfaz), en el idioma del juego
for i = 1, 8 do
    ZO_CreateStringId("SI_BINDING_NAME_NWUI_QS_" .. i, NWUI.T("bind_qs", i))
end
ZO_CreateStringId("SI_BINDING_NAME_NWUI_TOGGLE_MOVE", NWUI.T("bind_move"))
