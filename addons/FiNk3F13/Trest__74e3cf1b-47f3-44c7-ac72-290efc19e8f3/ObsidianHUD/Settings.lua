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
            setFunction=function(value)
                if key=="skillHudScale" then O.StopNativeMove() end
                O.vars[key]=value; O.Refresh()
            end}
    end
    local function dropdown(label,key,items,tooltip)
        return {type=L.ST_DROPDOWN,label=label,items=items,tooltip=tooltip,
            getFunction=function()
                for _,entry in ipairs(items) do if entry.data==O.vars[key] then return entry.name end end
                return items[1].name
            end,
            setFunction=function(_,_,entry) O.vars[key]=entry.data; O.Refresh() end}
    end
    local function color(label,key)
        return {type=L.ST_COLOR,label=label,
            getFunction=function() return unpack(O.vars[key] or O.vars.accent) end,
            setFunction=function(r,g,b) O.vars[key]={r,g,b}; O.Refresh() end}
    end
    local settings={
        {type=L.ST_LABEL,label="Fantasy-Metallrahmen, abgeschraegte Balken und ein Klassenemblem. Aktive Skills bleiben echte ESO-Buttons; die zweite Reihe zeigt die andere Waffenleiste."},
        {type=L.ST_SECTION,label="Skill-Leiste"},
        slider("Gesamtes Skill-HUD: Groesse","skillHudScale",1,1.5,0.05),
        checkbox("Andere Waffenleiste als zweite Reihe","backBar","Nur Vorschau: ESO erlaubt weiterhin fuenf Skills und eine Ultimate pro Waffenleiste."),
        dropdown("Skill-HUD-Ansicht","skillHudView",O.skillHudViews,
            "Animation betrifft den Waffenwechsel der Skills. Die Druckanimation beim Benutzen bleibt in allen Ansichten aktiv."),
        color("Skill HUD","skillFrameColor"),
        {type=L.ST_SECTION,label="Skill-Timer"},
        slider("Skill-Timergroesse","timerSize",8,48,1),
        color("Timer-Farbe","timerColor"),
        dropdown("Timer-Schriftart","timerFont",O.skillFonts),
        dropdown("Timer-Schriftstil","timerStyle",O.skillTextStyles),
        {type=L.ST_SECTION,label="Stacks"},
        slider("Stack-Groesse","stackSize",8,32,1),
        color("Stack-Farbe","stackColor"),
        dropdown("Stack-Schriftart","stackFont",O.skillFonts),
        dropdown("Stack-Schriftstil","stackStyle",O.skillTextStyles),
        {type=L.ST_SECTION,label="Ressourcen-HUD"},
        {type=L.ST_BUTTON,label="Move UI",buttonText="Ressourcen-HUD verschieben",
            tooltip="Leben, Magicka, Ausdauer und Emblem gemeinsam mit dem rechten Stick verschieben. Speichert nach 3 Sekunden ohne Bewegung.",
            clickHandler=function() O.StartMove() end},
        {type=L.ST_LABEL,label="Leben bleibt oben. Der hoehere Ressourcen-Maximalwert auf der Frontbar bestimmt die mittlere Position. Beim Wechsel auf die Backbar bleibt die Reihenfolge erhalten. Sie wird pro Charakter gespeichert."},
        slider("Breite","width",380,800,10),
        slider("Groesse","scale",0.65,1.6,0.05),
        slider("Deckkraft","opacity",0.4,1,0.05),
        checkbox("Werte und Prozent anzeigen","numbers"),
        color("Lebensfarbe","health"),
        color("Magickafarbe","magicka"),
        color("Ausdauerfarbe","stamina"),
        color("Metall-Akzentfarbe","accent"),
    }
    settings[#settings+1]={type=L.ST_SECTION,label="HUD-Elemente verschieben"}
    settings[#settings+1]={type=L.ST_BUTTON,label="Move UI: Skills, Traenke und Ultimate gemeinsam",
        buttonText="Skill-HUD gemeinsam verschieben",
        tooltip="Verschiebt beide Skillleisten, Traenke und Ultimate gemeinsam. Abstaende bleiben erhalten. Ressourcen-HUD, Buffanzeige und Synergie bleiben stehen. Speichert nach 3 Sekunden ohne Bewegung.",
        clickHandler=function() O.StartNativeMove("skillgroup") end}
    for _,entry in ipairs({{"skills","Skillleiste"},{"ultimate","Ultimate"},{"quickslot","Traenke"},{"buffs","Buffanzeige"},{"synergy","Synergie-Hinweis"}}) do
        local key,label=entry[1],entry[2]
        settings[#settings+1]={type=L.ST_BUTTON,label="Move UI: "..label,buttonText=label.." verschieben",
            tooltip="Mit dem rechten Stick verschieben. Der markierte Bereich speichert nach 3 Sekunden ohne Bewegung.",
            clickHandler=function() O.StartNativeMove(key) end}
    end
    settings[#settings+1]={type=L.ST_BUTTON,label="Gesamtes HUD: Position und Groesse zuruecksetzen",
        buttonText="Gesamtes HUD zuruecksetzen",
        tooltip="Setzt Ressourcen, Skills, Ultimate, Traenke, Buffanzeige und Synergiepositionen fuer Tastatur und Controller zurueck. Groessen werden zurueckgesetzt; Farben, Timer und die gewaehlte Ansicht bleiben erhalten.",
        clickHandler=function() O.ResetHudLayout() end}
    panel:AddSettings(settings)
end
