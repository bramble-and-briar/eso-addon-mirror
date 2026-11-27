local H=HUDMoveUI
function H.CreateSettings()
    local L=LibHarvensAddonSettings
    local panel=L:AddAddon("HUD Move UI",{allowRefresh=true})
    panel.version=H.version
    local options={
        {type=L.ST_LABEL,label="HUD-Element auswaehlen und Move UI druecken. Rechter Stick verschiebt, Kreuz speichert, Kreis bricht ab. Drei Sekunden Stillstand speichern automatisch. Groesse separat pro Element einstellen."},
        {type=L.ST_LABEL,label="Standardmaessig bleibt alles unveraendert. Versteckte Anzeigen werden nicht eingeblendet; ein Rahmen zeigt ihre Position. Bei Obsidian HUD oder anderen HUD-Movern darf nur ein Addon dasselbe Element steuern."},
        {type=L.ST_SECTION,label="Allgemein"},
        {type=L.ST_CHECKBOX,label="HUD-Anpassungen aktiv",getFunction=function() return H.saved.enabled end,
            setFunction=function(value) H.StopMove(false); H.saved.enabled=value; H.Refresh() end},
        {type=L.ST_SLIDER,label="Geschwindigkeit des rechten Sticks",min=100,max=1200,step=50,
            getFunction=function() return H.saved.speed end,setFunction=function(v) H.saved.speed=v end},
        {type=L.ST_BUTTON,label="Move UI speichern und beenden",buttonText="Speichern",disable=function() return not H.moving end,
            clickHandler=function() H.StopMove(true) end},
        {type=L.ST_BUTTON,label="Move UI abbrechen",buttonText="Abbrechen",disable=function() return not H.moving end,
            clickHandler=function() H.StopMove(false) end},
    }
    options[#options+1]={type=L.ST_SECTION,label="Erkannte Addon-Fenster"}
    options[#options+1]={type=L.ST_LABEL,label="Das gewuenschte Fenster zuerst im anderen Addon anzeigen, dann suchen. Es werden benannte Fenster erkannt, keine beliebigen Menues oder Hintergrund-Addons. Die Anpassung bleibt bis zu deiner Auswahl ausgeschaltet."}
    options[#options+1]={type=L.ST_BUTTON,label="Addon-Fenster suchen",buttonText="Fensterliste aktualisieren",
        disable=function() return H.scanning or H.moving end,clickHandler=H.StartDiscovery}
    options[#options+1]={type=L.ST_LABEL,label=function() return H.discoveryStatus or "Die erste Suche startet nach dem Einloggen automatisch." end}
    options[#options+1]={type=L.ST_DROPDOWN,label="Addon-Fenster auswaehlen",items=H.DiscoveryItems,
        getFunction=H.SelectedAddonName,setFunction=function(_,_,item)
            if item and item.data~="" then H.saved.selectedAddon=item.data end
        end}
    options[#options+1]={type=L.ST_LABEL,label=function()
        local entry=H.SelectedAddon()
        if not entry then return "Noch kein Addon-Fenster ausgewaehlt." end
        if entry.error then return "Nicht anwendbar: "..entry.error end
        local c=H.Resolve(entry)
        return entry.title..(not c and " — zurzeit nicht vorhanden. Fenster oeffnen und erneut suchen."
            or c:IsHidden() and " — momentan ausgeblendet." or " — verfuegbar.")
    end}
    options[#options+1]={type=L.ST_CHECKBOX,label="Ausgewaehltes Addon-Fenster anpassen",
        disable=function() return not H.SelectedAddon() end,
        getFunction=function() local e=H.SelectedAddon(); return e and H.Config(e).enabled or false end,
        setFunction=function(v) local e=H.SelectedAddon(); if e then H.StopMove(false); H.Config(e).enabled=v; H.Apply(e) end end}
    options[#options+1]={type=L.ST_BUTTON,label="Move UI: Addon-Fenster",buttonText="Mit rechtem Stick verschieben",
        disable=function() local e=H.SelectedAddon(); return not e or not H.Resolve(e) end,
        clickHandler=function() local e=H.SelectedAddon(); if e then H.StartMove(e) end end}
    options[#options+1]={type=L.ST_SLIDER,label="Groesse des Addon-Fensters (%)",min=50,max=200,step=5,
        disable=function() local e=H.SelectedAddon(); return not e or not H.saved.enabled or not H.Config(e).enabled end,
        getFunction=function() local e=H.SelectedAddon(); return e and (H.Config(e).scale or 1)*100 or 100 end,
        setFunction=function(v) local e=H.SelectedAddon(); if e then H.Config(e).scale=v/100; H.Apply(e) end end}
    options[#options+1]={type=L.ST_BUTTON,label="Addon-Fenster zuruecksetzen",buttonText="Originalposition und -groesse",
        disable=function() return not H.SelectedAddon() end,
        clickHandler=function() local e=H.SelectedAddon(); if e then H.Reset(e) end end}
    for _,item in ipairs(H.entries) do
        local entry=item
        if not entry.custom then
        options[#options+1]={type=L.ST_SECTION,label=entry.section.." / "..entry.title}
        options[#options+1]={type=L.ST_LABEL,label=function()
            if entry.error then return "Nicht anwendbar: "..entry.error end
            local control=H.Resolve(entry)
            return not control and "Status: Auf diesem Client noch nicht verfuegbar."
                or (control:IsHidden() and "Status: Momentan ausgeblendet. Move UI zeigt einen Positionsrahmen." or "Status: Verfuegbar.")
        end}
        options[#options+1]={type=L.ST_CHECKBOX,label="Anpassen",getFunction=function() return H.Config(entry).enabled end,
            setFunction=function(v) H.StopMove(false); H.Config(entry).enabled=v; H.Apply(entry) end}
        options[#options+1]={type=L.ST_BUTTON,label="Move UI",buttonText="Mit rechtem Stick verschieben",
            clickHandler=function() H.StartMove(entry) end}
        options[#options+1]={type=L.ST_SLIDER,label="Groesse (%)",min=50,max=200,step=5,
            disable=function() return not H.saved.enabled or not H.Config(entry).enabled end,
            getFunction=function() return (H.Config(entry).scale or 1)*100 end,
            setFunction=function(v) H.Config(entry).scale=v/100; H.Apply(entry) end}
        options[#options+1]={type=L.ST_BUTTON,label="Dieses Element zuruecksetzen",buttonText="Originalposition und -groesse",
            clickHandler=function() H.Reset(entry) end}
        end
    end
    options[#options+1]={type=L.ST_SECTION,label="Alle Elemente zuruecksetzen"}
    options[#options+1]={type=L.ST_BUTTON,label="Alle Positionen und Groessen zuruecksetzen",buttonText="Alles zuruecksetzen",
        clickHandler=function()
            local fn=(IsConsoleUI() or IsInGamepadPreferredMode()) and ZO_Dialogs_ShowGamepadDialog or ZO_Dialogs_ShowDialog
            fn("HUDMOVEUI_RESET")
        end}
    ESO_Dialogs.HUDMOVEUI_RESET={gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},
        title={text="HUD Move UI"},mainText={text="Alle mit HUD Move UI gespeicherten Positionen und Groessen zuruecksetzen?"},
        buttons={{text=SI_DIALOG_CONFIRM,callback=H.ResetAll},{text=SI_DIALOG_CANCEL}}}
    panel:AddSettings(options)
end
