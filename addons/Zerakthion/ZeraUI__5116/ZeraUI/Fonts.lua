-- Zera UI: font catalog, native font application, vertical nudge, and badge/counter fitting.
function ZeraUIAttachFonts(A,UI)
    local ADDON=UI.addon
    local text=UI.text

    local REFERENCE_FONT="Rajdhani Bold"
    local REFERENCE_FONT_PATH=ADDON.."/fonts/Rajdhani-Bold-OL.slug"
    local SEMIBOLD_FONT="Rajdhani SemiBold"
    local SEMIBOLD_FONT_PATH=ADDON.."/fonts/Rajdhani-SemiBold-OL.slug"
    -- Rajdhani is converted with slugfont -outline and declared in Fonts.xml.
    -- ESO draws its native outline/thick-outline for a custom .slug only when
    -- both are true; otherwise the outline style renders as plain text.
    local DEFAULT_FONT="Univers 67"

    -- Only these faces are offered: Rajdhani Bold/SemiBold (bundled .slug, see
    -- Fonts.xml) and ESO's own Univers 67 / Univers 57. Saved choices of any
    -- other face are reset by NormalizeFonts.
    local GAME_FONTS={
        {"Univers 67","$(BOLD_FONT)"},
        {"Univers 57","$(MEDIUM_FONT)"},
    }
    local FONTS={}
    for _,row in ipairs(GAME_FONTS) do FONTS[row[1]]=row[2] end
    FONTS[REFERENCE_FONT]=REFERENCE_FONT_PATH
    FONTS[SEMIBOLD_FONT]=SEMIBOLD_FONT_PATH

    function A:DefaultFontPath()
        return FONTS[DEFAULT_FONT]
    end
    function A:FontChoices()
        local choices={REFERENCE_FONT,SEMIBOLD_FONT}
        for _,row in ipairs(GAME_FONTS) do choices[#choices+1]=row[1] end
        return choices
    end

    -- Vertical correction for text centered in a fixed box, in em (font size)
    -- units; positive moves the text down. Measured in game: ESO centers the
    -- outlined Rajdhani .slug about 0.22 em above the box center. Fonts not
    -- listed here use 0. Values are multiplied by the label's font size.
    local FONT_VERTICAL_NUDGE={
        [REFERENCE_FONT_PATH]=.22,
        [SEMIBOLD_FONT_PATH]=.22,
    }
    function A:FontVerticalNudge(path,size)
        local em=path and FONT_VERTICAL_NUDGE[path] or 0
        return math.floor(em*(size or 0)+.5)
    end
    function A:ResolveFont(face)
        return FONTS[face]
    end

    -- ESO's own faces only. These render the selected outline natively, so a
    -- label needs no contour copies (fewer controls, one SetText per change).
    local GAME_FONT_PATHS={}
    for _,row in ipairs(GAME_FONTS) do GAME_FONT_PATHS[row[1]]=row[2] end
    function A:GameFont(name)
        return name and name~="Off" and GAME_FONT_PATHS[name] or nil
    end
    function A:NormalizeFonts()
        if not FONTS[self.settings.fontFace] then self.settings.fontFace=DEFAULT_FONT end
        if self.settings.attrFont~="HUD font" and not FONTS[self.settings.attrFont] then self.settings.attrFont="HUD font" end
        if self.settings.setCooldownFont~="HUD font" and not FONTS[self.settings.setCooldownFont] then self.settings.setCooldownFont="HUD font" end
        for _,key in ipairs({"effectSelfFont","effectSelfDebuffFont","effectTargetFont","effectTargetDebuffFont","offBalanceFont"}) do
            local face=self.settings[key]
            if face~=nil and face~="HUD font" and not FONTS[face] then self.settings[key]="HUD font" end
        end
    end

    -- Vertical correction for faces ESO does not center (outlined Rajdhani .slug,
    -- see FONT_VERTICAL_NUDGE), applied to every label in one place: the label's
    -- SetAnchor adds its current correction, so any module positioning it keeps
    -- the correction, and a font change moves the label once by the difference.
    local function setLabelNudge(label,nudge)
        if not label.vabNudgeHook then
            if nudge==0 or not label.SetAnchor then return end
            local setAnchor=label.SetAnchor
            label.SetAnchor=function(self,point,relativeTo,relativePoint,x,y,...)
                return setAnchor(self,point,relativeTo,relativePoint,x or 0,(y or 0)+(self.vabNudge or 0),...)
            end
            label.vabNudgeHook=true
        end
        local old=label.vabNudge or 0
        if old==nudge then return end
        label.vabNudge=nudge
        if not label.GetAnchor then return end
        local anchors={}
        for i=0,1 do
            local valid,point,relativeTo,relativePoint,x,y,constrains=label:GetAnchor(i)
            if valid then anchors[#anchors+1]={point,relativeTo,relativePoint,x or 0,(y or 0)-old,constrains} end
        end
        if #anchors==0 then return end
        label:ClearAnchors()
        for _,a in ipairs(anchors) do
            if a[6]~=nil then label:SetAnchor(a[1],a[2],a[3],a[4],a[5],a[6]) else label:SetAnchor(a[1],a[2],a[3],a[4],a[5]) end
        end
    end

    function A:ApplyNativeFont(label,resolved,size,style,compactOutline,prevalidated)
        local fallback=FONTS[DEFAULT_FONT]
        local strong=compactOutline=="strong"
        local generation=self.fontGeneration or 0
        if label.vabFontGeneration==generation and label.vabFontPath==resolved and label.vabFontSize==size and label.vabFontStyle==style and label.vabFontOutline==compactOutline then return true end
        label.vabFontGeneration=nil
        local spec=function(path) return string.format("%s|%d|%s",path,math.floor(size+.5),style) end
        -- A verified font face need not be preceded by a fallback SetFont on
        -- every size change. Still check the native face, since unavailable
        -- custom fonts can fail silently. Keep this cache bounded and scoped
        -- to the font settings generation.
        if self.verifiedFontGeneration~=generation then
            self.verifiedFontGeneration=generation; self.verifiedFonts={}; self.verifiedFontCount=0
        end
        local verified=self.verifiedFonts
        local face=resolved and (strong and string.format("%s|%d|thick-outline",resolved,math.floor(size+.5)) or spec(resolved))
        local known=type(prevalidated)=="string" and prevalidated or face and verified[face]
        if known and label.GetFont then
            local ok,result=pcall(label.SetFont,label,face)
            local valid=ok and result~=false and label:GetFont()==known
            if valid and not prevalidated and resolved:lower():sub(-5)==".slug" and not resolved:lower():find("^esoui/") and label.GetStringWidth then
                local measured,width=pcall(label.GetStringWidth,label,"0123456789")
                valid=measured and type(width)=="number" and width>0
            end
            if valid then
                label.vabFontGeneration=generation; label.vabFontPath=resolved; label.vabFontSize=size; label.vabFontStyle=style; label.vabFontOutline=compactOutline; label.vabAppliedFont=face
                setLabelNudge(label,self:FontVerticalNudge(resolved,size))
                return true
            end
        end
        -- Keep native labels, opacity, draw level and text intact. Never replace
        -- the label with texture glyphs. Native font failure returns to Univers.
        local appliedFace=spec(fallback)
        label:SetFont(appliedFace)
        local fallbackFace=label.GetFont and label:GetFont()
        -- Native label outline only: no additional contour or weight controls.
        if strong then resolved=resolved or fallback end
        if resolved and (resolved~=fallback or strong) then
            local face=strong and string.format("%s|%d|thick-outline",resolved,math.floor(size+.5)) or spec(resolved)
            local ok,result=pcall(label.SetFont,label,face)
            local custom=resolved:lower():sub(-5)==".slug" and not resolved:lower():find("^esoui/")
            -- SetFont may silently retain the previous face, or yield zero glyph
            -- metrics. Test the resolved face without changing the visible text.
            local silentFailure=false
            if ok and result~=false and custom then
                if label.GetFont and fallbackFace and label:GetFont()==fallbackFace then silentFailure=true end
                if label.GetStringWidth then
                    local measured,width=pcall(label.GetStringWidth,label,"0123456789")
                    if not measured or type(width)~="number" or width<=0 then silentFailure=true end
                end
            end
            if not ok or result==false or silentFailure then
                if not strong then appliedFace=spec(fallback); label:SetFont(appliedFace); label.vabAppliedFont=appliedFace; setLabelNudge(label,0); return false end
                appliedFace=string.format("%s|%d|thick-outline",fallback,math.floor(size+.5)); label:SetFont(appliedFace)
                resolved=nil
            else
                appliedFace=face
            end
        end
        label.vabAppliedFont=appliedFace
        if resolved then
            label.vabFontGeneration=generation; label.vabFontPath=resolved; label.vabFontSize=size; label.vabFontStyle=style; label.vabFontOutline=compactOutline
            local actual=face and label.GetFont and label:GetFont()
            if actual then
                if not verified[face] then
                    if self.verifiedFontCount>=96 then verified={}; self.verifiedFonts=verified; self.verifiedFontCount=0 end
                    self.verifiedFontCount=self.verifiedFontCount+1
                end
                verified[face]=actual
            end
        end
        setLabelNudge(label,resolved and self:FontVerticalNudge(resolved,size) or 0)
        return resolved~=nil
    end

    -- Measure string width in local UI units via an unscaled, unbounded GuiRoot
    -- CT_LABEL probe using GetTextWidth(). Unlike GetStringWidth() on a scaled
    -- HUD label, GetTextWidth() returns stringWidthUIUnits unaffected by
    -- ancestor SetScale() transforms, and never mutates the visible label text.
    local function getMeasureProbe(self)
        local probe=self.textMeasureProbe
        if probe then return probe end
        local parent=GuiRoot or self.root
        if not parent or not WINDOW_MANAGER or not WINDOW_MANAGER.CreateControl then return nil end
        probe=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL)
        if probe.SetAnchor then probe:SetAnchor(TOPLEFT,parent,TOPLEFT,0,0) end
        if probe.SetDimensions then probe:SetDimensions(0,0) end
        if probe.SetScale then probe:SetScale(1) end
        probe:SetHidden(true)
        self.textMeasureProbe=probe
        return probe
    end

    local MEASURE_CACHE_LIMIT=512
    local function rawProbeWidth(probe,value)
        probe:SetText(value)
        local ok,width=pcall(probe.GetTextWidth,probe)
        if ok and type(width)=="number" and width>0 then return width end
        return nil
    end

    function A:MeasureStringUIWidth(label,value)
        if type(value)~="string" or value=="" then return 0 end
        local probe=getMeasureProbe(self)
        local fontSpec=label and (label.vabAppliedFont or (label.GetFont and label:GetFont()))
        if probe and fontSpec and probe.SetFont and probe.SetText and probe.GetTextWidth then
            local generation=self.fontGeneration or 0
            local cache=self.textMeasureCache
            if not cache or self.textMeasureCacheGen~=generation then
                cache={}; self.textMeasureCache=cache; self.textMeasureCacheGen=generation; self.textMeasureCacheCount=0
                probe.vabLastMeasureFont=nil
            end
            local byFont=cache[fontSpec]
            if byFont then
                local cached=byFont[value]
                if cached~=nil then return cached end
            end
            if probe.vabLastMeasureFont~=fontSpec then
                local ok,res=pcall(probe.SetFont,probe,fontSpec)
                if ok and res~=false then probe.vabLastMeasureFont=fontSpec end
            end
            if probe.vabLastMeasureFont==fontSpec then
                local width=rawProbeWidth(probe,value)
                if width then
                    if (self.textMeasureCacheCount or 0)>=MEASURE_CACHE_LIMIT then
                        cache={}; self.textMeasureCache=cache; self.textMeasureCacheCount=0; byFont=nil
                    end
                    if not byFont then byFont={}; cache[fontSpec]=byFont end
                    byFont[value]=width
                    self.textMeasureCacheCount=(self.textMeasureCacheCount or 0)+1
                    return width
                end
            end
        end
        if label and label.GetStringWidth then
            local ok,width=pcall(label.GetStringWidth,label,value)
            if ok and type(width)=="number" then return width end
        end
        return 0
    end

    -- Keep badge text inside the bevel of its metal plate. Local UI-unit widths
    -- (GetTextWidth via unscaled probe) make this work for every face, size and
    -- parent scale: the font shrinks first (not below 10 px, or the chosen size
    -- if smaller), then the badge widens up to maxW. Measured only when the
    -- text, size or font changes.
    local BADGE_BEVEL,BADGE_MIN_FONT=.12,10
    local function badgeInner(w) return w-2*math.ceil(w*BADGE_BEVEL) end
    function A:FitBadgeText(label,font,style,outline,value,size,w,maxW)
        size=math.floor(size+.5)
        maxW=maxW or w
        -- Reuse the last fit while every input is unchanged. Compared field by
        -- field: building a key here made most of the addon's garbage.
        local generation=self.fontGeneration or 0
        if label.badgeFitValid and label.badgeFitValue==value and label.badgeFitInSize==size and label.badgeFitInW==w
            and label.badgeFitMaxW==maxW and label.badgeFitFont==font and label.badgeFitStyle==style and label.badgeFitOutline==outline and label.badgeFitGeneration==generation then
            self:ApplyNativeFont(label,font,label.badgeFitSize,style,outline)
            return label.badgeFitSize,label.badgeFitW,label.badgeFitOk
        end
        -- Stack/recipient counters revisit a small set of strings. Retain the
        -- exact native measurements, instead of resizing and measuring again
        -- each time the number changes. One shape per label, bounded entries.
        local cache=label.badgeFitCache
        if not cache or cache.generation~=generation or cache.font~=font or cache.style~=style or cache.outline~=outline
            or cache.size~=size or cache.w~=w or cache.maxW~=maxW then
            cache={generation=generation,font=font,style=style,outline=outline,size=size,w=w,maxW=maxW,entries={},count=0}
            label.badgeFitCache=cache
        end
        local saved=cache.entries[value]
        if saved and self:ApplyNativeFont(label,font,saved.size,style,outline) then
            label.badgeFitValid=true
            label.badgeFitValue,label.badgeFitInSize,label.badgeFitInW,label.badgeFitMaxW=value,size,w,maxW
            label.badgeFitFont,label.badgeFitStyle,label.badgeFitOutline,label.badgeFitGeneration=font,style,outline,generation
            label.badgeFitSize,label.badgeFitW,label.badgeFitOk=saved.size,saved.w,saved.ok
            return saved.size,saved.w,saved.ok
        end
        -- Native outlines are drawn outside the measured advance width.
        local pad=(style or ""):find("thick%-outline") and 4 or (style or ""):find("outline") and 2 or 0
        local function measure()
            if value=="" then return 0 end
            local width=self:MeasureStringUIWidth(label,value)
            return (type(width)=="number" and width or 0)+pad
        end
        local floor=math.min(size,BADGE_MIN_FONT)
        local current=size
        local fontOK=self:ApplyNativeFont(label,font,current,style,outline)
        local width=measure()
        local room=badgeInner(w)
        local tries=0
        while width>room and current>floor and tries<8 do
            current=math.max(floor,math.min(current-1,math.floor(current*room/width)))
            local applied=self:ApplyNativeFont(label,font,current,style,outline)
            fontOK=fontOK and applied
            width=measure(); tries=tries+1
        end
        local fits=width<=room
        local inW=w
        if not fits and maxW>w then
            w=math.min(maxW,math.max(w,math.ceil(width/(1-2*BADGE_BEVEL))))
            while badgeInner(w)<width and w<maxW do w=w+1 end
            fits=width<=badgeInner(w)
        end
        label.badgeFitValid=true
        label.badgeFitValue,label.badgeFitInSize,label.badgeFitInW,label.badgeFitMaxW=value,size,inW,maxW
        label.badgeFitFont,label.badgeFitStyle,label.badgeFitOutline,label.badgeFitGeneration=font,style,outline,generation
        label.badgeFitSize,label.badgeFitW,label.badgeFitOk=current,w,fits
        if fontOK then
            if cache.count>=24 then cache.entries={}; cache.count=0 end
            if not cache.entries[value] then cache.count=cache.count+1 end
            cache.entries[value]={size=current,w=w,ok=fits}
        end
        return current,w,fits
    end

    -- Build safe numeric font limits when the HUD font is configured, not when
    -- combat changes a stack. Widths are conservative for proportional digits;
    -- all countdown/phase/recipient formats use this small ASCII alphabet.
    function A:PrepareCounterFontMetrics(font,style)
        local generation=self.fontGeneration or 0
        local old=self.counterFontMetrics
        if old and old.font==font and old.style==style and old.generation==generation then return end
        local probe=self.counterFontProbe
        if not probe then
            probe=text(GuiRoot or self.root,16,0,0,0,0,1)
            if probe.SetScale then probe:SetScale(1) end
            probe:SetHidden(true)
            self.counterFontProbe=probe
        end
        local function probeWidth(glyphText)
            if probe.SetText and probe.GetTextWidth then
                probe:SetText(glyphText)
                local ok,w=pcall(probe.GetTextWidth,probe)
                if ok and type(w)=="number" and w>0 then return w end
            end
            if probe.GetStringWidth then
                local ok,w=pcall(probe.GetStringWidth,probe,glyphText)
                if ok and type(w)=="number" then return w end
            end
            return 0
        end
        local metrics={font=font,style=style,generation=generation,sizes={}}
        for size=8,40 do
            local actual=font
            if not self:ApplyNativeFont(probe,font,size,style,true) then
                actual=FONTS[DEFAULT_FONT]; self:ApplyNativeFont(probe,actual,size,style,true)
            end
            local row={font=actual,native=probe.GetFont and probe:GetFont(),digit=0,strings={}}
            for d=0,9 do
                local glyph=tostring(d)
                local width=math.max(probeWidth(glyph),probeWidth(glyph:rep(4))/4)
                row.digit=math.max(row.digit,width)
            end
            for glyph in ("AF~[]./-+eE:L"):gmatch(".") do row.strings[glyph]=probeWidth(glyph) end
            row.digit=math.max(row.digit,1)
            metrics.sizes[size]=row
        end
        self.counterFontMetrics=metrics
    end

    -- Shape, not changing digits, determines the maximum font size. The caps
    -- below are pure table/arithmetic lookups: never call GetStringWidth or
    -- probe successive native fonts from Tick. Keep the exact-fit routine above
    -- for the pre-layout fallback.
    function A:CounterFontLimit(value,size,w,maxW,metal)
        local metrics=self.counterFontMetrics
        size=math.max(8,math.min(40,math.floor(size+.5)))
        maxW=maxW or w
        local minSize=math.min(size,metal and BADGE_MIN_FONT or 8)
        local pad=metal and ((metrics.style or ""):find("thick%-outline") and 4 or (metrics.style or ""):find("outline") and 2 or 0) or 2
        local function widthAt(n)
            local row=metrics.sizes[n]
            local width=pad
            for glyph in value:gmatch(".") do
                if glyph:match("%d") then width=width+row.digit else width=width+(row.strings[glyph] or n) end
            end
            -- Round outward for fractional glyph advances and possible kerning.
            return math.ceil(width+1)
        end
        local function room(width) return metal and badgeInner(width) or width end
        local width=widthAt(size)
        while size>minSize and width>room(w) do size=size-1; width=widthAt(size) end
        if width>room(w) and maxW>w then
            w=math.min(maxW,math.max(w,metal and math.ceil(width/(1-2*BADGE_BEVEL)) or width))
            while w<maxW and room(w)<width do w=w+1 end
        end
        -- Rare long custom timers/counts must not overflow even at the ordinary
        -- badge minimum. Do not truncate the gameplay value.
        while size>8 and width>room(w) do size=size-1; width=widthAt(size) end
        return size,w,width<=room(w),metrics.sizes[size].font,metrics.sizes[size].native
    end

    function A:FitCounterText(label,font,style,outline,value,size,w,maxW,metal,sample)
        local metrics=self.counterFontMetrics
        if not metrics or metrics.font~=font or metrics.style~=style then
            if metal then return self:FitBadgeText(label,font,style,outline,value,size,w,maxW) end
            self:ApplyNativeFont(label,font,size,style,outline); return size,w,true
        end
        maxW=maxW or w
        local input=sample or value
        local fit=label.counterFit
        if not fit or fit.metrics~=metrics or fit.size~=size or fit.w~=w or fit.maxW~=maxW or fit.metal~=metal then
            fit={metrics=metrics,size=size,w=w,maxW=maxW,metal=metal,shapes={},count=0}; label.counterFit=fit
        end
        local result
        if fit.text==input then result=fit.result else
            local shape=input:gsub("%d","0")
            result=fit.shapes[shape]
            if not result then
                local cap,width,ok,actual,native=self:CounterFontLimit(shape,size,w,maxW,metal)
                result={cap,width,ok,actual,native}
                if fit.count>=16 then fit.shapes={}; fit.count=0 end
                fit.shapes[shape]=result; fit.count=fit.count+1
            end
            fit.text,fit.result=input,result
        end
        self:ApplyNativeFont(label,result[4],result[1],style,outline,result[5] or true)
        return result[1],result[2],result[3]
    end
end
