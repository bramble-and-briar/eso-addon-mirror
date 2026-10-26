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
    local function dropdown(label,key,items)
        return {type=L.ST_DROPDOWN,label=label,items=items,
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
        {type=L.ST_LABEL,label=O.MaterialStatus},
        {type=L.ST_LABEL,label="Fantasy-Metallrahmen, abgeschraegte Balken und ein Klassenemblem. Aktive Skills bleiben echte ESO-Buttons; die zweite Reihe zeigt die andere Waffenleiste."},
        {type=L.ST_SECTION,label="Skill-Leiste"},
        checkbox("Andere Waffenleiste als zweite Reihe","backBar","Nur Vorschau: ESO erlaubt weiterhin fuenf Skills und eine Ultimate pro Waffenleiste."),
        dropdown("Skill-HUD-Ansicht","skillHudView",O.skillHudViews),
        color("Skill HUD","skillFrameColor"),
        {type=L.ST_SECTION,label="Skill-Timer"},
        slider("Skill-Timergroesse","timerSize",8,48,1),
        color("Timer-Farbe","timerColor"),
        dropdown("Timer-Schriftart","timerFont",O.skillFonts),
        dropdown("Timer-Schriftstil","timerStyle",O.skillTextStyles),
        {type=L.ST_SECTION,label="Stacks"},
        {type=L.ST_BUTTON,label="Stack-Anzeige testen",buttonText="Testzahl 3 anzeigen",
            tooltip="Zeigt 15 Sekunden lang eine ausdrueckliche Testzahl oben rechts auf belegten Skills. Danach erscheinen wieder die echten Werte.",
            clickHandler=function() O.PreviewSkillStacks() end},
        slider("Stack-Groesse","stackSize",8,32,1),
        color("Stack-Farbe","stackColor"),
        dropdown("Stack-Schriftart","stackFont",O.skillFonts),
        dropdown("Stack-Schriftstil","stackStyle",O.skillTextStyles),
        {type=L.ST_SECTION,label="Ressourcen-HUD"},
        {type=L.ST_BUTTON,label="Move UI",buttonText="Ressourcen-HUD verschieben",
            tooltip="Leben, Magicka, Ausdauer und Emblem gemeinsam mit Maus oder rechtem Stick verschieben. Speichert nach 3 Sekunden ohne Bewegung.",
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
    settings[#settings+1]={type=L.ST_SECTION,label="HUD-Elemente einzeln verschieben"}
    for _,entry in ipairs({{"skills","Skillleiste"},{"ultimate","Ultimate"},{"quickslot","Traenke"},{"buffs","Buffanzeige"}}) do
        local key,label=entry[1],entry[2]
        settings[#settings+1]={type=L.ST_BUTTON,label="Move UI: "..label,buttonText=label.." verschieben",
            tooltip="Mit Maus oder rechtem Stick verschieben. Der markierte Bereich speichert nach 3 Sekunden ohne Bewegung. Tastatur- und Controllerpositionen werden getrennt gespeichert.",
            clickHandler=function() O.StartNativeMove(key) end}
    end
    settings[#settings+1]={type=L.ST_BUTTON,label="Skill-, Ultimate-, Trank- und Buffpositionen zuruecksetzen",
        clickHandler=function() O.ResetNativePositions() end}
    settings[#settings+1]={type=L.ST_BUTTON,label="Position und Groesse zuruecksetzen",
        clickHandler=function()
            for _,key in ipairs({"x","y","width","scale","opacity"}) do O.vars[key]=O.defaults[key] end
            O.Refresh()
        end}
    panel:AddSettings(settings)
end
