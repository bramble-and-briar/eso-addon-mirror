local O=ObsidianHUD
function O.CreateSettings()
    local L=LibHarvensAddonSettings
    local panel=L:AddAddon("Obsidian HUD",{allowRefresh=true})
    panel.version=O.version
    local function checkbox(label,key,tooltip)
        return {type=L.ST_CHECKBOX,label=label,tooltip=tooltip,
            getFunction=function() return O.vars[key] end,
            setFunction=function(value) O.vars[key]=value; O.Refresh() end}
    end
    local function slider(label,key,low,high,step)
        return {type=L.ST_SLIDER,label=label,min=low,max=high,step=step,
            getFunction=function() return O.vars[key] end,
            setFunction=function(value) O.vars[key]=value; O.Refresh() end}
    end
    local settings={
        {type=L.ST_LABEL,label=O.MaterialStatus},
        {type=L.ST_LABEL,label="Fantasy-Metallrahmen, abgeschraegte Balken und ein Klassenemblem. Aktive Skills bleiben echte ESO-Buttons; die zweite Reihe zeigt die andere Waffenleiste."},
        checkbox("Obsidian HUD aktiv","enabled","Aus stellt die Original-Ressourcen und die native Skilldekoration wieder her."),
        checkbox("Originale Ressourcenbalken ausblenden","hideOriginals","Ersetzt nur Leben, Magicka und Ausdauer. Besondere Anzeigen wie Reittier-Ausdauer bleiben erhalten."),
        {type=L.ST_SECTION,label="Skill-Leiste"},
        checkbox("Obsidian-Skillrahmen","skillFrames"),
        checkbox("Andere Waffenleiste als zweite Reihe","backBar","Nur Vorschau: ESO erlaubt weiterhin fuenf Skills und eine Ultimate pro Waffenleiste."),
        {type=L.ST_SECTION,label="Ressourcen-HUD"},
        {type=L.ST_BUTTON,label="Move UI",buttonText="Ressourcen-HUD verschieben",
            tooltip="Leben, Magicka, Ausdauer und Emblem gemeinsam mit Maus oder rechtem Stick verschieben. Speichert nach 3 Sekunden ohne Bewegung.",
            disable=function() return not O.vars.enabled end,
            clickHandler=function() O.StartMove() end},
        {type=L.ST_LABEL,label="Leben bleibt oben. Der hoehere Ressourcen-Maximalwert auf der Frontbar bestimmt die mittlere Position. Beim Wechsel auf die Backbar bleibt die Reihenfolge erhalten. Sie wird pro Charakter gespeichert."},
        checkbox("Rundes Emblem statt Raute","roundBadge"),
        checkbox("Eigene Klassensymbole","customClassIcons","Zeigt das neue Symbol deiner Charakterklasse. Aus verwendet die normalen ESO-Klassensymbole."),
        slider("Breite","width",380,800,10),
        slider("Groesse","scale",0.65,1.6,0.05),
        slider("Horizontal verschieben","x",-GuiRoot:GetWidth()/2,GuiRoot:GetWidth()/2,5),
        slider("Vertikal verschieben","y",-GuiRoot:GetHeight(),0,5),
        slider("Deckkraft","opacity",0.4,1,0.05),
        checkbox("Werte und Prozent anzeigen","numbers"),
    }
    settings[#settings+1]={type=L.ST_SECTION,label="HUD-Elemente einzeln verschieben"}
    for _,entry in ipairs({{"skills","Skillleiste"},{"ultimate","Ultimate"},{"quickslot","Traenke"},{"buffs","Buffanzeige"}}) do
        local key,label=entry[1],entry[2]
        settings[#settings+1]={type=L.ST_BUTTON,label="Move UI: "..label,buttonText=label.." verschieben",
            tooltip="Mit Maus oder rechtem Stick verschieben. Der markierte Bereich speichert nach 3 Sekunden ohne Bewegung. Tastatur- und Controllerpositionen werden getrennt gespeichert.",
            disable=function() return not O.vars.enabled end,
            clickHandler=function() O.StartNativeMove(key) end}
    end
    settings[#settings+1]={type=L.ST_BUTTON,label="Skill-, Ultimate-, Trank- und Buffpositionen zuruecksetzen",
        clickHandler=function() O.ResetNativePositions() end}
    for _,entry in ipairs({{"health","Lebensfarbe"},{"magicka","Magickafarbe"},
        {"stamina","Ausdauerfarbe"},{"accent","Metall-Akzentfarbe"}}) do
        local key,label=entry[1],entry[2]
        settings[#settings+1]={type=L.ST_COLOR,label=label,
            getFunction=function() return unpack(O.vars[key]) end,
            setFunction=function(r,g,b) O.vars[key]={r,g,b}; O.Refresh() end}
    end
    settings[#settings+1]={type=L.ST_BUTTON,label="Position und Groesse zuruecksetzen",
        clickHandler=function()
            for _,key in ipairs({"x","y","width","scale","opacity"}) do O.vars[key]=O.defaults[key] end
            O.Refresh()
        end}
    panel:AddSettings(settings)
end
