local S = IsoStats2
local wm, em = WINDOW_MANAGER, EVENT_MANAGER
local db, moving, dragging, previousUI, previousCamera, lastInput, lastTick
local windows, fields = {}, {}
local previewKey,previewUntil
local WIDTH = 180
local columnContentWidth=104
-- Each statistic is its own compact, independently positioned meter.
local groups = {
    {key='power',title='Schaden (PWR)',tag='PWR',color='C9AD76',accent={0.79,0.68,0.46},x=80,y=240},
    {key='penetration',title='Durchdringung',tag='PEN',color='75D8C1',accent={0.46,0.85,0.76},x=80,y=296,pen=true},
    {key='critical',title='Kritische Werte (CC / CD)',x=80,y=352,critical=true,width=320,accent={0.70,0.63,0.90}},
    {key='resistance',title='Resistenzen (PR / SR)',x=80,y=408,resistance=true,width=320,accent={0.58,0.73,0.87}},
    {key='criticalResistance',title='Kritische Resistenz',tag='CR',color='B6A1D7',accent={0.71,0.63,0.84},x=460,y=408},
}
local defaults = {enabled=true, target=true, penTarget=18200,criticalCapAutomatic=true,criticalCap=125,
    criticalShowEffective=true,shadowCorrection=false,modules={},values={}}
for _, g in ipairs(groups) do
    defaults.modules[g.key] = {enabled=true, x=g.x, y=g.y, size=100, spacing=100}
end
local render, setMoving
local function pixelSize()
    return 1 / math.max(0.1, GetUIGlobalScale())
end
local function anchor(key, x, y)
    local w, p = windows[key], db.modules[key]
    local pixel=pixelSize()
    local factor=w.scaleFactor or 1
    local maxX=math.floor(math.max(0,GuiRoot:GetWidth()-w:GetWidth()*factor)/pixel)*pixel
    local maxY=math.floor(math.max(0,GuiRoot:GetHeight()-w:GetHeight()*factor)/pixel)*pixel
    p.x = math.max(0, math.min(maxX, math.floor(x/pixel+0.5)*pixel))
    p.y = math.max(0, math.min(maxY, math.floor(y/pixel+0.5)*pixel))
    w:ClearAnchors()
    w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
end
local function savePosition(key)
    local w=windows[key]
    anchor(key, math.floor(w:GetLeft()+0.5), math.floor(w:GetTop()+0.5))
end
local function hudVisible()
    local scene=SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene:GetName()
    return name=='hud' or name=='hudui'
end
local function number(value)
    local grouped, count=string.format('%.0f',value),0
    repeat grouped,count=grouped:gsub('^(-?%d+)(%d%d%d)','%1.%2') until count==0
    return grouped
end
render=function()
    S.includeTargetBonuses=db.target
    S.criticalCapAutomatic=db.criticalCapAutomatic
    S.manualCriticalCap=db.criticalCap
    S.criticalShowEffective=db.criticalShowEffective
    S.applyShadowCorrection=db.shadowCorrection
    local v=S.ReadStats()
    local hasTarget=db.target and v.targetName~=nil
    local visibleHUD=hudVisible() and db.enabled
    for _,g in ipairs(groups) do
        local key=g.key
        local w=windows[key]
        if g.critical then
            local damage=v.displayCriticalDamage
            local estimated=v.backstabberCriticalDamage>0 or (hasTarget and v.targetCriticalDamage~=0)
            fields.criticalChance.value:SetText(string.format('%.1f%%',v.criticalChance))
            fields.criticalDamage.value:SetText(string.format('%.1f%%',damage))
            fields.criticalDamage.label:SetText('CD'..(estimated and '*' or ''))
        elseif g.resistance then
            fields.physicalResistance.value:SetText(number(v.physicalResistance))
            fields.spellResistance.value:SetText(number(v.spellResistance))
        else
        local value=v[key]
        local estimated=key=='criticalDamage' and v.backstabberCriticalDamage>0
        if hasTarget and g.pen then
            value=value+v.targetPenetration
            estimated=v.targetPenetration~=0
        elseif hasTarget and key=='criticalDamage' then
            value=value+v.targetCriticalDamage
            estimated=estimated or v.targetCriticalDamage~=0
        end
        fields[key].value:SetText(g.percent and string.format('%.1f%%',value) or number(value))
        if g.pen then
            local reached=value>=math.max(100,tonumber(db.penTarget) or 18200)
            w.penRatio=math.max(0,math.min(1,value/math.max(100,tonumber(db.penTarget) or 18200)))
            fields[key].value:SetColor(reached and 0 or 1,1,reached and 0 or 1,1)
        end
        fields[key].label:SetText(g.tag..(estimated and '*' or ''))
        end
        local options=db.modules[key]
        local factor=math.max(50,math.min(150,tonumber(options.size) or 100))/100
        w.scaleFactor=factor
        w:SetScale(factor)
        local spacing=math.max(25,math.min(150,tonumber(options.spacing) or 100))/100
        local pixel=pixelSize()/factor
        local pad=8+2*spacing
        local gap=4+4*spacing
        local unit=columnContentWidth+2*pad
        for index,fieldKey in ipairs(w.fieldKeys) do
            local field=fields[fieldKey]
            local cursor=(index-1)*(unit+gap)+pad
            field.value:ClearAnchors()
            field.value:SetAnchor(TOPLEFT,w,TOPLEFT,cursor,18+2*spacing)
            field.value:SetDimensions(columnContentWidth,32)
            field.label:ClearAnchors()
            field.label:SetAnchor(TOPLEFT,w,TOPLEFT,cursor,4+2*spacing)
            field.label:SetDimensions(columnContentWidth,16)
            if index==2 then w.separatorX=unit+gap/2 end
        end
        local width=math.ceil((#w.fieldKeys*unit+(#w.fieldKeys-1)*gap)/pixel)*pixel
        local height=math.ceil((52+6*spacing)/pixel)*pixel
        w:SetDimensions(width,height)
        w.leftInset=0
        w.backdrop:ClearAnchors()
        w.backdrop:SetAnchor(TOPLEFT,w,TOPLEFT,0,0)
        w.backdrop:SetDimensions(width,height)
        w.frame.top:SetDimensions(width,pixel)
        w.frame.bottom:SetDimensions(width,pixel)
        for _,side in ipairs({'left','right'}) do
            local line=w.frame[side]
            local point=side=='left' and TOPLEFT or TOPRIGHT
            line:ClearAnchors()
            line:SetAnchor(point,w,point,0,pixel)
            line:SetDimensions(pixel,height-2*pixel)
        end
        w.accent:SetDimensions(2*pixel,height-2*pixel)
        w.accent:ClearAnchors()
        w.accent:SetAnchor(TOPLEFT,w,TOPLEFT,0,pixel)
        if w.separator then
            w.separator:ClearAnchors()
            w.separator:SetAnchor(TOPLEFT,w,TOPLEFT,w.separatorX,8)
            w.separator:SetDimensions(pixel,height-16)
        end
        if w.penTrack then
            local trackWidth=width-2*pad
            w.penTrack:ClearAnchors()
            w.penTrack:SetAnchor(TOPLEFT,w,TOPLEFT,pad,height-5*pixel)
            w.penTrack:SetDimensions(trackWidth,2*pixel)
            w.penFill:ClearAnchors()
            w.penFill:SetAnchor(TOPLEFT,w.penTrack,TOPLEFT,0,0)
            w.penFill:SetDimensions(math.max(pixel,trackWidth*(w.penRatio or 0)),2*pixel)
            w.penFill:SetHidden((w.penRatio or 0)<=0)
            if (w.penRatio or 0)>=1 then w.penFill:SetColor(0,1,0,1)
            else w.penFill:SetColor(0.46,0.85,0.76,0.9) end
        end
        local preview=previewKey==key and GetGameTimeMilliseconds()<(previewUntil or 0)
        w:SetHidden(moving~=key and not preview and (not visibleHUD or not db.modules[key].enabled))
        if not (moving==key and dragging) then anchor(key,db.modules[key].x,db.modules[key].y) end
    end
end
setMoving=function(key)
    if key==moving then
        if key then lastInput=GetGameTimeMilliseconds() end
        return
    end
    em:UnregisterForUpdate(S.name..'Move')
    if moving then
        local old=windows[moving]
        old:StopMovingOrResizing()
        savePosition(moving)
        old:SetMovable(false)
        old:SetMouseEnabled(false)
        old.hint:SetHidden(true)
        for _,line in pairs(old.frame) do line:SetColor(0.65,0.70,0.78,0.25) end
        SetGamepadRightStickConsumedByUI(false)
        SCENE_MANAGER:SetInUIMode(previousUI)
        SetGameCameraUIMode(previousCamera)
    end
    moving,dragging=key,false
    if key then
        local w=windows[key]
        w:SetMovable(true)
        w:SetMouseEnabled(true)
        w.hint:SetHidden(false)
        for _,line in pairs(w.frame) do line:SetColor(1,0.8,0.3,1) end
        lastInput,lastTick=GetGameTimeMilliseconds(),GetGameTimeMilliseconds()
        previousUI=SCENE_MANAGER:IsInUIMode()
        previousCamera=IsGameCameraUIModeActive()
        SCENE_MANAGER:SetInUIMode(true)
        SetGameCameraUIMode(true)
        em:RegisterForUpdate(S.name..'Move',16,function()
            local now=GetGameTimeMilliseconds()
            local dt=math.min(0.05,math.max(0,(now-lastTick)/1000))
            lastTick=now
            local x=GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE)
            local y=GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE)
            SetGamepadRightStickConsumedByUI(true)
            if dragging then lastInput=now end
            if not dragging and (math.abs(x)>0.08 or math.abs(y)>0.08) then
                local p=db.modules[key]
                anchor(key,p.x+x*700*dt,p.y-y*700*dt)
                lastInput=now
            end
            if now-lastInput>=3000 then setMoving(nil) end
        end)
    end
    render()
end
local function label(name,parent,x,y,width,height,value,size)
    local c=wm:CreateControl(name,parent,CT_LABEL)
    c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
    c:SetDimensions(width,height)
    c:SetFont(string.format('$(MEDIUM_FONT)|%d|soft-shadow-thin',size or 20))
    c:SetText(value or '')
    return c
end
local function initialize()
    db=ZO_SavedVars:NewAccountWide('IsoStats2SavedVariables',1,nil,defaults)
    S.InitializeStatusTracking()
    S.includeTargetBonuses=db.target
    S.InitializePenDiagnostics()
    S.InitializeCriticalDamage()
    -- Migrate previous category toggles and per-value preferences once.
    if not db.individualLayout then
        local mapping={weaponDamage='damage',spellDamage='damage',physicalPenetration='pen',
            spellPenetration='pen',weaponCritical='crit',spellCritical='crit',criticalDamage='crit'}
        local origin=db.modules.damage
        local originX=(origin and origin.x) or db.x or 80
        local originY=(origin and origin.y) or db.y or 240
        for _,g in ipairs(groups) do
            local old=db.modules[mapping[g.key]]
            local enabled=db.values[g.key]~=false and (not old or old.enabled~=false)
            db.modules[g.key]={enabled=enabled,x=originX+g.x-80,y=originY+g.y-240}
        end
        db.individualLayout=true
    end
    if not db.unifiedPenLayout then
        local physical, spell = db.modules.physicalPenetration, db.modules.spellPenetration
        local previous = physical and physical.enabled and physical or spell and spell.enabled and spell or physical or spell
        if previous then
            db.modules.penetration = {x=previous.x,y=previous.y,
                enabled=(physical and physical.enabled or spell and spell.enabled) and true or false}
        end
        db.unifiedPenLayout=true
    end
    if not db.unifiedCriticalLayout then
        local oldWeapon,oldSpell,oldDamage=db.modules.weaponCritical,db.modules.spellCritical,db.modules.criticalDamage
        local previous=oldWeapon and oldWeapon.enabled and oldWeapon or oldSpell and oldSpell.enabled and oldSpell or oldDamage and oldDamage.enabled and oldDamage or oldWeapon or oldSpell or oldDamage
        if previous then
            db.modules.critical={x=previous.x,y=previous.y,
                enabled=(oldWeapon and oldWeapon.enabled or oldSpell and oldSpell.enabled or oldDamage and oldDamage.enabled) and true or false}
        end
        db.unifiedCriticalLayout=true
    end
    if not db.unifiedResistanceLayout then
        local physical,spell,critical=db.modules.physicalResistance,db.modules.spellResistance,db.modules.criticalResistance
        local previous=physical and physical.enabled and physical or spell and spell.enabled and spell or critical and critical.enabled and critical or physical or spell or critical
        if previous then
            db.modules.resistance={x=previous.x,y=previous.y,
                enabled=(physical and physical.enabled or spell and spell.enabled or critical and critical.enabled) and true or false}
        end
        db.unifiedResistanceLayout=true
    end
    if not db.separateCriticalResistance then
        local combined=db.modules.resistance
        db.modules.criticalResistance={x=combined.x+320,y=combined.y,enabled=combined.enabled}
        db.separateCriticalResistance=true
    end
    if not db.unifiedPowerLayout then
        local weapon,spell=db.modules.weaponDamage,db.modules.spellDamage
        local previous=weapon and weapon.enabled and weapon or spell and spell.enabled and spell or weapon or spell
        if previous then
            db.modules.power={x=previous.x,y=previous.y,
                enabled=(weapon and weapon.enabled or spell and spell.enabled) and true or false}
        end
        db.unifiedPowerLayout=true
    end
    local lib=LibHarvensAddonSettings
    local settings={
        {type=lib.ST_SECTION,label='Allgemein'},
        {type=lib.ST_CHECKBOX,label='IsoStats2 aktivieren',getFunction=function() return db.enabled end,
         setFunction=function(value) db.enabled=value; render() end},
        {type=lib.ST_CHECKBOX,label='Ziel-Debuffs berücksichtigen',
         tooltip='Zeigt Pen und Krit-Schaden einschließlich Ziel-Debuffs und beobachteter Status-Effekte für Force of Nature. Ein Stern (*) markiert Zuschläge oder angenommene Boni. Backstabber nutzt die tatsächlich investierten CP-Stufen; die Flanke wird weiterhin angenommen.',
         getFunction=function() return db.target end,setFunction=function(value) db.target=value; render() end},
    }
    for _,g in ipairs(groups) do
        local key=g.key
        db.modules[key].size=db.modules[key].size or 100
        db.modules[key].spacing=db.modules[key].spacing or 100
        local w=wm:CreateTopLevelWindow('IsoStats2Window_'..key)
        windows[key]=w
        w:SetDimensions(g.width or WIDTH,48)
        w:SetClampedToScreen(true)
        w:SetDrawLayer(DL_OVERLAY)
        w:SetMouseEnabled(false)
        w:SetMovable(false)
        w:SetHandler('OnMoveStart',function() if moving==key then dragging=true end end)
        w:SetHandler('OnMoveStop',function() dragging=false; savePosition(key); lastInput=GetGameTimeMilliseconds() end)
        w.backdrop=wm:CreateControl(nil,w,CT_BACKDROP)
        w.backdrop:SetAnchorFill()
        w.backdrop:SetCenterColor(0.025,0.032,0.045,0.94)
        w.backdrop:SetEdgeTexture('',1,1,1)
        w.backdrop:SetEdgeColor(0,0,0,0)
        local function valueField(fieldKey,tag,x,tagWidth)
            fields[fieldKey]={
                value=label('IsoStats2Value'..fieldKey,w,x+2,4,112,40,'',30),
                label=label('IsoStats2Tag'..fieldKey,w,x+118,6,tagWidth or 62,24,tag,13),
                reserveTag=tag..((fieldKey=='criticalDamage' or fieldKey=='penetration') and '*' or ''),
            }
            fields[fieldKey].value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            fields[fieldKey].value:SetFont('$(BOLD_FONT)|26|soft-shadow-thick')
            fields[fieldKey].label:SetFont('$(BOLD_FONT)|12|soft-shadow-thin')
            fields[fieldKey].label:SetColor(g.accent[1],g.accent[2],g.accent[3],1)
            fields[fieldKey].value:SetColor(1,1,1,1)
            -- Measure once before any parent scaling, so changing HUD size
            -- cannot feed back into the layout and stretch its proportions.
            local template=(fieldKey=='criticalChance' or fieldKey=='criticalDamage') and '188.8%'
                or (fieldKey=='physicalResistance' or fieldKey=='spellResistance') and '888.888' or '88.888'
            fields[fieldKey].reserveWidth=fields[fieldKey].value:GetStringWidth(template)/GetUIGlobalScale()
            fields[fieldKey].reserveTagWidth=fields[fieldKey].label:GetStringWidth(fields[fieldKey].reserveTag)/GetUIGlobalScale()
            columnContentWidth=math.max(columnContentWidth,fields[fieldKey].reserveWidth+4,fields[fieldKey].reserveTagWidth)
        end
        if g.critical then
            valueField('criticalChance','CC',0,40)
            valueField('criticalDamage','CD',160,40)
            w.edgeLabel,w.edgeOffset=fields.criticalDamage.label,278
            w.firstValue=fields.criticalChance.value
            w.fieldKeys={'criticalChance','criticalDamage'}
        elseif g.resistance then
            valueField('physicalResistance','PR',0,40)
            valueField('spellResistance','SR',160,40)
            w.edgeLabel,w.edgeOffset=fields.spellResistance.label,278
            w.firstValue=fields.physicalResistance.value
            w.fieldKeys={'physicalResistance','spellResistance'}
        else
            valueField(key,g.tag,0)
            w.edgeLabel,w.edgeOffset=fields[key].label,118
            w.firstValue=fields[key].value
            w.fieldKeys={key}
        end
        -- Four uniform one-pixel texture strips avoid missing native backdrop
        -- edges on compact/resized HUDs. Same opacity as the original frame.
        w.frame={}
        local function edge(name,point,width,height)
            local line=wm:CreateControl(nil,w,CT_TEXTURE)
            line:SetTexture('IsoStats2/assets/white.dds')
            line:SetAnchor(point,w,point,0,0)
            line:SetDimensions(width,height)
            line:SetColor(0.65,0.70,0.78,0.25)
            line:SetDrawLayer(DL_OVERLAY)
            line:SetDrawTier(DT_HIGH)
            line:SetDrawLevel(10)
            line:SetPixelRoundingEnabled(false)
            w.frame[name]=line
        end
        edge('top',TOPLEFT,w:GetWidth(),1)
        edge('bottom',BOTTOMLEFT,w:GetWidth(),1)
        -- Stop the vertical strips at the horizontal ones to keep the corners
        -- from becoming brighter through overlapping transparency.
        edge('left',TOPLEFT,1,46)
        w.frame.left:ClearAnchors()
        w.frame.left:SetAnchor(TOPLEFT,w,TOPLEFT,0,1)
        edge('right',TOPRIGHT,1,46)
        w.frame.right:ClearAnchors()
        w.frame.right:SetAnchor(TOPRIGHT,w,TOPRIGHT,0,1)
        local function detail(name,parent,r,g,b,a)
            local control=wm:CreateControl(name,parent,CT_TEXTURE)
            control:SetTexture('IsoStats2/assets/white.dds')
            control:SetColor(r,g,b,a)
            control:SetPixelRoundingEnabled(false)
            return control
        end
        w.accent=detail(nil,w,g.accent[1],g.accent[2],g.accent[3],0.95)
        w.accent:SetAnchor(TOPLEFT,w,TOPLEFT,0,pixelSize())
        if g.critical or g.resistance then w.separator=detail(nil,w,0.65,0.70,0.78,0.18) end
        if g.pen then
            w.penTrack=detail(nil,w,0.46,0.85,0.76,0.16)
            w.penFill=detail(nil,w.penTrack,0.46,0.85,0.76,0.90)
        end
        w.hint=label(nil,w,0,-66,420,64,'Move UI: '..g.title..'\nRechter Stick · Speichert nach 3 Sekunden',18)
        w.hint:SetHidden(true)
        settings[#settings+1]={type=lib.ST_SECTION,label=g.title}
        settings[#settings+1]={type=lib.ST_CHECKBOX,label=g.title..' anzeigen',
            getFunction=function() return db.modules[key].enabled end,
            setFunction=function(value) db.modules[key].enabled=value; render() end}
        settings[#settings+1]={type=lib.ST_SLIDER,label=g.title..': Größe (%)',min=50,max=150,step=5,
            tooltip='Skaliert dieses gesamte HUD gleichmäßig samt Zahlen, Kürzeln und Abständen. Die Proportionen bleiben gleich. Rahmen bleiben ein Bildschirmpixel dünn. Kurze Vorschau beim Ändern.',
            getFunction=function() return db.modules[key].size or 100 end,
            setFunction=function(value)
                db.modules[key].size=math.max(50,math.min(150,tonumber(value) or 100))
                previewKey,previewUntil=key,GetGameTimeMilliseconds()+5000
                render()
            end}
        settings[#settings+1]={type=lib.ST_SLIDER,label=g.title..': Abstände (%)',min=25,max=150,step=5,
            tooltip='Kleinere Werte machen die Kachel enger: weniger Rand und weniger Abstand zwischen den Spalten CC/CD oder PR/SR. Schriftgröße bleibt gleich. Kurze Vorschau beim Ändern.',
            getFunction=function() return db.modules[key].spacing or 100 end,
            setFunction=function(value)
                db.modules[key].spacing=math.max(25,math.min(150,tonumber(value) or 100))
                previewKey,previewUntil=key,GetGameTimeMilliseconds()+5000
                render()
            end}
        if g.pen then
            settings[#settings+1]={type=lib.ST_BUTTON,label='PEN: mit originalem IsoStats vergleichen',buttonText='Kampfvergleich im Chat',
                tooltip='Zeigt den gespeicherten Kampfvergleich beider Rechnungen vom selben Zeitpunkt beim höchsten beobachteten IsoStats2-PEN-Wert. Ohne Messung: aktuelle Werte. Original nicht lesbar: klar gekennzeichnete ALT-LOGIK. Neuer Kampf oder Diagnose-Reset leert die Aufzeichnung.',
                clickHandler=function() for _,line in ipairs(S.GetPenetrationComparison()) do d(line) end end}
            settings[#settings+1]={type=lib.ST_BUTTON,label='PEN: Berechnung anzeigen',buttonText='Aufschlüsselung im Chat',
                tooltip='Zeigt die aktuelle Messung UND den höchsten beobachteten Wert des letzten Tests. Der gespeicherte Kampfwert bleibt nach Ablauf der Buffs erhalten. Dazu Status-Ereignisse und Ziel-ID zur Fehlersuche.',
                clickHandler=function() for _,line in ipairs(S.GetPenetrationReport(db.target)) do d(line) end end}
            settings[#settings+1]={type=lib.ST_BUTTON,label='PEN: Diagnose zurücksetzen',buttonText='Neuen Test beginnen',
                tooltip='Löscht die gespeicherten PEN- und CD-Testmessungen gemeinsam. Danach Ziel anvisieren und angreifen. Ändert weder Berechnung noch HUD-Einstellungen.',
                clickHandler=function() S.ResetPenDiagnosticHistory(); d('IsoStats2: PEN- und CD-Testmessungen zurückgesetzt.') end}
            settings[#settings+1]={type=lib.ST_SLIDER,label='PEN: Zielwert',min=100,max=33000,step=100,
                tooltip='Ab diesem angezeigten Pen-Wert wird die Zahl grün. Standard: 18200 wie bei Meterskull. Berücksichtigt die eingeschalteten Ziel-Zuschläge. Andere Gegner können einen anderen Zielwert benötigen.',
                getFunction=function() return db.penTarget or 18200 end,
                setFunction=function(value)
                    db.penTarget=math.max(100,math.min(33000,tonumber(value) or 18200))
                    previewKey,previewUntil=key,GetGameTimeMilliseconds()+5000
                    render()
                end}
        end
        if g.critical then
            settings[#settings+1]={type=lib.ST_CHECKBOX,label='CD: nutzbaren Wert anzeigen',
                tooltip='Zeigt den am Krit-Cap begrenzten Wert im bestehenden CD-Feld. Aus: rechnerischer Gesamtbonus. Die Aufschlüsselung enthält immer beide Werte. Backstabber setzt weiterhin Flankieren voraus.',
                getFunction=function() return db.criticalShowEffective end,
                setFunction=function(value) db.criticalShowEffective=value; render() end}
            settings[#settings+1]={type=lib.ST_CHECKBOX,label='CD: Krit-Cap automatisch',
                tooltip='125 Prozent Standard; 155 bei aktiver, erlernter Above-and-Beyond-Meisterschaft (ID 263605). Bei abweichenden PTS-Regeln ausschalten und den Cap manuell setzen.',
                getFunction=function() return db.criticalCapAutomatic end,
                setFunction=function(value) db.criticalCapAutomatic=value; S.InvalidateCriticalCache(); render() end}
            settings[#settings+1]={type=lib.ST_SLIDER,label='CD: manueller Krit-Cap',min=125,max=155,step=30,
                tooltip='Wird nur verwendet, wenn die automatische Cap-Erkennung ausgeschaltet ist.',
                getFunction=function() return db.criticalCap end,
                setFunction=function(value) db.criticalCap=tonumber(value) or 125; render() end}
            settings[#settings+1]={type=lib.ST_CHECKBOX,label='CD: Schatten-Korrektur wie CMX',
                tooltip='Optionaler historischer LibCombat-Workaround: addiert nur die Differenz zwischen Schatten/Göttlich-Berechnung und Effekttext. Standard AUS, da der Charakterwert auf neueren Spielversionen bereits korrekt sein kann. cdinfo zeigt die Werte auch ausgeschaltet.',
                getFunction=function() return db.shadowCorrection end,
                setFunction=function(value) db.shadowCorrection=value; render() end}
            settings[#settings+1]={type=lib.ST_BUTTON,label='CD: Berechnung anzeigen',buttonText='Aufschlüsselung im Chat',
                tooltip='Aktuelle CD-Werte und gespeicherter höchster Kampfwert: Basis, Charakterbonus, Backstabber, Ziel-Debuffs, Cap und Überschuss.',
                clickHandler=function() for _,line in ipairs(S.GetCriticalDamageReport()) do d(line) end end}
        end
        settings[#settings+1]={type=lib.ST_BUTTON,label='Move UI: '..g.title,buttonText='Anzeige verschieben',
            tooltip='Verschiebt nur diese Anzeige. Speichert nach 3 Sekunden ohne Bewegung.',
            clickHandler=function() setMoving(key) end}
        settings[#settings+1]={type=lib.ST_BUTTON,label=g.title..': Position zurücksetzen',buttonText='Zurücksetzen',
            clickHandler=function() if moving==key then setMoving(nil) end; anchor(key,g.x,g.y); render() end}
    end
    local panel=lib:AddAddon('IsoStats2',{allowRefresh=true})
    panel.version=S.version
    panel:AddSettings(settings)
    SLASH_COMMANDS['/isostats2']=function(command)
        command=(command or ''):match('^%s*(.-)%s*$')
        if command=='compare' or command=='compare live' or command=='compare last' then
            local mode=command=='compare live' and 'live' or command=='compare last' and 'last' or nil
            for _,line in ipairs(S.GetPenetrationComparison(mode)) do d(line) end
            return
        end
        if command=='version' then d('IsoStats2 '..S.version); return end
        if command=='peninfo' then for _,line in ipairs(S.GetPenetrationReport(db.target)) do d(line) end; return end
        if command=='peninfo live' or command=='peninfo last' then
            for _,line in ipairs(S.GetPenetrationReport(db.target,command=='peninfo live' and 'live' or 'last')) do d(line) end
            return
        end
        if command=='peninfo reset' then S.ResetPenDiagnosticHistory(); d('IsoStats2: PEN- und CD-Testmessungen zurückgesetzt.'); return end
        if command=='cdinfo' or command=='cdinfo live' or command=='cdinfo last' then
            local mode=command=='cdinfo live' and 'live' or command=='cdinfo last' and 'last' or nil
            for _,line in ipairs(S.GetCriticalDamageReport(mode)) do d(line) end
            return
        end
        if command=='cdinfo reset' then S.ResetPenDiagnosticHistory(); d('IsoStats2: PEN- und CD-Testmessungen zurückgesetzt.'); return end
        local aliases={damage='power',schaden='power',pwr='power',weaponDamage='power',spellDamage='power',pen='penetration',physicalPenetration='penetration',spellPenetration='penetration',crit='critical',krit='critical',criticalDamage='critical',weaponCritical='critical',spellCritical='critical',criticalChance='critical',res='resistance',physicalResistance='resistance',spellResistance='resistance',move='power'}
        local key=aliases[command] or (windows[command] and command)
        if key then
            if moving==key then setMoving(nil) else setMoving(key) end
        else db.enabled=not db.enabled; render() end
    end
    em:RegisterForEvent(S.name,EVENT_PLAYER_DEACTIVATED,function() if moving then setMoving(nil) end end)
    em:RegisterForEvent(S.name,EVENT_ACTIVE_WEAPON_PAIR_CHANGED,render)
    em:RegisterForEvent(S.name,EVENT_RETICLE_TARGET_CHANGED,render)
    em:RegisterForUpdate(S.name..'Stats',200,render)
    render()
    if (db.tileLayoutVersion or 0)<2 then
        -- Give the redesigned copy an initial arrangement without overlapping
        -- the taller cards. This runs once; later manual positions are retained.
        local rows={{'power','penetration'},{'critical'},{'resistance'},{'criticalResistance'}}
        local widths,heights={},{}
        local widest,totalHeight,gap=0,0,8
        for index,row in ipairs(rows) do
            local rowWidth,rowHeight=0,0
            for column,key in ipairs(row) do
                local w=windows[key]
                rowWidth=rowWidth+w:GetWidth()*w.scaleFactor+(column>1 and gap or 0)
                rowHeight=math.max(rowHeight,w:GetHeight()*w.scaleFactor)
            end
            widths[index],heights[index]=rowWidth,rowHeight
            widest=math.max(widest,rowWidth)
            totalHeight=totalHeight+rowHeight+(index>1 and gap or 0)
        end
        local baseX=math.max(0,math.min(db.modules.power.x,GuiRoot:GetWidth()-widest))
        local y=math.max(0,math.min(db.modules.power.y,GuiRoot:GetHeight()-totalHeight))
        for index,row in ipairs(rows) do
            local x=baseX
            for _,key in ipairs(row) do
                anchor(key,x,y)
                x=x+windows[key]:GetWidth()*windows[key].scaleFactor+gap
            end
            y=y+heights[index]+gap
        end
        db.tileLayoutVersion=2
        render()
    end
end
em:RegisterForEvent(S.name,EVENT_ADD_ON_LOADED,function(_,name)
    if name~=S.name then return end
    em:UnregisterForEvent(S.name,EVENT_ADD_ON_LOADED)
    initialize()
end)
