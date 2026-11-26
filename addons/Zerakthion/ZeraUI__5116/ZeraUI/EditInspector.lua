-- Zera UI: Interactive Edit Mode live Inspector panel and widget visual schemas.
-- Created lazily on first Edit Mode entry; hidden on exit with zero combat cost.
function ZeraUIAttachEditInspector(A,UI)
    local WM=WINDOW_MANAGER
    local function tr(text) return A.settings and A.settings.menuLanguage=="tr" and ZeraUITranslate(text) or text end

    local OUTLINES={"thick-outline","outline","thin-outline","normal","shadow","soft-shadow-thin","soft-shadow-thick"}
    local INHERIT_OUTLINES={"HUD outline","thick-outline","outline","thin-outline","normal","shadow","soft-shadow-thin","soft-shadow-thick"}

    local function hudFonts()
        return A:FontChoices()
    end
    local function inheritFonts()
        local list={"HUD font"}
        for _,v in ipairs(A:FontChoices()) do list[#list+1]=v end
        return list
    end

    -- Coalesced per-frame visual apply so dragging sliders updates smoothly once per frame.
    local pendingScope
    local function queueApply(scope)
        scope=scope or "hud"
        if pendingScope=="all" or scope=="all" then pendingScope="all"
        elseif pendingScope and pendingScope~=scope then pendingScope="all"
        else pendingScope=scope end
        if A.editApplyScheduled then return end
        A.editApplyScheduled=true
        local run=function()
            A.editApplyScheduled=false
            local s=pendingScope or "hud"
            pendingScope=nil
            if not A.editing then return end
            if A.ApplyScopedVisual then A:ApplyScopedVisual(s) else A:ApplySettings() end
        end
        if zo_callLater then zo_callLater(run,1) else run() end
    end

    -- Concise control descriptors for each widget schema.
    local function hdr(label) return {kind="header",label=label} end
    local function note(text) return {kind="note",label=text} end
    local function chk(label,key,scope,onSet) return {kind="bool",label=label,key=key,scope=scope,onSet=onSet} end
    local function sld(label,key,min,max,step,scope,mode,onSet)
        return {kind="slider",label=label,key=key,min=min,max=max,step=step,scope=scope,mode=mode,onSet=onSet}
    end
    local function drp(label,key,choices,scope,onSet,choicesValues)
        return {kind="dropdown",label=label,key=key,choices=choices,choicesValues=choicesValues,scope=scope,onSet=onSet}
    end
    local function clr(label,key,scope) return {kind="color",label=label,key=key,scope=scope} end
    local function act(label,fn) return {kind="button",label=label,fn=fn} end

    local function effectSchema(prefix,isDebuff)
        local list={
            hdr("Layout"),
            chk("Lock position",prefix.."Locked","effects"),
            sld("Icons per row",prefix.."Columns",1,16,1,"effects","effectSize"),
            drp("Horizontal growth",prefix.."Grow",{"Right to left","Left to right","Center"},"effects"),
            chk("Single row",prefix.."SingleRow","effects"),
            sld("Icon size (pixels)",prefix.."Size",20,100,1,"effects","effectSize"),
            sld("Icon gap",prefix.."Gap",0,20,1,"effects","effectSize"),
            hdr("Typography"),
            drp("Font family",prefix.."Font",inheritFonts,"effects"),
            drp("Font outline",prefix.."Outline",INHERIT_OUTLINES,"effects"),
            sld("Timer font scale",prefix.."FontSize",12,48,1,"effects"),
            sld("Stack font scale",prefix.."StackSize",10,30,1,"effects"),
            chk("Show stacks",prefix.."Stacks","effects"),
            hdr("Visuals & colors"),
            chk("Countdown fill",prefix.."Fill","effects"),
            chk("Expiry flash",prefix.."Flash","effects"),
            sld("Flash threshold (seconds)",prefix.."FlashSeconds",1,10,1,"effects"),
        }
        if isDebuff then list[#list+1]=chk("Highlight debuffs",prefix.."HighlightDebuffs","effects") end
        list[#list+1]=clr(isDebuff and "Highlight & fill color" or "Fill color",prefix.."Color","effects")
        return list
    end

    local ATTR_MODE_LABELS={"Off","Default Attribute Bar","Custom Attribute Bar"}
    local ATTR_MODE_VALUES={"Off","Default","Custom"}
    local function switchAttributeMode(v)
        A:SetAttributeMode(v)
        if v=="Off" then
            if A.SelectEdit then A:SelectEdit(nil) end
            if A.UpdateEditHandles then A:UpdateEditHandles() end
            if A.RefreshEditInspector then A:RefreshEditInspector() end
        elseif A.SelectAttributeEditTarget then
            A:SelectAttributeEditTarget()
        else
            if A.UpdateEditHandles then A:UpdateEditHandles() end
            if A.RefreshEditInspector then A:RefreshEditInspector() end
        end
    end
    local function switchAttributeLayout(v)
        A:SetAttributeLayout(v)
        if A.SelectAttributeEditTarget then A:SelectAttributeEditTarget()
        else
            if A.UpdateEditHandles then A:UpdateEditHandles() end
            if A.RefreshEditInspector then A:RefreshEditInspector() end
        end
    end
    local attrFlatSchema={
        hdr("Layout"),
        drp("Attribute bars","attrMode",ATTR_MODE_LABELS,"all",switchAttributeMode,ATTR_MODE_VALUES),
        drp("Layout","attrLayout",function() return A:AttributeLayoutChoices() end,"all",switchAttributeLayout),
        chk("Move attributes individually","attrSplit","attributes",function(v)
            A.settings.attrSplit=v
            queueApply("attributes")
            if A.SelectAttributeEditTarget then A:SelectAttributeEditTarget() end
        end),
        sld("Bar scale","attrScale",.5,1.8,.05,"attributes","hudSize"),
        sld("Bar width","attrWidth",100,300,1,"attributes","hudSize"),
        sld("Gap between bars","attrGap",0,20,1,"attributes","hudSize"),
        hdr("Typography"),
        drp("Attribute font","attrFont",inheritFonts,"attributes"),
        drp("Attribute text outline","attrOutline",OUTLINES,"attributes"),
        drp("Value format","attrFormat",{"Short","Full","Full / Max"},"attributes"),
        chk("Show percentage next to value","attrPercent","attributes"),
        sld("Text size","attrTextSize",10,28,1,"attributes"),
        sld("Text vertical offset","attrTextOffsetY",-10,10,1,"attributes"),
    }

    local SCHEMAS={
        ["__global"]={
            hdr("Global HUD"),
            sld("HUD scale","scale",.6,1.6,.05,"hud","hudSize"),
            drp("Attribute bars","attrMode",ATTR_MODE_LABELS,"all",switchAttributeMode,ATTR_MODE_VALUES),
            drp("Font family","fontFace",hudFonts,"all"),
            drp("Duration outline","fontStyle",OUTLINES,"all"),
            chk("Move HUD together (linked)","moveTogether","hud",function(v)
                A.settings.moveTogether=v
                if A.UpdateEditHandles then A:UpdateEditHandles() end
            end),
            hdr("Editor grid"),
            chk("Show alignment grid","editShowGrid",nil,function(v)
                A.settings.editShowGrid=v
                if A.RefreshEditGrid then A:RefreshEditGrid() end
                if A.UpdateEditHandles then A:UpdateEditHandles() end
            end),
            sld("Edit snap grid (pixels)","editSnap",0,64,1,nil,nil,function(v)
                A.settings.editSnap=v
                if A.RefreshEditGrid then A:RefreshEditGrid() end
                if A.UpdateEditHandles then A:UpdateEditHandles() end
            end),
            note("Click any widget to customize its appearance. Right-click a widget for quick alignment and reset actions."),
        },
        ["Action bar"]={
            hdr("Layout"),
            sld("Skill icon size","skillSize",32,96,1,"hud","hudSize"),
            sld("Horizontal skill spacing","gapX",0,24,1,"hud","hudSize"),
            sld("Vertical bar spacing","gapY",0,28,1,"hud","hudSize"),
            chk("Show active bar arrow","showArrow","hud"),
            drp("Active bar arrow style","arrowStyle",{"Classic","Large","Left","Double"},"hud"),
            chk("Active bar on top","activeBarOnTop","hud"),
            chk("Show keybind labels","showHotkeys","hud"),
            sld("Keybind font size","keySize",10,22,1,"hud"),
            sld("Inactive icon desaturation","inactiveDesaturation",0,1,.05,"hud"),
            sld("Inactive icon opacity","inactiveAlpha",.2,1,.05,"hud"),
            hdr("Timers & text"),
            sld("Duration font size","timerSize",16,44,1,"hud"),
            drp("Duration outline","fontStyle",OUTLINES,"all"),
            chk("Color timers orange/red near expiration","warningColors","hud"),
            clr("Default timer color","normalColor","hud"),
            clr("Soon warning color","soonColor","hud"),
            clr("Final warning color","lastColor","hud"),
            clr("Second effect color","secondColor","hud"),
            clr("Third effect color","thirdColor","hud"),
            hdr("Corner timers"),
            sld("Lower-left timer font size","extraLeftSize",10,22,1,"hud"),
            sld("Lower-left timer X","extraLeftX",-32,32,1,"hud"),
            sld("Lower-left timer Y","extraLeftY",-32,32,1,"hud"),
            sld("Lower-right timer font size","extraRightSize",10,22,1,"hud"),
            sld("Lower-right timer X","extraRightX",-32,32,1,"hud"),
            sld("Lower-right timer Y","extraRightY",-32,32,1,"hud"),
            hdr("Counters & badges"),
            chk("Show stack counts","showStacks","hud"),
            chk("Show usage charges","showCharges","hud"),
            chk("Stack count badge","stackBadge","hud"),
            sld("Stack font size","stackSize",10,28,1,"hud"),
            clr("Stack counter color","stackColor","hud"),
            clr("Usage charge color","chargeColor","hud"),
            sld("Target count font size","targetSize",10,22,1,"hud"),
            clr("Target count color","targetColor","hud"),
            sld("Passive and auxiliary badge font size","cornerBadgeSize",10,24,1,"hud"),
            hdr("Fill & glows"),
            chk("Show green duration fill","showFill","hud"),
            clr("Duration fill color / opacity","fillColor","hud"),
            clr("Glow tint","glowColor","hud"),
            clr("Toggle glow color","togglePulseColor","hud"),
            clr("Proc glow color","procColor","hud"),
        },
        ["Attributes"]=attrFlatSchema,
        ["Health"]=attrFlatSchema,
        ["Magicka"]=attrFlatSchema,
        ["Stamina"]=attrFlatSchema,
        ["curved"]={
            hdr("Layout"),
            drp("Attribute bars","attrMode",ATTR_MODE_LABELS,"all",switchAttributeMode,ATTR_MODE_VALUES),
            drp("Layout","attrLayout",function() return A:AttributeLayoutChoices() end,"all",switchAttributeLayout),
            sld("Arc size","curvedScale",.6,1.8,.05,"attributes"),
            sld("Space between arcs","curvedGap",250,800,5,"attributes",nil,function(v)
                if A.SetCurvedGap then A:SetCurvedGap(v) else A.settings.curvedGap=v; queueApply("attributes") end
            end),
            hdr("Typography & shield"),
            drp("Attribute font","attrFont",inheritFonts,"attributes"),
            drp("Attribute text outline","attrOutline",OUTLINES,"attributes"),
            drp("Value format","attrFormat",{"Short","Full","Full / Max"},"attributes"),
            chk("Show percentage next to value","attrPercent","attributes"),
            sld("Arc percentage size","curvedPercentSize",10,30,1,"attributes"),
            sld("Arc value size","curvedValueSize",8,26,1,"attributes"),
            sld("Shield opacity","curvedShieldAlpha",.1,1,.05,"attributes"),
        },
        ["Ultimate"]={
            hdr("Layout & style"),
            sld("Ultimate size","ultScale",.5,1.8,.05,"hud","hudSize"),
            drp("Overload style","overloadStyle",{"Classic","Gapless bright core"},"hud",nil,{"Classic","Gapless"}),
            hdr("Typography"),
            sld("Ultimate points font","ultValueSize",12,36,1,"hud"),
            sld("Ultimate cost font","ultCostSize",10,32,1,"hud"),
            sld("Ultimate duration font","ultDurationSize",10,32,1,"hud"),
            hdr("Colors"),
            clr("Ultimate ring color","ultimateColor","hud"),
            clr("Active ultimate ring color","activeUltColor","hud"),
            clr("Affordable ultimate cost color","readyColor","hud"),
            clr("Unaffordable ultimate cost color","unreadyColor","hud"),
        },
        ["Potion"]={
            hdr("Layout & typography"),
            sld("Quickslot size","quickScale",.5,1.8,.05,"hud","hudSize"),
            sld("Quickslot timer font","quickTimerSize",12,36,1,"hud"),
            sld("Potion count font size","quickCountSize",8,24,1,"hud"),
            drp("Potion count position","quickCountPosition",{"Inside bottom","Bottom","Top","Left","Top left","Top right"},"hud"),
            hdr("Colors"),
            clr("Quickslot ring color","quickColor","hud"),
        },
        ["Cast bar"]={
            hdr("Layout & typography"),
            sld("GCD size","castScale",.5,1.8,.05,"hud","hudSize"),
            sld("GCD font size","castFontSize",10,28,1,"hud"),
            sld("GCD countdown font size","castTimeSize",10,28,1,"hud"),
            hdr("Colors"),
            clr("GCD fill tint","castColor","hud"),
            clr("Channel fill tint","channelColor","hud"),
        },
        ["Synergy"]={
            hdr("Layout & typography"),
            sld("Synergy size","synergyScale",.5,1.8,.05,"hud","hudSize"),
            chk("Show synergy name","synergyName","hud"),
            chk("Show synergy key","synergyShowKey","hud"),
            sld("Synergy name font","synergyTextSize",10,28,1,"hud"),
            sld("Synergy key font","synergyKeySize",10,26,1,"hud"),
            act("Preview synergy appearance",function()
                if not (A.settings and A.settings.showSynergy) then return end
                if A.FadeSynergy then A:FadeSynergy(true,true) end
                if A.FlashSynergy then A:FlashSynergy() end
            end),
        },
        ["Class ultimate-generation cooldowns"]={
            hdr("Typography"),
            sld("Class cooldown font size","passiveTimerSize",0,40,1,"hud"),
        },
        ["setCooldown"]={
            hdr("Layout"),
            chk("Lock set widget position","setCooldownLocked","sets"),
            drp("Icon layout","setCooldownDirection",{"Vertical","Horizontal"},"sets"),
            sld("Set icon size (pixels)","setCooldownIconSize",24,128,1,"sets"),
            sld("Set widget scale","setCooldownScale",.5,2,.05,"sets"),
            sld("Set icon spacing","setCooldownGap",0,40,1,"sets"),
            hdr("Typography"),
            drp("Set font family","setCooldownFont",inheritFonts,"sets"),
            drp("Set font outline","setCooldownOutline",INHERIT_OUTLINES,"sets"),
            sld("Set countdown font size","setCooldownFontSize",10,60,1,"sets"),
            chk("Show set stacks & counts","setCooldownShowStacks","sets"),
            sld("Set stack font size","setCooldownStackSize",8,40,1,"sets"),
            sld("Set secondary timer font size","setCooldownSecondarySize",8,32,1,"sets"),
            chk("Show set names","setCooldownNames","sets"),
            drp("Set name position","setCooldownNamePosition",{"Right","Left","Above","Below"},"sets"),
            chk("Set name background","setCooldownNameBg","sets"),
            sld("Set name font size","setCooldownNameSize",8,28,1,"sets"),
            hdr("Visuals"),
            chk("Set progress fill","setCooldownShowFill","sets"),
            chk("Set glow effects","setCooldownShowGlow","sets"),
            chk("Set icon frame","setCooldownShowFrame","sets"),
            chk("Desaturate cooldown / off-bar icons","setCooldownDesaturate","sets"),
            chk("Color set countdown by state","setCooldownColorTimer","sets"),
            chk("Color set frame by state","setCooldownColorFrame","sets"),
            hdr("Colors"),
            clr("Set active color","setCooldownActiveColor","sets"),
            clr("Set cooldown color","setCooldownCooldownColor","sets"),
            clr("Set ready color","setCooldownReadyColor","sets"),
            clr("Set resource value color","setCooldownValueColor","sets"),
            clr("Set off-bar color","setCooldownOffBarColor","sets"),
            clr("Set fixed countdown color","setCooldownTimerColor","sets"),
            clr("Set stack color","setCooldownStackColor","sets"),
            clr("Set secondary timer color","setCooldownSecondaryColor","sets"),
            clr("Set name color","setCooldownNameColor","sets"),
        },
        ["effectSelf"]=effectSchema("effectSelf",false),
        ["effectSelfDebuff"]=effectSchema("effectSelfDebuff",true),
        ["effectTarget"]=effectSchema("effectTarget",false),
        ["effectTargetDebuff"]=effectSchema("effectTargetDebuff",true),
        ["offBalance"]={
            hdr("Layout & typography"),
            chk("Lock Off Balance position","offBalanceLocked","effects"),
            sld("Off Balance icon size (pixels)","offBalanceSize",20,100,1,"effects","effectSize"),
            sld("Off Balance timer font scale","offBalanceFontSize",12,48,1,"effects"),
            drp("Off Balance font family","offBalanceFont",inheritFonts,"effects"),
            drp("Off Balance font outline","offBalanceOutline",INHERIT_OUTLINES,"effects"),
            hdr("Visuals & colors"),
            chk("Off Balance countdown fill","offBalanceFill","effects"),
            clr("Off Balance active color","offBalanceActiveColor","effects"),
            clr("Off Balance immunity color","offBalanceImmuneColor","effects"),
            clr("Off Balance ready color","offBalanceReadyColor","effects"),
        },
        ["playerInteraction"]={
            note("Native ESO prompt: drag, nudge, or use Reset Position. Appearance stays managed by ESO."),
        },
        ["instanceKick"]={
            note("Native ESO warning: drag, nudge, or use Reset Position. Appearance stays managed by ESO."),
        },
        ["reticleInteract"]={
            note("Native ESO prompt: drag, nudge, or use Reset Position. Appearance stays managed by ESO."),
        },
        ["tutorialTip"]={
            note("Native ESO tip: drag, nudge, or use Reset Position. Appearance stays managed by ESO."),
        },
        ["interactWindow"]={
            note("Native ESO dialogue window: drag, nudge, or use Reset Position. Appearance stays managed by ESO."),
        },
    }

    local function collectSchemaKeys(widgetKey)
        local schema=SCHEMAS[widgetKey]
        if not schema then return {} end
        local list,seen={},{}
        for _,item in ipairs(schema) do
            if item.key and not seen[item.key] and item.key~="attrMode" and item.key~="attrLayout" and item.key~="attrSplit" then
                seen[item.key]=true; list[#list+1]=item.key
            end
        end
        return list
    end

    function A:HasWidgetAppearance(widgetKey)
        if not widgetKey or widgetKey=="playerInteraction" or widgetKey=="instanceKick" or widgetKey=="reticleInteract" or widgetKey=="tutorialTip" or widgetKey=="interactWindow" then return false end
        return #collectSchemaKeys(widgetKey)>0
    end

    function A:ResetWidgetAppearance(widgetKey)
        local list=collectSchemaKeys(widgetKey)
        if #list==0 then return end
        if self.ResetKeysToDefault then
            self:ResetKeysToDefault(list)
        else
            for _,k in ipairs(list) do self.settings[k]=self:DefaultSetting(k) end
        end
        local scope="all"
        if widgetKey=="setCooldown" then scope="sets"
        elseif widgetKey=="offBalance" or widgetKey=="effectSelf" or widgetKey=="effectSelfDebuff" or widgetKey=="effectTarget" or widgetKey=="effectTargetDebuff" then scope="effects"
        elseif widgetKey=="Attributes" or widgetKey=="Health" or widgetKey=="Magicka" or widgetKey=="Stamina" or widgetKey=="curved" then scope="attributes"
        elseif widgetKey=="Ultimate" or widgetKey=="Potion" or widgetKey=="Cast bar" or widgetKey=="Synergy" or widgetKey=="Class ultimate-generation cooldowns" then scope="hud" end
        if self.ApplyScopedVisual then self:ApplyScopedVisual(scope) else self:ApplySettings() end
        self:RefreshEditInspector()
    end

    -- Apply one control value change with the right sizing helper and scoped refresh.
    local function commitValue(item,value)
        if item.onSet then
            item.onSet(value)
            return
        end
        if item.mode=="hudSize" then
            A:SetHudSize(item.key,value)
        elseif item.mode=="effectSize" and A.effectHUD then
            A.effectHUD:SetSizeOption(item.key,value)
        else
            A.settings[item.key]=value
        end
        if item.scope then queueApply(item.scope) end
    end

    local function fmtNumber(val,step)
        if step and step<1 then return string.format("%.2f",val) end
        return tostring(math.floor(val+.5))
    end

    local function clampStep(val,minV,maxV,step)
        val=math.max(minV,math.min(maxV,val))
        val=math.floor(val/step+.5)*step
        if step<1 then val=math.floor(val*100+.5)/100 end
        return math.max(minV,math.min(maxV,val))
    end

    -- Studio visual theme & Rajdhani Bold helpers (reuses A.studioStyle from Studio.lua).
    local CORAL={.871,.353,.447,1}
    local function rgba(c) return c[1],c[2],c[3],c[4] or 1 end
    local function theme()
        local s=A.studioStyle
        if s and s.prepareFont then s.prepareFont() end
        return s
    end
    local function palette(s)
        if s then return s.cream,s.card,s.field,s.ink,s.soft,s.yellow,s.teal end
        return {.906,.875,.800,1},{.941,.914,.855,1},{.886,.847,.761,1},{.086,.086,.086,1},{.33,.32,.30,1},{.953,.800,.310,1},{.373,.776,.682,1}
    end
    local WHITE={1,1,1,1}
    local function makeFill(s,parent,x,y,w,h,color,edge,thickness,level,layer)
        local b
        if s and s.fill then b=s.fill(parent,x,y,w,h,color,edge,thickness,level)
        else
            b=WM:CreateControl(nil,parent,CT_BACKDROP)
            b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
            b:SetCenterColor(rgba(color)); b:SetEdgeColor(rgba(edge)); b:SetEdgeTexture("",1,1,thickness or 2)
            b:SetDrawLayer(DL_BACKGROUND); b:SetDrawLevel(level or 1)
        end
        if layer then b:SetDrawLayer(layer) end
        return b
    end
    local function makeLabel(s,parent,value,x,y,w,size,color,align,h)
        if s and s.label then return s.label(parent,value,x,y,w,size,color,align,h,true) end
        local l=WM:CreateControl(nil,parent,CT_LABEL)
        l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y); l:SetDimensions(w,h or (size+8))
        l:SetFont(string.format("$(BOLD_FONT)|$(KB_%d)",size or 15))
        l:SetColor(rgba(color)); l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT); l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        l:SetDrawLayer(DL_TEXT or DL_CONTROLS); l:SetText(value or "")
        return l
    end
    local function makeButton(s,parent,value,x,y,w,h,fn,accent,small,level,layer)
        if s and s.button then
            local b=s.button(parent,value,x,y,w,h,fn,accent,small)
            if accent==CORAL and b.SetTextColor then b:SetTextColor(WHITE) end
            if layer then
                if b.shadow then b.shadow:SetDrawLayer(layer) end
                if b.face then b.face:SetDrawLayer(layer) end
            end
            if level then
                if b.shadow then b.shadow:SetDrawLevel(level) end
                if b.face then b.face:SetDrawLevel(level+1) end
                if b.text then b.text:SetDrawLevel(level+3) end
            end
            return b
        end
        local b=WM:CreateControl(nil,parent,CT_BUTTON)
        b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
        b:SetFont("$(BOLD_FONT)|14|thick-outline"); b:SetText(value or ""); b:SetMouseEnabled(true)
        b:SetHandler("OnClicked",fn)
        function b:SetLabel(v) self:SetText(v or "") end
        function b:SetAccent() end
        function b:SetTextColor() end
        return b
    end

    -- Reusable row pool per control kind so switching widgets never leaks controls.
    local inspector
    local WIN_W,MAX_H=356,560
    local CONTENT_W=310
    local ROW_LAYER=DL_CONTROLS or 1

    local function createRowControl(kind,parent)
        local s=theme()
        local _,CARD,FIELD,INK,INK_SOFT,YELLOW,TEAL=palette(s)
        local row=WM:CreateControl(nil,parent,CT_CONTROL)
        row:SetWidth(CONTENT_W)
        row.kind=kind
        if kind=="header" then
            row:SetHeight(28)
            local strip=makeFill(s,row,0,2,CONTENT_W,24,YELLOW,INK,2,4,ROW_LAYER)
            local lbl=makeLabel(s,strip,"",8,-2,CONTENT_W-16,13,INK,TEXT_ALIGN_LEFT,24)
            lbl:SetDrawLevel(9)
            row.label=lbl
        elseif kind=="note" then
            row:SetHeight(50)
            local box=makeFill(s,row,0,2,CONTENT_W,46,FIELD,INK,2,4,ROW_LAYER)
            local lbl=makeLabel(s,box,"",8,2,CONTENT_W-16,12,INK_SOFT,TEXT_ALIGN_LEFT,40)
            lbl:SetMaxLineCount(3); lbl:SetDrawLevel(9)
            row.label=lbl
        elseif kind=="bool" then
            row:SetHeight(28)
            local lbl=makeLabel(s,row,"",2,0,CONTENT_W-86,14,INK,TEXT_ALIGN_LEFT,26)
            local stateLbl=makeLabel(s,row,"",CONTENT_W-80,0,34,12,INK_SOFT,TEXT_ALIGN_RIGHT,26)
            local track=makeFill(s,row,CONTENT_W-38,3,38,22,FIELD,INK,2,4,ROW_LAYER)
            local knob=makeFill(s,track,4,4,14,14,INK,INK,1,6,ROW_LAYER)
            local hit=WM:CreateControl(nil,track,CT_BUTTON)
            hit:SetAnchorFill(track); hit:SetMouseEnabled(true)
            hit:SetDrawLayer(ROW_LAYER); hit:SetDrawLevel(20)
            hit:SetHandler("OnMouseUp",function(_,mouse,inside)
                if not A.editing or inside==false or (MOUSE_BUTTON_INDEX_LEFT and mouse~=MOUSE_BUTTON_INDEX_LEFT) then return end
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
                if row.onToggle then row.onToggle() end
            end)
            row.label=lbl; row.stateLbl=stateLbl; row.track=track; row.knob=knob
        elseif kind=="slider" then
            row:SetHeight(46)
            local lbl=makeLabel(s,row,"",2,0,CONTENT_W-66,13,INK,TEXT_ALIGN_LEFT,22)
            local chip=makeFill(s,row,CONTENT_W-56,0,56,22,FIELD,INK,2,4,ROW_LAYER)
            local valLbl=makeLabel(s,chip,"",2,-2,52,13,INK,TEXT_ALIGN_CENTER,22)
            valLbl:SetDrawLevel(9)
            local track=makeFill(s,row,2,30,CONTENT_W-4,8,FIELD,INK,2,4,ROW_LAYER)
            local sl=WM:CreateControl(nil,row,CT_SLIDER)
            sl:SetAnchor(TOPLEFT,row,TOPLEFT,2,25); sl:SetAnchor(TOPRIGHT,row,TOPRIGHT,-2,25)
            sl:SetHeight(18); sl:SetMouseEnabled(true); sl:SetOrientation(ORIENTATION_HORIZONTAL)
            sl:SetDrawLayer(ROW_LAYER); sl:SetDrawLevel(12)
            sl:SetThumbTexture(UI.path.."square.dds",UI.path.."square.dds",UI.path.."square.dds",14,18)
            local thumb=sl.GetThumbTextureControl and sl:GetThumbTextureControl()
            if thumb then
                thumb:SetColor(rgba(INK))
                thumb:SetDrawLayer(ROW_LAYER); thumb:SetDrawLevel(14)
            end
            sl:SetHandler("OnMouseEnter",function() if thumb then thumb:SetColor(rgba(TEAL)) end end)
            sl:SetHandler("OnMouseExit",function() if thumb then thumb:SetColor(rgba(INK)) end end)
            row.label=lbl; row.valLbl=valLbl; row.slider=sl; row.track=track
        elseif kind=="dropdown" then
            row:SetHeight(32)
            local lbl=makeLabel(s,row,"",2,1,CONTENT_W-152,13,INK,TEXT_ALIGN_LEFT,28)
            local btn=makeButton(s,row,"",CONTENT_W-144,2,142,26,function(b)
                if b.onClick then b.onClick(b) end
            end,CARD,true,4,ROW_LAYER)
            row.label=lbl; row.btn=btn
        elseif kind=="color" then
            row:SetHeight(28)
            local lbl=makeLabel(s,row,"",2,0,CONTENT_W-58,14,INK,TEXT_ALIGN_LEFT,26)
            local border=makeFill(s,row,CONTENT_W-48,3,48,22,INK,INK,2,4,ROW_LAYER)
            border:SetMouseEnabled(true)
            local swatch=WM:CreateControl(nil,border,CT_TEXTURE)
            swatch:SetAnchor(TOPLEFT,border,TOPLEFT,2,2); swatch:SetAnchor(BOTTOMRIGHT,border,BOTTOMRIGHT,-2,-2)
            swatch:SetDrawLayer(ROW_LAYER); swatch:SetDrawLevel(10)
            row.label=lbl; row.border=border; row.swatch=swatch
        elseif kind=="button" then
            row:SetHeight(36)
            local btn=makeButton(s,row,"",0,3,CONTENT_W-2,28,function(b)
                if b.onClick then b.onClick(b) end
            end,YELLOW,false,4,ROW_LAYER)
            row.btn=btn
        end
        row:SetHidden(true)
        return row
    end

    local function ensureInspector()
        if inspector then return inspector end
        local s=theme()
        local CREAM,CARD,_,INK,_,YELLOW,_=palette(s)
        local win=WM:CreateTopLevelWindow("ZeraUIEditInspector")
        win:SetDimensions(WIN_W,MAX_H); win:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-24,90)
        win:SetDrawTier(DT_HIGH); win:SetDrawLevel(60)
        win:SetMouseEnabled(true); win:SetMovable(true); win:SetClampedToScreen(true); win:SetHidden(true)

        local shadow=makeFill(s,win,6,6,WIN_W,MAX_H,INK,INK,1,0)
        local frame=makeFill(s,win,0,0,WIN_W,MAX_H,CREAM,INK,3,1)

        local title=makeLabel(s,win,"",12,8,WIN_W-140,18,INK,TEXT_ALIGN_LEFT,28)
        local overviewBtn=makeButton(s,win,tr("Overview"),WIN_W-124,10,78,26,function()
            A:SelectEdit(nil)
        end,YELLOW,true,4)
        overviewBtn:SetHidden(true)
        makeButton(s,win,"X",WIN_W-38,10,28,26,function()
            A:ToggleEditInspector(false)
        end,CORAL,true,4)

        local bodyCard=makeFill(s,win,10,46,WIN_W-20,MAX_H-96,CARD,INK,2,2)

        -- Parent scroll container to `win` (not `DL_BACKGROUND` backdrop) so its
        -- controls & native scrollbar never inherit DL_BACKGROUND layering.
        local scroll,scrollChild
        if WM.CreateControlFromVirtual then
            local ok,created=pcall(WM.CreateControlFromVirtual,WM,"ZeraUIEditInspectorScroll",win,"ZO_ScrollContainer")
            if ok and created then
                scroll=created
                scrollChild=scroll:GetNamedChild("ScrollChild")
            end
        end
        if not scroll or not scrollChild then
            scroll=WM:CreateControl(nil,win,CT_CONTROL)
            scrollChild=scroll
        end
        scroll:SetAnchor(TOPLEFT,bodyCard,TOPLEFT,13,8)
        scroll:SetAnchor(BOTTOMRIGHT,bodyCard,BOTTOMRIGHT,3,-8)
        if scrollChild~=scroll then
            scrollChild:SetWidth(CONTENT_W)
            if ZO_Scroll_SetUseFadeGradient then pcall(ZO_Scroll_SetUseFadeGradient,scroll,false) end
        end

        local resetAppBtn=makeButton(s,win,tr("Reset appearance"),10,MAX_H-40,164,28,function()
            local key=A:GetEditSelectionKey()
            if key then A:ResetWidgetAppearance(key) end
        end,CARD,true,4)
        local resetPosBtn=makeButton(s,win,tr("Reset position"),182,MAX_H-40,164,28,function()
            A:ResetEditSelection()
        end,CARD,true,4)

        inspector={
            win=win,shadow=shadow,frame=frame,bodyCard=bodyCard,
            title=title,overviewBtn=overviewBtn,scroll=scroll,child=scrollChild,
            resetAppBtn=resetAppBtn,resetPosBtn=resetPosBtn,
            pools={header={},note={},bool={},slider={},dropdown={},color={},button={}},
            used={},
            shown=true,
        }
        return inspector
    end

    local function acquireRow(insp,kind)
        local pool=insp.pools[kind]
        local idx=(insp.used[kind] or 0)+1
        insp.used[kind]=idx
        local row=pool[idx]
        if not row then
            row=createRowControl(kind,insp.child)
            pool[idx]=row
        end
        row:SetHidden(false)
        return row
    end

    local colorPickerHideHooked={}
    local function ensureColorPickerHideHook(picker)
        local control=picker and picker.control
        if not control or colorPickerHideHooked[control] or not ZO_PostHookHandler then return end
        colorPickerHideHooked[control]=pcall(ZO_PostHookHandler,control,"OnHide",function()
            if A.SetEditColorPickerActive then A:SetEditColorPickerActive(false) end
        end)
    end

    local function bindRow(row,item)
        local gen=(row.bindGen or 0)+1; row.bindGen=gen
        local kind=item.kind
        local s=theme()
        local _,_,FIELD,INK,INK_SOFT,_,TEAL=palette(s)
        if kind=="header" or kind=="note" then
            row.label:SetText(tr(item.label))
        elseif kind=="bool" then
            row.label:SetText(tr(item.label))
            local function paintToggle()
                local on=A.settings[item.key]==true
                row.track:SetCenterColor(rgba(on and TEAL or FIELD))
                row.knob:ClearAnchors()
                row.knob:SetAnchor(TOPLEFT,row.track,TOPLEFT,on and 20 or 4,4)
                row.stateLbl:SetText(tr(on and "ON" or "OFF"))
                row.stateLbl:SetColor(rgba(on and INK or INK_SOFT))
            end
            paintToggle()
            row.onToggle=function()
                commitValue(item,A.settings[item.key]~=true)
                paintToggle()
            end
        elseif kind=="slider" then
            row.itemKey=item.key
            row.itemSpec=item
            row.label:SetText(tr(item.label))
            local cur=tonumber(A.settings[item.key]) or item.min
            cur=clampStep(cur,item.min,item.max,item.step)
            row.valLbl:SetText(fmtNumber(cur,item.step))
            row.suppress=true
            row.slider:SetMinMax(item.min,item.max)
            if row.slider.SetValueStep then row.slider:SetValueStep(item.step) end
            row.slider:SetValue(cur)
            row.suppress=false
            row.slider:SetHandler("OnValueChanged",function(_,rawVal)
                if row.suppress or not A.editing then return end
                local v=clampStep(rawVal,item.min,item.max,item.step)
                row.valLbl:SetText(fmtNumber(v,item.step))
                if A.settings[item.key]~=v then commitValue(item,v) end
            end)
        elseif kind=="dropdown" then
            row.label:SetText(tr(item.label))
            local function displayFor(stored)
                local labels=type(item.choices)=="function" and item.choices() or item.choices or {}
                local values=item.choicesValues
                if values then
                    for i,v in ipairs(values) do if v==stored then return tr(tostring(labels[i] or v)) end end
                end
                return tr(tostring(stored or ""))
            end
            row.btn:SetLabel(displayFor(A.settings[item.key]))
            row.btn.onClick=function(btn)
                if not ClearMenu or not AddMenuItem or not ShowMenu then return end
                local labels=type(item.choices)=="function" and item.choices() or item.choices or {}
                local values=item.choicesValues
                ClearMenu()
                for i,choice in ipairs(labels) do
                    local label=choice
                    local val=values and values[i] or choice
                    local mark=A.settings[item.key]==val and "• " or "  "
                    AddMenuItem(mark..tr(tostring(label)),function()
                        if not A.editing or row.bindGen~=gen then return end
                        btn:SetLabel(tr(tostring(label)))
                        commitValue(item,val)
                    end)
                end
                ShowMenu(btn)
            end
        elseif kind=="color" then
            row.label:SetText(tr(item.label))
            local c=A.settings[item.key] or {1,1,1,1}
            row.swatch:SetColor(c[1] or 1,c[2] or 1,c[3] or 1,c[4] or 1)
            row.border:SetHandler("OnMouseUp",function(_,button,upInside)
                if not A.editing or row.bindGen~=gen or not upInside or (MOUSE_BUTTON_INDEX_LEFT and button~=MOUSE_BUTTON_INDEX_LEFT) then return end
                local cur=A.settings[item.key] or {1,1,1,1}
                local picker=IsInGamepadPreferredMode and IsInGamepadPreferredMode() and COLOR_PICKER_GAMEPAD or COLOR_PICKER
                if picker and picker.Show then
                    ensureColorPickerHideHook(picker)
                    picker:Show(function(r,g,b,a)
                        if A.SetEditColorPickerActive then A:SetEditColorPickerActive(false) end
                        if not A.editing or row.bindGen~=gen then return end
                        local nc={r,g,b,a or 1}
                        row.swatch:SetColor(nc[1],nc[2],nc[3],nc[4])
                        commitValue(item,nc)
                    end,cur[1] or 1,cur[2] or 1,cur[3] or 1,cur[4] or 1)
                    local opened=picker.control and colorPickerHideHooked[picker.control] and (not picker.IsShown or picker:IsShown())
                    if opened and A.SetEditColorPickerActive then A:SetEditColorPickerActive(true) end
                end
            end)
        elseif kind=="button" then
            row.btn:SetLabel(tr(item.label))
            row.btn.onClick=function() if item.fn then item.fn() end end
        end
    end

    function A:RefreshEditInspector()
        if not self.editing then return end
        local insp=ensureInspector()
        if not insp.shown or self.editColorPickerActive then insp.win:SetHidden(true); return end
        insp.win:SetHidden(false)
        local key=self:GetEditSelectionKey()
        local schemaKey=key and SCHEMAS[key] and key or "__global"
        local schema=SCHEMAS[schemaKey]
        local titleText=key and tr(self:EditWidgetTitle(key)) or tr("HUD Overview")
        insp.title:SetText(titleText)
        insp.title:SetWidth(key and (WIN_W-146) or (WIN_W-64))
        if insp.overviewBtn then insp.overviewBtn:SetHidden(key==nil) end

        local hasApp=key~=nil and self:HasWidgetAppearance(key)
        insp.resetAppBtn:SetHidden(not hasApp)
        insp.resetPosBtn:SetHidden(key==nil)

        insp.used={header=0,note=0,bool=0,slider=0,dropdown=0,color=0,button=0}
        local y=4
        for _,item in ipairs(schema) do
            local row=acquireRow(insp,item.kind)
            row:ClearAnchors()
            row:SetAnchor(TOPLEFT,insp.child,TOPLEFT,0,y)
            bindRow(row,item)
            y=y+row:GetHeight()+4
        end
        for kind,pool in pairs(insp.pools) do
            local active=insp.used[kind] or 0
            for i=active+1,#pool do pool[i]:SetHidden(true) end
        end
        local contentH=math.max(20,y+4)
        if insp.child~=insp.scroll then insp.child:SetHeight(contentH) end
        -- Auto-fit inspector height cleanly (eliminates empty void on HUD Overview)
        -- and center scroll viewport symmetrically when no scrollbar is needed.
        local hasFooter=key~=nil
        local footerH=hasFooter and 48 or 12
        local maxBodyH=MAX_H-46-footerH
        local needsScroll=(contentH+16)>maxBodyH
        local bodyH=needsScroll and maxBodyH or math.max(96,contentH+16)
        local winH=46+bodyH+footerH
        insp.win:SetHeight(winH)
        if insp.shadow then insp.shadow:SetHeight(winH) end
        if insp.frame then insp.frame:SetHeight(winH) end
        if insp.bodyCard then insp.bodyCard:SetHeight(bodyH) end
        if insp.scroll and insp.bodyCard then
            insp.scroll:ClearAnchors()
            if needsScroll then
                insp.scroll:SetAnchor(TOPLEFT,insp.bodyCard,TOPLEFT,8,8)
                insp.scroll:SetAnchor(BOTTOMRIGHT,insp.bodyCard,BOTTOMRIGHT,-2,-8)
            else
                insp.scroll:SetAnchor(TOPLEFT,insp.bodyCard,TOPLEFT,13,8)
                insp.scroll:SetAnchor(BOTTOMRIGHT,insp.bodyCard,BOTTOMRIGHT,3,-8)
            end
        end
        if hasFooter then
            local fy=winH-38
            insp.resetAppBtn:ClearAnchors(); insp.resetAppBtn:SetAnchor(TOPLEFT,insp.win,TOPLEFT,10,fy)
            insp.resetPosBtn:ClearAnchors(); insp.resetPosBtn:SetAnchor(TOPLEFT,insp.win,TOPLEFT,hasApp and 182 or 10,fy)
            insp.resetPosBtn:SetWidth(hasApp and 164 or (WIN_W-20))
            if insp.resetPosBtn.face then insp.resetPosBtn.face:SetWidth(hasApp and 164 or (WIN_W-20)) end
            if insp.resetPosBtn.shadow then insp.resetPosBtn.shadow:SetWidth(hasApp and 164 or (WIN_W-20)) end
        end
        if insp.lastKey~=schemaKey then
            insp.lastKey=schemaKey
            if ZO_Scroll_ResetToTop and insp.child~=insp.scroll then pcall(ZO_Scroll_ResetToTop,insp.scroll) end
        end
        if ZO_Scroll_UpdateScrollBar and insp.child~=insp.scroll then pcall(ZO_Scroll_UpdateScrollBar,insp.scroll) end
    end

    -- Targeted single-slider sync during live corner resize drag: avoids
    -- rebinding all pooled rows, anchors, and scrollbar layout on every step.
    function A:SyncEditInspectorValue(key)
        if not self.editing or not inspector or not inspector.shown or self.editColorPickerActive then return end
        local pool=inspector.pools and inspector.pools.slider
        local used=inspector.used and inspector.used.slider or 0
        if not pool or used<=0 then return end
        for i=1,used do
            local row=pool[i]
            if row and row.itemKey==key and row.itemSpec then
                local item=row.itemSpec
                local cur=clampStep(tonumber(self.settings[key]) or item.min,item.min,item.max,item.step)
                row.valLbl:SetText(fmtNumber(cur,item.step))
                row.suppress=true
                row.slider:SetValue(cur)
                row.suppress=false
                return
            end
        end
    end

    function A:IsEditInspectorShown()
        return inspector~=nil and inspector.shown==true and not inspector.win:IsHidden()
    end

    function A:ShowEditInspector(visible)
        if not visible then
            if inspector then
                inspector.win:SetAlpha(1)
                inspector.win:SetMouseEnabled(true)
                inspector.win:SetHidden(true)
            end
            return
        end
        local insp=ensureInspector()
        insp.shown=true
        insp.win:SetAlpha(1)
        insp.win:SetMouseEnabled(true)
        self:RefreshEditInspector()
        if self.SyncEditInspectorButton then self:SyncEditInspectorButton() end
    end

    function A:ToggleEditInspector(forceState)
        if not self.editing then return end
        local insp=ensureInspector()
        if forceState~=nil then insp.shown=not not forceState
        else insp.shown=not insp.shown end
        self:RefreshEditInspector()
        if self.SyncEditInspectorButton then self:SyncEditInspectorButton() end
    end

    function A:SetEditInspectorDragging(dragging)
        if not inspector then return end
        if dragging and not inspector.shown then return end
        inspector.win:SetAlpha(dragging and .22 or 1)
        inspector.win:SetMouseEnabled(not dragging)
    end

    function A:SetEditInspectorColorPickerActive(active)
        if not inspector then return end
        if active then
            inspector.win:SetHidden(true)
        else
            inspector.win:SetAlpha(1)
            inspector.win:SetMouseEnabled(true)
            inspector.win:SetHidden(not (self.editing and inspector.shown))
        end
    end
end
