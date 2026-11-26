-- Zera UI: default settings, SavedVariables bootstrap, and versioned migrations.
function ZeraUIAttachDefaults(A,UI)
    local boundedSize=UI.boundedSize
    local APPEARANCE={
        effectSelfEnabled=true,effectTargetEnabled=true,effectOutsideCombat=true,effectHideNative=true,
        effectSelfLocked=true,effectTargetLocked=true,offBalanceLocked=false,setCooldownLocked=false,curvedLocked=true,
        effectSelfFont="HUD font",effectTargetFont="HUD font",offBalanceFont="HUD font",
        effectSelfOutline="HUD outline",effectTargetOutline="HUD outline",offBalanceOutline="HUD outline",
        effectTargetMine=false,effectInteractive=true,
        effectSelfWhitelistOnly=false,effectTargetWhitelistOnly=false,
        effectSelfPermanent=false,effectTargetPermanent=false,
        effectSelfColumns=8,effectTargetColumns=8,effectSelfSize=36,effectTargetSize=36,
        effectSelfGap=3,effectTargetGap=3,effectSelfX=-296,effectSelfY=12,effectTargetX=-1316,effectTargetY=12,
        effectSelfGrow="Right to left",effectTargetGrow="Right to left",effectSelfSingleRow=false,effectTargetSingleRow=false,
        effectSelfSort="Game order",effectTargetSort="Game order",
        effectSelfHighlightDebuffs=true,effectTargetHighlightDebuffs=true,
        effectSelfFontSize=30,effectTargetFontSize=30,effectSelfStackSize=19,effectTargetStackSize=19,
        effectSelfStacks=true,effectTargetStacks=true,effectSelfFill=true,effectTargetFill=true,
        effectSelfFlash=true,effectTargetFlash=true,effectSelfFlashSeconds=3,effectTargetFlashSeconds=3,
        effectSelfColor={.15,1,.12,1},effectTargetColor={.15,1,.12,1},
        effectSelfDebuffColor={1,.25,.22,1},effectTargetDebuffColor={.15,1,.12,1},
        offBalanceEnabled=true,offBalanceSeparate=true,offBalanceEstimate=true,offBalanceReady=true,
        offBalanceActiveColor={.12,1,.05,1},offBalanceImmuneColor={1,.08,.08,1},offBalanceReadyColor={1,.82,.10,1},
        offBalanceSize=48,offBalanceX=-1125,offBalanceY=690,offBalanceFontSize=30,offBalanceStackSize=19,
        offBalanceFill=true,offBalanceFlash=true,offBalanceFlashSeconds=3,
        setCooldownEnabled=true,setCooldownReady=true,setCooldownBoth=true,setCooldownNames=false,
        setCooldownDirection="Vertical",setCooldownX=-275,setCooldownY=143,setCooldownScale=1,setCooldownGap=5,setCooldownFontSize=24,
        setCooldownIconSize=77,setCooldownStackSize=15,setCooldownSecondarySize=16,setCooldownNameSize=12,
        setCooldownFont="Rajdhani Bold",setCooldownOutline="HUD outline",setCooldownDecimal=3,setCooldownTimerX=0,setCooldownTimerY=0,
        setCooldownOutsideCombat=true,setCooldownOffBar=true,setCooldownShowStacks=true,setCooldownShowFill=true,
        effectLongEffects=false,setCooldownShowGlow=true,setCooldownBorderAnimation=true,setCooldownProcFlash=true,setCooldownResourceGlow=true,setCooldownShowFrame=true,setCooldownColorTimer=true,setCooldownColorFrame=false,
        setCooldownNamePosition="Right",setCooldownNameBg=false,setCooldownNameColor={1,1,1,1},
        setCooldownActiveColor={.36,1,.32,1},setCooldownCooldownColor={.90,.35,1,1},setCooldownReadyColor={1,.77,.22,1},
        setCooldownValueColor={.52,.85,1,1},setCooldownOffBarColor={.55,.55,.55,1},
        setCooldownStackColor={.55,.87,1,1},setCooldownSecondaryColor={1,.90,.72,1},setCooldownTimerColor={1,1,1,1},
        setCooldownActiveAlpha=1,setCooldownCooldownAlpha=1,setCooldownReadyAlpha=1,setCooldownOffBarAlpha=.55,
        setCooldownValueAlpha=1,setCooldownDesaturate=true,setCooldownFilterMode="All equipped",setCooldownFilter={},setCooldownOverrides={},
        setCooldownProcSound="None",setCooldownReadySound="None",setCooldownZenBoss=false,setCooldownZenCountMode="All",setCooldownRODuration=true,setCooldownROCount=true,
        setCooldownResourceValue=true,setCooldownProcCount=true,
        scale=1,x=0,y=-70,skillSize=64,gapX=4,gapY=7,gridX=0,gridY=-17,
        inactiveDesaturation=.9,inactiveAlpha=1,showArrow=true,arrowStyle="Classic",activeBarOnTop=false,showFill=true,swapFade=true,
        showUnavailable=true,darkenResource=true,darkenCorpse=true,darkenTarget=true,unavailableTint=.28,unavailableAlpha=.75,
        timerSize=30,stackSize=19,stackBadge=true,extraSize=16,extraLeftSize=15,extraRightSize=15,cornerBadgeSize=16,keySize=14,fontStyle="thick-outline",fontFace="Rajdhani Bold",
        extraLeftX=-5,extraLeftY=0,extraRightX=4,extraRightY=0,
        warningColors=true,soonSeconds=3,lastSeconds=1,decimalSeconds=3,
        normalColor={1,1,1,1},soonColor={1,.68,.12,1},lastColor={1,.16,.12,1},
        fillColor={.15,1,.12,.92},stackColor={.44,.82,1,1},
        secondColor={.4,.9,1,1},thirdColor={1,.82,.3,1},
        glowColor={1,1,1,1},glowStrength=1,pressMs=650,expiryMs=800,burstStrength=.70,ringBloom=true,
        ultScale=1,ultX=0,ultY=17,ultValueSize=21,ultCostSize=20,ultDurationSize=24,
        showUltDuration=true,showBackUlt=true,showUltCost=true,ultDurationOffset=-9,
        ultimateReadyGlow=true,
        ultimateColor={1,.78,.25,1},activeUltColor={.24,1,.20,1},readyColor={.26,1,.24,1},unreadyColor={1,.2,.17,1},
        quickScale=1,quickX=0,quickY=17,quickColor={.63,.38,1,1},quickTimerSize=21,quickCountSize=12,quickCountPosition="Inside bottom",
        castScale=1,castX=0,castY=17,castFontSize=19,castTimeSize=15,castColor={1,1,1,1},
        castShowGCD=true,castShowChannels=true,castShowHardcasts=true,channelColor={.30,.80,1,1},
        synergyScale=1,synergyX=0,synergyY=60,synergyTextSize=15,synergyKeySize=14,
        synergyFadeIn=140,synergyFadeOut=180,synergyInstantHide=true,synergyOpacity=1,synergyKey="X",synergyName=true,synergyShowKey=true,
        synergyAnimations=true,synergyPressFlash=true,showQuickslot=true,showSynergy=true,showGCD=true,showHotkeys=true,showStacks=true,
        animations=true,pressFlash=true,pressSink=true,expiryGlow=true,showSkillTooltips=true,
        showTargets=true,showSingleTarget=false,showSingleGroupBuff=true,targetSize=16,targetColor={1,.8,0,1},
        targetExpireFirst=false,followTargetTimers=true,followKeepLast=true,showUltimatePassives=true,showCharges=true,chargeColor={.80,.68,1,1},
        procHighlight=true,procColor={.35,.85,1,1},procPulse=true,
        toggleGlow=true,toggleGlowStrength=1,overloadStyle="Classic",
        togglePulse=true,togglePulsePeriod=1000,togglePulseColor={.30,.78,1,1},
        expiryLoop=true,stackLoop=true,loopSeconds=1,loopStacks=3,loopPeriod=1150,loopInactive=false,
        showNothingWasted=true,nwWarning=true,nwWarnSeconds=2,
        showVampirePassive=true,arcanistPassiveMode="Fatecarver",
        attrEnabled=true,attrMode="Custom",attrTrauma=true,attrNoHealing=true,attrUpdateRate="Every change",attrLayout="Pyramid",attrCustomSkin=true,attrSplit=false,attrWidth=237,attrScale=1,attrGap=2,attrCleanGlow=true,
        attrTextSize=20,attrTextOffsetY=0,attrFont="HUD font",attrOutline="thick-outline",attrFormat="Short",attrPercent=true,attrLowWarning=true,attrShieldValue=true,
        attrX=0,attrY=264,attrHealthX=0,attrHealthY=0,attrMagickaX=0,attrMagickaY=0,attrStaminaX=0,attrStaminaY=0,
        curvedX=0,curvedY=0,curvedScale=1,curvedGap=400,curvedPercentSize=15,curvedValueSize=11,curvedShieldAlpha=.95,
        moveTogether=false,editSnap=5,editShowGrid=false,editAxis="Free",playerInteractionX=0,playerInteractionY=0,instanceKickX=0,instanceKickY=0,reticleInteractX=0,reticleInteractY=0,tutorialTipX=0,tutorialTipY=0,interactWindowX=0,interactWindowY=0,passiveX=0,passiveY=0,passiveTimerSize=0,
    }
    -- Each unit uses one scan, but has two independently configured widgets.
    local EFFECT_GRID_KEYS={"Enabled","Locked","Font","Outline","Permanent","Columns","Size","Gap","Grow","SingleRow","Sort","HighlightDebuffs","FontSize","StackSize","Stacks","Fill","Flash","FlashSeconds","Mine","WhitelistOnly"}
    for _,p in ipairs({"effectSelf","effectTarget"}) do
        for _,key in ipairs(EFFECT_GRID_KEYS) do APPEARANCE[p.."Debuff"..key]=APPEARANCE[p..key] end
    end
    APPEARANCE.effectSelfDebuffX,APPEARANCE.effectSelfDebuffY=-805,705
    APPEARANCE.effectTargetDebuffX,APPEARANCE.effectTargetDebuffY=-806,145
    APPEARANCE.effectSelfDebuffGrow="Center"
    APPEARANCE.effectTargetDebuffMine=true
    APPEARANCE.effectTargetDebuffHighlightDebuffs=false

    -- Defaults for the settings menu's per-control reset. Appearance defaults
    -- take priority over the original saved-variable seed values.
    local BASE_SETTINGS={enabled=true,replaceNative=true,animations=true,expiryGlow=true,scale=1,x=0,y=-70,timerSize=30,fontStyle="thick-outline",warningColors=true,showHotkeys=true,showStacks=true,showQuickslot=true,showSynergy=true,showGCD=true}
    -- The set filter and per-set settings are saved choices, not visuals.
    local RESET_KEEPS={setCooldownFilterMode=true,setCooldownFilter=true,setCooldownOverrides=true}
    -- Widget offsets from TOPRIGHT were authored in a 1920 x 1080 GuiRoot.
    -- Convert defaults only; saved coordinates and icon dimensions are in UI units.
    local widgetDefaultAxis={}
    for _,p in ipairs({"effectSelf","effectSelfDebuff","effectTarget","effectTargetDebuff","offBalance"}) do
        widgetDefaultAxis[p.."X"]="x"; widgetDefaultAxis[p.."Y"]="y"
    end

    local function copyValue(v)
        if type(v)~="table" then return v end
        local copy={}; for i,x in ipairs(v) do copy[i]=x end; return copy
    end

    function A:DefaultSetting(key)
        local v=APPEARANCE[key]
        if v==nil then v=BASE_SETTINGS[key] end
        local axis=widgetDefaultAxis[key]
        if axis and GuiRoot then
            local horizontal=axis=="x"
            local extent=horizontal and GuiRoot:GetWidth() or GuiRoot:GetHeight()
            if extent and extent>0 then
                -- GuiRoot dimensions are already divided by GetUIGlobalScale();
                -- convert back to 1x reference pixels so EffectHUD:Position()'s
                -- UIUnits() does not divide by GetUIGlobalScale() a second time.
                local scale=self.GlobalUIScale and self:GlobalUIScale() or 1
                local pixels=extent*scale
                return math.max(horizontal and -4000 or 0,math.min(horizontal and 0 or 3000,
                    math.floor(v*pixels/(horizontal and 1920 or 1080)+.5)))
            end
        end
        return copyValue(v)
    end

    function A:ResetAppearance()
        for key in pairs(APPEARANCE) do
            if not RESET_KEEPS[key] then self.settings[key]=self:DefaultSetting(key) end
        end
        self:ApplySettings()
    end

    function A:SnapshotAppearance()
        local snap={}
        for key in pairs(APPEARANCE) do
            if not RESET_KEEPS[key] then snap[key]=copyValue(self.settings[key]) end
        end
        return snap
    end

    function A:RestoreAppearanceSnapshot(snap)
        if type(snap)~="table" then return end
        for key,value in pairs(snap) do
            if APPEARANCE[key]~=nil and not RESET_KEEPS[key] then
                self.settings[key]=copyValue(value)
            end
        end
    end

    function A:ResetKeysToDefault(keyList)
        if type(keyList)~="table" then return end
        for _,key in ipairs(keyList) do
            if APPEARANCE[key]~=nil and not RESET_KEEPS[key] then
                self.settings[key]=self:DefaultSetting(key)
            end
        end
    end

    function A:ResetAttributePositions()
        local s=self.settings
        s.attrX,s.attrY=APPEARANCE.attrX,APPEARANCE.attrY
        if s.attrLayout=="Stacked" then s.attrX,s.attrY=-245,-30 end
        for _,key in ipairs({"attrHealthX","attrHealthY","attrMagickaX","attrMagickaY","attrStaminaX","attrStaminaY"}) do s[key]=0 end
    end

    function A:LoadAndMigrateSettings()
        self.settings=ZO_SavedVars:NewAccountWide("ZeraUISaved",1,nil,BASE_SETTINGS)
        if self.settings.menuLanguage~="tr" then self.settings.menuLanguage="en" end
        -- Existing v0.5 saves had warning colors disabled by default.
        if not self.settings.expiryStyleVersion then
            self.settings.warningColors=true
            self.settings.expiryStyleVersion=1
        end
        -- Migrate old defaults, never arbitrary custom values or tracker rules.
        if not self.settings.referenceStyleVersion then
            if self.settings.gapX==2 then self.settings.gapX=3 end
            if self.settings.gapY==2 then self.settings.gapY=4 end
            if self.settings.pressMs==520 then self.settings.pressMs=650 end
            if self.settings.inactiveDesaturation==.8 then self.settings.inactiveDesaturation=.9 end
            local c=self.settings.fillColor
            if c and c[1]==.12 and c[2]==1 and c[3]==.1 and c[4]==.84 then self.settings.fillColor=copyValue(APPEARANCE.fillColor) end
            self.settings.referenceStyleVersion=1
        end
        if not self.settings.rajdhaniStyleVersion then
            -- Preserve existing font preferences. Fresh installs must not
            -- depend on a custom SLUG that is not included in the archive.
            local face=self.settings.fontFace
            if not face or face=="Reference Display" then
                self.settings.fontFace=APPEARANCE.fontFace
            end
            if self.settings.castFontSize==17 then self.settings.castFontSize=15 end
            if self.settings.castTimeSize==16 then self.settings.castTimeSize=15 end
            self.settings.rajdhaniStyleVersion=1
        end
        if not self.settings.ringStyleVersion then
            -- Upgrade prior defaults while keeping individualized spacing/intensity.
            if self.settings.gapX==3 then self.settings.gapX=4 end
            if self.settings.gapY==4 then self.settings.gapY=7 end
            if self.settings.burstStrength==.85 then self.settings.burstStrength=.70 end
            self.settings.ringStyleVersion=1
        end
        if not self.settings.stackBadgeVersion then
            self.settings.stackBadgeVersion=1
        end
        if not self.settings.restoredStackVersion then
            if self.settings.compactStackVersion and self.settings.stackSize==14 then self.settings.stackSize=19 end
            self.settings.restoredStackVersion=1
        end
        -- Adopt the requested set style only for former defaults; explicit custom
        -- faces, sizes and colors remain untouched.
        if not self.settings.setReferenceStyleVersion then
            local s=self.settings
            if s.setCooldownFont=="HUD font" then s.setCooldownFont="Rajdhani Bold" end
            if s.setCooldownSecondarySize==12 then s.setCooldownSecondarySize=16 end
            local c=s.setCooldownSecondaryColor
            if type(c)=="table" and c[1]==.94 and c[2]==.45 and c[3]==1 and (c[4] or 1)==1 then
                s.setCooldownSecondaryColor=copyValue(APPEARANCE.setCooldownSecondaryColor)
            end
            s.setReferenceStyleVersion=1
        end
        -- The old "Bottom" potion count sat inside the ring; "Bottom" is now
        -- outside it. Keep every existing layout exactly where it was.
        if not self.settings.quickCountPositionVersion then
            local pos=self.settings.quickCountPosition
            if pos==nil or pos=="Bottom" then self.settings.quickCountPosition="Inside bottom" end
            self.settings.quickCountPositionVersion=1
        end
        -- The Z'en count methods were renamed; keep each saved choice.
        local zen={Cooldowns="All",ExoY="Timed"}
        local zenMode=zen[self.settings.setCooldownZenCountMode]
        if zenMode then self.settings.setCooldownZenCountMode=zenMode end
        -- v0.14.0 shipped both custom grids OFF. Enable the replacement once
        -- on that legacy default, then respect subsequent explicit choices.
        if not self.settings.effectGridActivationVersion then
            if self.settings.effectSelfEnabled==false and self.settings.effectTargetEnabled==false then
                self.settings.effectSelfEnabled=true; self.settings.effectTargetEnabled=true
            end
            self.settings.effectGridActivationVersion=1
        end
        if not self.settings.effectSplitVersion then
            local s=self.settings
            for _,p in ipairs({"effectSelf","effectTarget"}) do
                local dp=p.."Debuff"
                if s[p.."Enabled"]~=nil or s[p.."X"]~=nil or s[p.."Filter"]~=nil then
                for _,key in ipairs(EFFECT_GRID_KEYS) do
                    if s[dp..key]==nil and s[p..key]~=nil then s[dp..key]=copyValue(s[p..key]) end
                end
                local enabled=s[p.."Enabled"]~=false
                local filter=s[p.."Filter"]
                if filter=="Debuffs" then s[p.."Enabled"]=false end
                s[dp.."Enabled"]=enabled and filter~="Buffs"
                local x=tonumber(s[p.."X"]) or APPEARANCE[p.."X"]
                local y=tonumber(s[p.."Y"]) or APPEARANCE[p.."Y"]
                local size=tonumber(s[p.."Size"]) or APPEARANCE[p.."Size"]
                local gap=tonumber(s[p.."Gap"]) or APPEARANCE[p.."Gap"]
                local columns=tonumber(s[p.."Columns"]) or APPEARANCE[p.."Columns"]
                s[dp.."X"]=math.max(-4000,x-columns*size-(columns-1)*gap-26)
                s[dp.."Y"]=y
                if s.effectBuffColor then s[p.."Color"]=copyValue(s.effectBuffColor) end
                if s.effectDebuffColor then s[dp.."Color"]=copyValue(s.effectDebuffColor) end
                end
            end
            s.effectSplitVersion=1
        end
        -- The old HUD used one global debuff color. Migrate its inherited
        -- target copy (or stock red), while retaining independent target edits.
        if not self.settings.effectColorSeparationVersion then
            local s=self.settings
            local c=s.effectTargetDebuffColor
            local legacy=s.effectDebuffColor
            local inherited=type(c)=="table" and type(legacy)=="table" and
                c[1]==legacy[1] and c[2]==legacy[2] and c[3]==legacy[3] and (c[4] or 1)==(legacy[4] or 1)
            if not c or inherited or (c[1]==1 and c[2]==.25 and c[3]==.22 and (c[4] or 1)==1) then
                s.effectTargetDebuffColor=copyValue(APPEARANCE.effectTargetDebuffColor)
            else s.effectTargetDebuffColor=copyValue(c) end
            if s.effectSelfDebuffColor then s.effectSelfDebuffColor=copyValue(s.effectSelfDebuffColor) end
            s.effectColorSeparationVersion=1
        end
        if not self.settings.effectTargetNeutralStyleVersion then
            local s=self.settings
            local c=s.effectTargetDebuffColor
            -- Remove both previous default colors from existing installs.
            -- Retain independent custom fill colors and all other geometry.
            if not c or (c[1]==1 and ((c[2]==.76 and c[3]==.16) or (c[2]==.25 and c[3]==.22)) and (c[4] or 1)==1) then
                s.effectTargetDebuffColor=copyValue(APPEARANCE.effectTargetDebuffColor)
            end
            s.effectTargetDebuffHighlightDebuffs=false
            s.effectTargetNeutralStyleVersion=1
        end
        -- Preserve an existing shared secondary-timer size when introducing
        -- independent left/right controls.
        if self.settings.extraLeftSize==nil then self.settings.extraLeftSize=boundedSize(self.settings.extraSize,APPEARANCE.extraLeftSize,10,22) end
        if self.settings.extraRightSize==nil then self.settings.extraRightSize=boundedSize(self.settings.extraSize,APPEARANCE.extraRightSize,10,22) end
        for key in pairs(APPEARANCE) do
            if self.settings[key]==nil then self.settings[key]=self:DefaultSetting(key) end
        end
        -- Fine-tuning values that are no longer in the settings menu always use
        -- their defaults, so older saves cannot keep hidden custom values.
        -- Positions written by Edit Mode are not in this list.
        for _,key in ipairs({"synergyFadeIn","synergyFadeOut","synergyOpacity","pressMs","expiryMs",
            "glowStrength","burstStrength","loopPeriod","togglePulsePeriod","toggleGlowStrength",
            "unavailableTint","unavailableAlpha","ultDurationOffset","setCooldownTimerX","setCooldownTimerY",
            "setCooldownActiveAlpha","setCooldownCooldownAlpha","setCooldownReadyAlpha","setCooldownValueAlpha",
            "setCooldownOffBarAlpha","editAxis","attrCleanGlow"}) do
            if APPEARANCE[key]~=nil then self.settings[key]=copyValue(APPEARANCE[key]) end
        end
        for _,override in pairs(self.settings.setCooldownOverrides or {}) do
            if type(override)=="table" then override.timerX=nil; override.timerY=nil end
        end
        self.settings.menuView=nil
        if (self.settings.performanceFontCleanupVersion or 0)<1 then
            local s=self.settings
            if s.setCooldownPerformanceFont and s.setCooldownPerformanceFont~="Off" and (not self.GameFont or self:GameFont(s.setCooldownPerformanceFont)) then
                s.setCooldownFont=s.setCooldownPerformanceFont
            end
            if s.effectPerformanceFont and s.effectPerformanceFont~="Off" and (not self.GameFont or self:GameFont(s.effectPerformanceFont)) then
                for _,key in ipairs({"effectSelfFont","effectSelfDebuffFont","effectTargetFont","effectTargetDebuffFont","offBalanceFont"}) do
                    s[key]=s.effectPerformanceFont
                end
            end
            s.setCooldownPerformanceFont=nil
            s.effectPerformanceFont=nil
            s.setCooldownMartialStamina=nil
            s.performanceFontCleanupVersion=1
        end
        if (self.settings.icyConjurerNameVersion or 0)<1 then
            local f=self.settings.setCooldownFilter
            if type(f)=="table" and f["icy conjuror"]~=nil then
                if f["icy conjurer"]==nil then f["icy conjurer"]=f["icy conjuror"] end
                f["icy conjuror"]=nil
            end
            local ov=self.settings.setCooldownOverrides
            if type(ov)=="table" and ov["icy conjuror"]~=nil then
                if ov["icy conjurer"]==nil then ov["icy conjurer"]=ov["icy conjuror"] end
                ov["icy conjuror"]=nil
            end
            self.settings.icyConjurerNameVersion=1
        end
        self:NormalizeFonts()
        self.settings.customFontPath=nil; self.settings.showOutOfCombat=nil
        self.settings.paSeparate=nil; self.settings.paSeparateX=nil; self.settings.paSeparateY=nil; self.settings.paSeparateScale=nil
        if (self.settings.attrLayoutVersion or 0)<2 then
            if self.settings.attrWidth==164 or self.settings.attrWidth==168 then self.settings.attrWidth=237 end
            if self.settings.attrGap==0 then self.settings.attrGap=2 end
            self.settings.attrLayoutVersion=2
        end
        if self.settings.attrLayoutVersion<3 then
            if (self.settings.attrX==0 and (self.settings.attrY==0 or self.settings.attrY==265)) then self:ResetAttributePositions() end
            self.settings.attrLayoutVersion=3
        end
        -- Before the Default/Custom split: Cast Classic or Curved were Zera's
        -- own look (Custom); ESO textures arranged by Zera are Default. The glow
        -- option is gone and keeps its default (ESO's extra visuals hidden).
        local s=self.settings
        if (s.attrModeVersion or 0)<1 then
            if s.attrEnabled==false then s.attrMode="Off"
            elseif s.attrLayout=="Curved" or s.attrCustomSkin~=false then s.attrMode="Custom"
            else s.attrMode="Default" end
            s.attrCleanGlow=true
            s.attrModeVersion=1
        end
        self:NormalizeAttributeLayout()
        self.settings.tracking=self.settings.tracking or {}
        self.settings.procRules=self.settings.procRules or {}
        self.settings.skillVisualRules=self.settings.skillVisualRules or {}
        self.settings.multiTargetBlacklist=self.settings.multiTargetBlacklist or {}
        self.settings.trackingPolicies=self.settings.trackingPolicies or {}
        -- Hidden / whitelisted buffs and debuffs: keys are ability IDs and
        -- lower-case names. Kept apart from appearance so a reset keeps them.
        for _,key in ipairs({"effectBlacklist","effectWhitelistSelf","effectWhitelistTarget"}) do
            if type(self.settings[key])~="table" then self.settings[key]={} end
        end
        if self.settings.showLandslide==nil then self.settings.showLandslide=true end
        if self.settings.showExternalCounts==nil then self.settings.showExternalCounts=false end
        if self.settings.groupRecipientsOnly==nil then self.settings.groupRecipientsOnly=false end
    end
end
