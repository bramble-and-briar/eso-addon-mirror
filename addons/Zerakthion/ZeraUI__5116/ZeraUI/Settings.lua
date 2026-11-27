-- Standard ESO Settings > Addons panel.
-- Focused on core activations, gameplay/tracking behavior, filters, performance
-- and tools. Per-widget visual styling (sizes, fonts, spacing, colors, layout)
-- lives in Interactive Edit Mode so both stay backed by one SavedVariables table.

-- Lua 5.1/ESO uppercase does not implement Turkish dotted and dotless I.
-- Convert the six Turkish lowercase letters explicitly, then uppercase ASCII.
local function turkishTitle(value)
    if type(value)~="string" then return value end
    value=value:gsub("i","İ"):gsub("ı","I"):gsub("ç","Ç"):gsub("ğ","Ğ"):gsub("ö","Ö"):gsub("ş","Ş"):gsub("ü","Ü")
    return (value:gsub("[a-z]",string.upper))
end

function ZeraUIRegisterSettings(A)
    local LAM=LibAddonMenu2
    if not LAM or not LAM.RegisterAddonPanel or not LAM.RegisterOptionControls then return false,"LibAddonMenu-2.0 r40+ is required." end
    if A.settingsRegistered then return true end
    local turkish=A.settings.menuLanguage=="tr"
    local function tr(v) return turkish and ZeraUITranslate(v) or v end
    local function translateChoices(option,values)
        if not turkish then option.choices=values; return end
        local labels,changed={},false
        for i,v in ipairs(values) do labels[i]=tr(v); changed=changed or labels[i]~=v end
        option.choices=changed and labels or values
        option.choicesValues=changed and values or nil
    end
    local PRIMARY,BACKUP=HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP
    local T=ZeraUITracker
    local name="ZeraUISettingsPanel"
    local panel=A.settingsPanel or LAM:RegisterAddonPanel(name,{
        type="panel",name="Zera UI",displayName="|cE9C46AZera|r |cFFF4DCUI|r",
        author="|cE9C46AZerakthion|r",version="1.1.6",slashCommand="/zeraset",
        registerForRefresh=true,registerForDefaults=true,
        resetFunc=function() if A.ResetEffectGridDefaults then A:ResetEffectGridDefaults() end end,
    })
    A.settingsPanel=panel
    local function refresh()
        if CALLBACK_MANAGER then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel",panel) end
    end

    -- Coalesced per-frame apply: dragging a slider or resetting defaults runs once.
    local queued={}
    local function soon(id,fn)
        if queued[id] then return end
        queued[id]=true
        local run=function() queued[id]=nil; fn() end
        if zo_callLater then zo_callLater(run,1) else run() end
    end
    local function applyHUD() soon("hud",function() A:ApplySettings() end) end
    local function toggle(label,key,tooltip)
        return {type="checkbox",name=label,tooltip=tooltip,vabKey=key,
            getFunc=function() return A.settings[key] end,
            setFunc=function(v) A.settings[key]=v; applyHUD() end}
    end
    local function slider(label,key,min,max,step,tooltip)
        return {type="slider",name=label,min=min,max=max,step=step,decimals=step<1 and 2 or 0,tooltip=tooltip,vabKey=key,
            getFunc=function() return A.settings[key] end,
            setFunc=function(v) A:SetHudSize(key,v); applyHUD() end}
    end
    local function attrCustom() return A.settings.attrMode=="Custom" end
    local function only(o,fn) o.disabled=function() return not fn() end; return o end
    local function header(label) return {type="header",name=label} end
    local function sub(title,controls) return {type="submenu",name=title,controls=controls} end

    local function setOption(key,v)
        A.settings[key]=v; soon("sets",function() A.setCooldowns:ApplyConfig() end)
    end
    local function setToggle(label,key,tooltip)
        return {type="checkbox",name=label,tooltip=tooltip,vabKey=key,getFunc=function() return A.settings[key] end,setFunc=function(v) setOption(key,v) end}
    end
    local function setSlider(label,key,min,max,step,tooltip)
        return {type="slider",name=label,min=min,max=max,step=step,decimals=step<1 and 2 or 0,tooltip=tooltip,vabKey=key,
            getFunc=function() return A.settings[key] end,setFunc=function(v) setOption(key,v) end}
    end
    local function setDropdown(label,key,choices,tooltip)
        return {type="dropdown",name=label,choices=choices,tooltip=tooltip,vabKey=key,
            getFunc=function() return A.settings[key] end,setFunc=function(v) setOption(key,v); refresh() end}
    end
    local function effectOption(key,v)
        A.effectHUD:SetSizeOption(key,v)
        soon("effects",function() A.effectHUD:ApplyConfig() end)
    end
    local function effectToggle(label,key,tooltip)
        return {type="checkbox",name=label,tooltip=tooltip,vabKey=key,getFunc=function() return A.settings[key] end,setFunc=function(v) effectOption(key,v) end}
    end
    local function effectSlider(label,key,min,max,step,tooltip)
        return {type="slider",name=label,min=min,max=max,step=step,tooltip=tooltip,vabKey=key,
            getFunc=function() return A.settings[key] end,setFunc=function(v) effectOption(key,v) end}
    end

    -- Attribute layout dropdown (dynamic choices depend on attrMode).
    local function attributeLayoutChoices() return A:AttributeLayoutChoices() end
    local attributeLayoutOption={type="dropdown",name="Layout",reference="ZeraUIAttributeLayoutDropdown",
        choices=attributeLayoutChoices(),default=A:DefaultSetting("attrLayout"),
        tooltip="Default: Pyramid or Native. Custom: Curved, Native, Stacked or Pyramid. Switching layouts resets their position.",
        getFunc=function() return A.settings.attrLayout end,setFunc=function(v) A:SetAttributeLayout(v); refresh() end}
    local function updateAttributeLayoutChoices()
        translateChoices(attributeLayoutOption,attributeLayoutChoices())
        local dropdown=_G[attributeLayoutOption.reference]
        if dropdown and dropdown.UpdateChoices then
            dropdown:UpdateChoices(attributeLayoutOption.choices,attributeLayoutOption.choicesValues)
            if dropdown.UpdateValue then dropdown:UpdateValue() end
        end
        refresh()
    end

    -- Set filter & individual override helpers (refreshed automatically when panel opens).
    local setChoices,setKeys=A.setCooldowns:CatalogChoices()
    local selectedSet=setChoices[1]
    local setChoiceOption={type="dropdown",name="Select set",reference="ZeraUISetFilterDropdown",choices=setChoices,scrollable=true,
        getFunc=function() return selectedSet end,setFunc=function(v) selectedSet=v; refresh() end}
    local function refreshSetChoices()
        local oldKey=setKeys[selectedSet]
        setChoices,setKeys=A.setCooldowns:CatalogChoices()
        if oldKey then for label,key in pairs(setKeys) do if key==oldKey then selectedSet=label; break end end end
        if not setKeys[selectedSet] then selectedSet=setChoices[1] end
        setChoiceOption.choices=setChoices
        local dropdown=_G[setChoiceOption.reference]
        if dropdown and dropdown.UpdateChoices then dropdown:UpdateChoices(setChoices); if dropdown.UpdateValue then dropdown:UpdateValue() end end
        refresh()
    end
    local sounds={"None","ABILITY_SYNERGY_READY","ABILITY_ULTIMATE_READY","ABILITY_SLOTTED","ACHIEVEMENT_AWARDED","CHAMPION_POINT_GAINED","DUEL_START","DISPLAY_ANNOUNCEMENT"}
    local individualSounds={"Global"}; for _,sound in ipairs(sounds) do individualSounds[#individualSounds+1]=sound end
    local function selectedOverride()
        return A.settings.setCooldownOverrides[setKeys[selectedSet]] or {}
    end
    local function writeOverride(field,value)
        local key=setKeys[selectedSet]; if not key then return end
        local override=A.settings.setCooldownOverrides[key] or {}
        override[field]=value
        A.settings.setCooldownOverrides[key]=next(override) and override or nil
        A.setCooldowns:ApplyConfig()
    end
    local function setOverrideSlider(label,field,min,max,tooltip)
        return {type="slider",name=label,min=min,max=max,step=1,tooltip=tooltip,
            getFunc=function() return selectedOverride()[field] or 0 end,
            setFunc=function(v) writeOverride(field,v~=0 and v or nil) end}
    end
    local function overrideColor(label,field,globalKey)
        return {type="colorpicker",name=label,
            getFunc=function() return unpack(selectedOverride()[field] or A.settings[globalKey]) end,
            setFunc=function(r,g,b,a) writeOverride(field,{r,g,b,a or 1}) end}
    end
    local function overrideSound(label,field)
        return {type="dropdown",name=label,choices=individualSounds,
            getFunc=function() return selectedOverride()[field] or "Global" end,
            setFunc=function(v) if v=="Global" then writeOverride(field,nil) else writeOverride(field,v) end end}
    end

    -- Per-skill animation override helpers (refreshed automatically when panel opens).
    local visual={slot="Front 1",category=PRIMARY,index=1,rule={},message=""}
    local function loadVisual(value)
        visual.slot=value or visual.slot
        local bar,index=visual.slot:match("^(%a+) (%d+)$")
        visual.category=bar=="Back" and BACKUP or PRIMARY
        visual.index=tonumber(index) or 1
        visual.key=T.IdentifyVisualSlot(visual.index+2,visual.category)
        visual.rule={}; visual.message=""
        local saved=visual.key and A.settings.skillVisualRules[visual.key]
        for k,v in pairs(saved or {}) do visual.rule[k]=v end
    end
    local function visualToggle(label,field)
        return {type="dropdown",name=label,choices={"Global","On","Off"},
            getFunc=function() local v=visual.rule[field]; return v==true and "On" or v==false and "Off" or "Global" end,
            setFunc=function(v) visual.rule[field]=v=="On" and true or v=="Off" and false or nil end}
    end
    local function visualNumber(label,field,max,step,tooltip)
        return {type="slider",name=label,min=0,max=max,step=step,decimals=step<1 and 1 or 0,tooltip=tooltip,
            getFunc=function() return tonumber(visual.rule[field]) or 0 end,
            setFunc=function(v) visual.rule[field]=v>0 and v or nil end}
    end
    local function saveVisual(clear)
        local key=T.IdentifyVisualSlot(visual.index+2,visual.category)
        if not key then visual.message="No skill is currently slotted in "..visual.slot.."."; refresh(); return end
        visual.key=key
        if clear then A.settings.skillVisualRules[key]=nil; visual.rule={}; visual.message="Restored global animation rules for "..key.."."
        else
            local rule={}; for k,v in pairs(visual.rule) do rule[k]=v end
            A.settings.skillVisualRules[key]=next(rule) and rule or nil
            visual.message=next(rule) and ("Saved animation rules for "..key..".") or ("Cleared overrides for "..key.." (using global settings).")
        end
        A:ApplySettings(); refresh()
    end

    -- Multi-target blacklist slot helper.
    local blacklistSlot="Front 1"
    local function blacklistKey()
        local bar,index=blacklistSlot:match("^(%a+) (%w+)$")
        local category=bar=="Back" and BACKUP or PRIMARY
        local slotIndex=index=="Ult" and 8 or (tonumber(index) or 1)+2
        return T.IdentifyVisualSlot(slotIndex,category)
    end

    -- Effect-area tracking/filtering selector (visual styling moved to Interactive Edit Mode).
    local areaNames={"Self Buffs","Self Debuffs","Target Buffs","Target Debuffs"}
    local areaSpecs={
        {"effectSelf","Self buffs",false,false},
        {"effectSelfDebuff","Self debuffs",true,false},
        {"effectTarget","Target buffs",false,true},
        {"effectTargetDebuff","Target debuffs",true,true},
    }
    local area=1
    local function areaPrefix() return areaSpecs[area][1] end
    function A:ResetEffectGridDefaults()
        local filterKeys={"Enabled","Permanent","Sort","Mine"}
        for _,spec in ipairs(areaSpecs) do
            for _,suffix in ipairs(filterKeys) do
                local key=spec[1]..suffix
                local v=self:DefaultSetting(key)
                if v~=nil then self.settings[key]=v end
            end
        end
        self.effectHUD:ApplyConfig()
    end

    -- Buff/debuff blacklist & whitelist editor.
    local listUi={choice="Hidden effects (blacklist)",input="",entry=nil,values={}}
    function listUi.key()
        return listUi.choice=="My whitelist" and "effectWhitelistSelf" or listUi.choice=="Target whitelist" and "effectWhitelistTarget" or "effectBlacklist"
    end
    function listUi.update()
        local choices,values={},{}
        for k in pairs(A.settings[listUi.key()] or {}) do
            local label=type(k)=="number" and (tostring(k).." — "..(GetAbilityName and GetAbilityName(k) or "")) or tostring(k)
            choices[#choices+1]=label; values[label]=k
        end
        table.sort(choices)
        if #choices==0 then choices={"—"} end
        listUi.values=values
        if not listUi.values[listUi.entry or ""] then listUi.entry=choices[1] end
        local d=_G.ZeraUIEffectListEntries
        if d and d.UpdateChoices then d:UpdateChoices(choices); if d.UpdateValue then d:UpdateValue() end end
    end
    function listUi.summary()
        local n=0; for _ in pairs(A.settings[listUi.key()] or {}) do n=n+1 end
        return n==0 and "List is empty." or (n.." entry(ies) in this list.")
    end

    -- Section icons from ESO's own main-menu art.
    local SECTION_ICON={
        ["01"]="EsoUI/Art/MainMenu/menuBar_character_up.dds",
        ["02"]="EsoUI/Art/MainMenu/menuBar_skills_up.dds",
        ["03"]="EsoUI/Art/MainMenu/menuBar_champion_up.dds",
        ["04"]="EsoUI/Art/MainMenu/menuBar_group_up.dds",
        ["05"]="EsoUI/Art/MainMenu/menuBar_inventory_up.dds",
        ["06"]="EsoUI/Art/MainMenu/menuBar_journal_up.dds",
    }
    local function sectionHeader(title)
        local h=header(title); h.vabRole="section"; h.vabIcon=SECTION_ICON[title:sub(1,2)]; return h
    end

    -- Direct declarative 6-section layout: zero intermediate copying or duplicate controls.
    local sections={
        {"02  |  Action bar & animations","Availability rules, warning thresholds and animation behavior",{
            sub("Availability & timers",{
                toggle("Show skill tooltips","showSkillTooltips"),
                {type="dropdown",name="Active bar position",vabKey="activeBarPosition",
                    choices={"Default (Front top)","Active bar on top","Active bar on bottom"},
                    choicesValues={"Default","Top","Bottom"},
                    tooltip="Choose whether front/back rows stay fixed, or move the active weapon bar to the top or bottom row whenever you weapon swap.",
                    getFunc=function() return A.settings.activeBarPosition or "Default" end,
                    setFunc=function(v) A.settings.activeBarPosition=v; applyHUD() end},
                toggle("Hide idle skills on inactive bar","hideInactiveIdle","On the inactive weapon bar, hide skill boxes that have no active timer, stack, toggle, proc, or warning animation."),
                toggle("Darken unusable skills","showUnavailable"),
                toggle("Darken low-resource skills","darkenResource","Darken skills whose Magicka or Stamina cost exceeds your current resource."),
                toggle("Darken corpse-required skills","darkenCorpse","Darken Blastbones/corpse consumers when ESO reports a corpse is required and none is available."),
                toggle("Darken skills without valid target","darkenTarget","Darken enemy-targeted skills when you have no valid attackable target or are out of range."),
                header("Timer thresholds"),
                slider("Soon warning (seconds)","soonSeconds",1,10,.5),
                slider("Last warning (seconds)","lastSeconds",.5,5,.1),
                slider("Show decimals below (seconds)","decimalSeconds",0,10,.5),
                header("Several enemies"),
                toggle("Debuff timers follow your target","followTargetTimers","Your DoT/debuff timer shows the time left on the enemy you look at: another enemy shows its own time, an enemy without it shows nothing, and looking away keeps the last target's time. Per skill, the tracking window can switch to Soonest / Latest instead."),
                {type="checkbox",name="Keep the last target's timer when looking away",vabKey="followKeepLast",
                    tooltip="With no enemy under the crosshair (or with the cursor shown), keep counting down the last target's debuff timer.",
                    disabled=function() return A.settings.followTargetTimers==false end,
                    getFunc=function() return A.settings.followKeepLast~=false end,setFunc=function(v) A.settings.followKeepLast=v; applyHUD() end},
            }),
            sub("Animations & glows",{
                toggle("Gold cast / synergy animations","animations"),
                toggle("Skill cast flash","pressFlash"),
                toggle("Pressed button effect","pressSink"),
                toggle("Weapon bar transition animation","swapFade"),
                toggle("Gold flash when an effect expires","expiryGlow"),
                header("Gold border"),
                toggle("Gold loop near expiration","expiryLoop"),
                slider("Gold loop warning (seconds)","loopSeconds",.5,10,.5),
                toggle("Gold loop at stack threshold","stackLoop"),
                slider("Gold loop stack threshold","loopStacks",1,10,1),
                toggle("Gold loop on inactive bar","loopInactive"),
                header("Toggle & proc glow"),
                toggle("Glow for toggled skills","toggleGlow","Shows an active edge instead of the green fill. Also applies to Overload's ultimate ring."),
                toggle("Repeat pulse while toggled on","togglePulse"),
                toggle("Enable proc highlight","procHighlight","Persistent glow while the selected player proc effect is active."),
                toggle("Pulse proc highlight","procPulse"),
                {type="button",name="Replay sample glow animations",func=function() A:ReplayVisualPreview() end},
            }),
        }},
        {"03  |  HUD widgets & performance","Resource bar engine, update rate and widget activations",{
            sub("Resource bars",{
                {type="description",text="Default Attribute Bar: ESO's own bars, arranged by Zera UI. Custom Attribute Bar: Zera UI's own bars; ESO's bars are hidden and paused. Sizes, fonts and spacing are edited live in Interactive HUD Edit Mode."},
                {type="dropdown",name="Attribute bars",vabKey="attrMode",vabMain=true,choices={"Off","Default Attribute Bar","Custom Attribute Bar"},choicesValues={"Off","Default","Custom"},
                    tooltip="Off: ESO handles its bars, Zera UI does not touch them.",
                    getFunc=function() return A.settings.attrMode end,
                    setFunc=function(v) A:SetAttributeMode(v); updateAttributeLayoutChoices() end},
                attributeLayoutOption,
                header("Shield, warnings & performance"),
                toggle("Show damage shield value","attrShieldValue","Shows the remaining shield in blue beside health, e.g. 19.7k (8.4k) 100%."),
                only(toggle("Show trauma","attrTrauma","Custom bars: damage that must be healed before health rises again, as a purple mark on the health bar."),attrCustom),
                only(toggle("Show no healing","attrNoHealing","Custom bars: a dark red tint on the health bar while you cannot be healed."),attrCustom),
                only({type="dropdown",name="Update rate",vabKey="attrUpdateRate",choices=ZeraUIAttributeCore.RATES,
                    tooltip="Custom bars: how often a changing value is redrawn. Every change is the most precise; a limit saves work in big fights. The final value is always shown.",
                    getFunc=function() return A.settings.attrUpdateRate end,setFunc=function(v) A.settings.attrUpdateRate=v end},attrCustom),
                toggle("Red text at 25% or lower","attrLowWarning","Health text turns red at 25% or lower. On the Curved arcs all three resources do."),
            }),
            sub("Ultimate, potion, cast & synergy",{
                header("Ultimate"),
                toggle("Pulse when ultimate is ready","ultimateReadyGlow","Continuous metallic gold pulse when you have enough ultimate. Active Overload takes priority with its own rotating lightning ring."),
                toggle("Metallic ring bloom","ringBloom","Extra soft glow when the ultimate or potion is ready, or while an ultimate effect is active. Charge and active effect remain independent."),
                toggle("Show ultimate active duration","showUltDuration","Shows actual active effect time, separate from your current ultimate points."),
                toggle("Show inactive ultimate","showBackUlt"),
                toggle("Show ultimate costs","showUltCost"),
                header("Potion / quickslot"),
                toggle("Show potion / quickslot meter","showQuickslot"),
                header("Cast / channel / GCD bar"),
                toggle("Show global cooldown bar","showGCD","Master switch for the cast, channel and GCD widget."),
                toggle("Show instant skill global cooldown","castShowGCD"),
                toggle("Show channeled abilities","castShowChannels","Uses the current ability's channel time instead of the 1s global cooldown. Meditate shows elapsed time."),
                toggle("Show cast-time abilities","castShowHardcasts"),
                header("Synergy"),
                toggle("Show synergy alert","showSynergy"),
                {type="dropdown",name="Synergy disappearance",choices={"Instant","Fade","Flash + fade"},default="Instant",
                    tooltip="Flash requires a confirmed supported synergy use. The master animation switch disables fade and flash.",
                    getFunc=function() local s=A.settings; return s.synergyInstantHide and "Instant" or (s.synergyPressFlash and s.synergyAnimations and "Flash + fade" or "Fade") end,
                    setFunc=function(v) local s=A.settings; s.synergyInstantHide=v=="Instant"; s.synergyAnimations=v~="Instant"; s.synergyPressFlash=v=="Flash + fade"; A:ApplySettings() end},
                {type="editbox",name="Synergy key label",default=A:DefaultSetting("synergyKey"),
                    getFunc=function() return A.settings.synergyKey end,setFunc=function(v) A.settings.synergyKey=v; A:ApplySettings() end},
            }),
        }},
        {"04  |  Tracking & class mechanics","Group buffs, target counts and class passives",{
            sub("Group buffs & target counts",{
                {type="description",text="|cEBC773Recipient count|r  ·  Allies your skill has affected, excluding yourself. Frost Cloak, Molten Weapons, group heals and other supported buffs use confirmed applications."},
                toggle("Show target count","showTargets","Counts distinct enemies or recipients of your supported heals, shields and group buffs."),
                toggle("Show count for one target","showSingleTarget","Show 1 as well as larger counts."),
                toggle("Show one group buff recipient","showSingleGroupBuff","Show 1 for supported group buffs even when the ordinary single-target counter is hidden. Yourself is not counted."),
                toggle("Group members only (friendly recipients)","groupRecipientsOnly","Exclude friendly recipients outside your group where the API identifies them. Enemy counts are unchanged."),
                {type="dropdown",name="Multi-target timer expiration",choices={"Last to expire","First to expire"},default="Last to expire",
                    tooltip="Pick the first or last active recipient's expiration. Does not change the number of recipients or true stacks.",
                    getFunc=function() return A.settings.targetExpireFirst and "First to expire" or "Last to expire" end,
                    setFunc=function(v) A.settings.targetExpireFirst=v=="First to expire"; A:ApplySettings() end},
                {type="dropdown",name="Multi-target blacklist skill",choices={"Front 1","Front 2","Front 3","Front 4","Front 5","Front Ult","Back 1","Back 2","Back 3","Back 4","Back 5","Back Ult"},
                    getFunc=function() return blacklistSlot end,setFunc=function(v) blacklistSlot=v; refresh() end},
                {type="checkbox",name="Hide target count for selected skill",tooltip="Saved by ability (including Scribing scripts), not by slot. Timers, stacks and charges are unaffected.",
                    disabled=function() return blacklistKey()==nil end,
                    getFunc=function() local key=blacklistKey(); return key and A.settings.multiTargetBlacklist[key]==true or false end,
                    setFunc=function(v) local key=blacklistKey(); if key then A.settings.multiTargetBlacklist[key]=v and true or nil; A:ApplySettings() end end},
            }),
            sub("Class mechanics",{
                header("Vampire"),
                toggle("Strike from the Shadows timer","showVampirePassive","Show the observed passive buff on Blood Frenzy and both morphs. The timer appears only while the buff is active."),
                header("Arcanist"),
                {type="dropdown",name="Arcanist mastery timer location",vabKey="arcanistPassiveMode",choices={"Off","Fatecarver","Tentacular Dread","Both"},
                    tooltip="Show observed Abyssal Emergence (A) and Fate Realigned (F) buff durations on the selected skill family. No timer is guessed when the buff is not observed.",
                    getFunc=function() return A.settings.arcanistPassiveMode end,
                    setFunc=function(v) A.settings.arcanistPassiveMode=v; A:ApplySettings() end},
                header("Necromancer"),
                toggle("Show Nothing Wasted timer","showNothingWasted","Shows the observed or inferred Nothing Wasted countdown on Necromancer tether and corpse skills."),
                toggle("Nothing Wasted decay warning","nwWarning","Gold loop before the passive decays, even on the inactive bar."),
                slider("Nothing Wasted warning seconds","nwWarnSeconds",1,5,.5),
                header("Dragonknight"),
                toggle("Landslide / Inexorable Descent on Whip","showLandslide","L: shows the actual player buff stack independently of Seething Fury and Whip charges. Hidden when inactive."),
                header("All classes"),
                toggle("External heal application count","showExternalCounts","E: counts distinct active effect slots from other players on yourself for supported Vigor and Regeneration morphs. It is not your recipient count or a guaranteed unique-caster count."),
                toggle("Class ultimate-generation cooldowns","showUltimatePassives","Show estimated internal cooldowns above the action bar after supported class ultimate-generation passives trigger. Only matching combat events are registered."),
            }),
        }},
        {"05  |  Sets","Set tracking, special mechanics, filters and sounds",{
            sub("Set tracking & special mechanics",{
                {type="description",text="Automatically tracks complete gear sets on either weapon bar. Customize icon layout, fonts and colors directly in Interactive HUD Edit Mode."},
                toggle("Enable set cooldown tracker","setCooldownEnabled"),
                setToggle("Show outside combat","setCooldownOutsideCombat"),
                setToggle("Show ready set icons","setCooldownReady"),
                setToggle("Show off-bar set icons","setCooldownOffBar"),
                setToggle("Show cooldown during active effects","setCooldownBoth"),
                setSlider("Set decimal countdown threshold","setCooldownDecimal",0,10,1,"0 = whole seconds; show tenths below this many seconds."),
                setToggle("Golden loop when a set can proc","setCooldownBorderAnimation","In combat, shows the skill-bar golden loop while a set's internal cooldown is over and it can proc again. Sets without a cooldown, or with one under 3 seconds, never loop."),
                setToggle("Golden fade-out on set proc","setCooldownProcFlash","Plays the skill-bar golden fade-out when a set procs, when a set without a cooldown starts, or when a resource or ultimate set reaches its threshold."),
                setToggle("Resource threshold glow","setCooldownResourceGlow","Fills the resource label of Coral Riptide, Bahsei's Mania and Martial Knowledge towards the full bonus. At the threshold it gets a gold edge with a light running around it."),
                {type="button",name="Toggle sample icons",func=function()
                    if not A.settings.setCooldownEnabled then A.settings.setCooldownEnabled=true; A:ApplySettings() end
                    A.setCooldowns:ToggleDemo(); refresh()
                end},
                header("Special mechanics"),
                setToggle("Z'en: focus single boss","setCooldownZenBoss"),
                {type="dropdown",name="Z'en: count method",choices={"All damage effects","Longer than 1 s"},choicesValues={"All","Timed"},vabKey="setCooldownZenCountMode",
                    tooltip="All damage effects counts every player-owned damage-type effect on the selected target, including short or untimed effects. Longer than 1 s requires a duration over one second and an active Z'en mark. Neither method guarantees every counted effect is a true DoT.",
                    getFunc=function() return A.settings.setCooldownZenCountMode=="Timed" and "Timed" or "All" end,
                    setFunc=function(v) setOption("setCooldownZenCountMode",v=="Timed" and "Timed" or "All"); refresh() end},
                setToggle("Roaring Opportunist: predicted duration","setCooldownRODuration"),
                setToggle("Roaring Opportunist: affected recipients","setCooldownROCount"),
                setToggle("Pearls / Esoteric: resource percentage","setCooldownResourceValue"),
                setToggle("Pearls / Esoteric: proc count","setCooldownProcCount"),
                {type="description",text="In gameplay: /zera sets preview for sample icons, /zera sets for supported equipped sets, /zera sets gear to diagnose piece counts and missing IDs. /zera sets probe learns Merciless Charge and Corpseburster IDs from real combat events during a 30-second test."},
            }),
            sub("Set filters, overrides & sounds",{
                header("Sounds"),
                setDropdown("Set proc sound","setCooldownProcSound",sounds),
                {type="button",name="Test set proc sound",func=function() A.setCooldowns:PlayAlert(A.settings.setCooldownProcSound) end},
                setDropdown("Set ready sound","setCooldownReadySound",sounds),
                {type="button",name="Test set ready sound",func=function() A.setCooldowns:PlayAlert(A.settings.setCooldownReadySound) end},
                header("Individual sets"),
                {type="description",text="Filters change which equipped set icons are displayed. Normal and perfected variants share preferences."},
                setDropdown("Set filter mode","setCooldownFilterMode",{"All equipped","Hide selected","Only selected"}),
                setChoiceOption,
                {type="checkbox",name="Add selected set to filter list",getFunc=function() return A.settings.setCooldownFilter[setKeys[selectedSet]]==true end,
                    setFunc=function(v) local key=setKeys[selectedSet]; if key then A.settings.setCooldownFilter[key]=v and true or nil; A.setCooldowns:ApplyConfig() end end},
                {type="description",text=function() local n=0; for _ in pairs(A.settings.setCooldownFilter) do n=n+1 end; return n.." selected set(s) in filter list." end},
                setOverrideSlider("Selected set icon size","size",0,128,"0 = use global icon size. Values below 24 use 24 pixels."),
                overrideColor("Selected set active color","activeColor","setCooldownActiveColor"),
                overrideColor("Selected set cooldown color","cooldownColor","setCooldownCooldownColor"),
                {type="button",name="Use global colors for selected set",func=function() writeOverride("activeColor",nil); writeOverride("cooldownColor",nil); refresh() end},
                overrideSound("Selected set proc sound","procSound"),
                overrideSound("Selected set ready sound","readySound"),
                {type="button",name="Clear set filter list",func=function() setOption("setCooldownFilter",{}); refresh() end},
                {type="button",name="Reset selected set overrides",func=function() local key=setKeys[selectedSet]; if key then A.settings.setCooldownOverrides[key]=nil; A.setCooldowns:ApplyConfig(); refresh() end end},
            }),
        }},
        {"06  |  Buffs, debuffs & tools","Effect filters, Off Balance, per-skill rules and Tracking Studio",{
            sub("Buff & debuff tracking",{
                {type="description",text="Four independent buff/debuff groups sharing one unit scan. Click any grid in Interactive HUD Edit Mode to style its icons, columns, growth, font and colors."},
                effectToggle("Long effects","effectLongEffects","Show effects that last longer than one minute."),
                effectToggle("Show effects outside combat","effectOutsideCombat"),
                effectToggle("Hide matching native buff containers","effectHideNative","Only the corresponding enabled custom grid replaces its matching native container when available. If the native HUD still duplicates it, disable the native display in ESO Combat settings."),
                {type="button",name="Preview enabled effect grids",func=function() A.effectHUD:ToggleDemo() end},
                header("Per-area filters"),
                {type="dropdown",name="Edit effect area",choices=areaNames,
                    tooltip="Select a group to edit its activation and filtering rules.",
                    getFunc=function() return areaNames[area] end,
                    setFunc=function(v) for i,label in ipairs(areaNames) do if label==v then area=i; break end end; refresh() end},
                {type="checkbox",name="Enable selected effect area",
                    getFunc=function() return A.settings[areaPrefix().."Enabled"] end,
                    setFunc=function(v) effectOption(areaPrefix().."Enabled",v) end},
                {type="checkbox",name="Effect area permanent effects",
                    tooltip="Include effects without a countdown. This can add many icons.",
                    getFunc=function() return A.settings[areaPrefix().."Permanent"] end,
                    setFunc=function(v) effectOption(areaPrefix().."Permanent",v) end},
                {type="dropdown",name="Effect area sort order",choices={"Shortest first","Game order"},
                    getFunc=function() return A.settings[areaPrefix().."Sort"] end,
                    setFunc=function(v) effectOption(areaPrefix().."Sort",v) end},
                {type="checkbox",name="Only my selected target effects",
                    tooltip="Available for target areas. Excludes effects cast by other players.",
                    disabled=function() return not areaSpecs[area][4] end,
                    getFunc=function() return A.settings[areaPrefix().."Mine"] end,
                    setFunc=function(v) if areaSpecs[area][4] then effectOption(areaPrefix().."Mine",v) end end},
            }),
            sub("Hide & whitelist",{
                {type="description",text="Show the mouse cursor (default key: .) and hover over any buff or debuff icon to read its tooltip. Right-click the icon to hide it (blacklist) or add it to a whitelist. Grids set to whitelist only show nothing else."},
                effectToggle("Mouse tooltips & right-click menu","effectInteractive","Icons react to the mouse only while the cursor is shown and the grid is locked. Turn off if you never use the cursor over the HUD."),
                effectToggle("Self buffs: only whitelisted","effectSelfWhitelistOnly","Uses My whitelist."),
                effectToggle("Self debuffs: only whitelisted","effectSelfDebuffWhitelistOnly","Uses My whitelist."),
                effectToggle("Target buffs: only whitelisted","effectTargetWhitelistOnly","Uses Target whitelist."),
                effectToggle("Target debuffs: only whitelisted","effectTargetDebuffWhitelistOnly","Uses Target whitelist."),
                {type="dropdown",name="List to edit",choices={"Hidden effects (blacklist)","My whitelist","Target whitelist"},
                    getFunc=function() return listUi.choice end,
                    setFunc=function(v) listUi.choice=v; listUi.entry=nil; listUi.update(); refresh() end},
                {type="editbox",name="Add by ID or name",tooltip="An ability ID (e.g. 61665) or an exact effect name (e.g. Major Brutality). A name matches every effect with that name.",
                    getFunc=function() return listUi.input or "" end,setFunc=function(v) listUi.input=v end},
                {type="button",name="Add to list",width="half",func=function()
                    local text=tostring(listUi.input or ""):gsub("^%s+",""):gsub("%s+$","")
                    if text=="" then return end
                    local id=tonumber(text)
                    A.effectHUD:SetListed(listUi.key(),id,not id and text or nil,true)
                    listUi.input=""; listUi.update(); refresh()
                end},
                {type="dropdown",name="Entries",choices={"—"},reference="ZeraUIEffectListEntries",
                    tooltip="Choose an entry, then press Remove selected.",
                    getFunc=function() return listUi.entry or "—" end,setFunc=function(v) listUi.entry=v end},
                {type="button",name="Remove selected",width="half",func=function()
                    local value=listUi.values[listUi.entry or ""]
                    if value~=nil then A.settings[listUi.key()][value]=nil; A.effectHUD:ListsChanged() end
                    listUi.entry=nil; listUi.update(); refresh()
                end},
                {type="description",text=function() return listUi.summary() end},
                {type="button",name="Clear this list",warning="Removes every entry from the selected list.",func=function()
                    local list=A.settings[listUi.key()]
                    for k in pairs(list) do list[k]=nil end
                    A.effectHUD:ListsChanged(); listUi.entry=nil; listUi.update(); refresh()
                end},
            }),
            sub("Off Balance tracker",{
                {type="description",text="Separate icon for the current hostile target: bright green = active, red = immunity, gold = ready. Actual immunity effects take priority. Size, font and colors are customized in Interactive HUD Edit Mode."},
                effectToggle("Enable Off Balance icon","offBalanceEnabled"),
                effectToggle("Exclude Off Balance from target grid","offBalanceSeparate"),
                effectToggle("Show when Off Balance is ready","offBalanceReady"),
                effectToggle("Estimate missing Off Balance immunity","offBalanceEstimate","After an observed natural expiry on the same target, show a marked 15s fallback until the real immunity is available. Never transfers across targets."),
                effectToggle("Off Balance expiry flash","offBalanceFlash"),
                effectSlider("Off Balance flash threshold (seconds)","offBalanceFlashSeconds",1,10,1),
            }),
            sub("Per-skill animations & stack thresholds",{
                {type="description",text="Override glow animations or the gold stack warning for a specific skill. Saved by ability (including Scribing scripts), not by slot. Refreshes automatically when opened."},
                {type="dropdown",name="Animation skill slot",choices={"Front 1","Front 2","Front 3","Front 4","Front 5","Back 1","Back 2","Back 3","Back 4","Back 5"},
                    getFunc=function() return visual.slot end,setFunc=function(v) loadVisual(v); refresh() end},
                {type="description",text=function()
                    local key,id=T.IdentifyVisualSlot(visual.index+2,visual.category)
                    return key and (tostring(GetSlotName(visual.index+2,visual.category) or "Skill").." | Ability ID: "..id.."\n"..key) or "No skill in this slot."
                end},
                visualToggle("Skill cast flash","pressFlash"),
                visualToggle("Skill expiration flash","expiryGlow"),
                visualToggle("Skill expiration gold loop","expiryLoop"),
                visualToggle("Skill stack gold loop","stackLoop"),
                visualToggle("Skill loop on inactive bar","loopInactive"),
                visualNumber("Skill stack threshold (0 = Global)","loopStacks",30,1,"The badge becomes gold and the stack loop triggers at this count. Set 0 to follow the global threshold."),
                visualNumber("Skill expiration warning (0 = Global)","loopSeconds",10,.1,"Seconds remaining before the gold border starts. Set 0 to follow the global duration warning."),
                {type="button",name="Save skill animations",func=function() saveVisual(false) end,width="half"},
                {type="button",name="Restore skill animation defaults",func=function() saveVisual(true) end,width="half"},
                {type="description",text=function() return visual.message end},
            }),
            sub("Skill tracking & effect IDs",{
                {type="description",text="Most skills need nothing here: Zera UI already reads the game's own timer, built-in effect IDs and phase timers (such as Ulfsild's Contingency and Resolving Vigor). Use the tracking window when a skill shows the wrong timer or none at all."},
                {type="description",text="How it works:  1) Open the window and click the skill on your bar.  2) Press Record and cast the skill 2-3 times on a target dummy.  3) The effects that came right after that skill are listed first; click Middle, Left or Right to use one.  4) Press Save timers."},
                {type="button",name="Open skill tracking window",func=function() A:OpenStudio() end},
                {type="description",text=function()
                    local lines={}
                    for key,list in pairs(A.settings.tracking or {}) do
                        if type(list)=="table" and list[1] then
                            local ids={}
                            for i,r in ipairs(list) do ids[i]=r.mode=="off" and "—" or tostring(r.effect) end
                            lines[#lines+1]=key.."  →  "..table.concat(ids,", ")
                        end
                    end
                    table.sort(lines)
                    return #lines>0 and (A.settings.menuLanguage=="tr" and "Kendi takip kuralların:\n" or "Your own tracking rules:\n")..table.concat(lines,"\n")
                        or (A.settings.menuLanguage=="tr" and "Henüz kendi takip kuralın yok." or "You have no tracking rules of your own yet.")
                end},
                {type="button",name="Remove all my tracking rules",warning="Built-in tracking returns for every skill. This cannot be undone.",func=function()
                    for key in pairs(A.settings.tracking) do A.tracker:ClearRule(key) end
                    for key in pairs(A.settings.procRules) do A.settings.procRules[key]=nil end
                    for key in pairs(A.settings.trackingPolicies) do A.settings.trackingPolicies[key]=nil end
                    A:ApplySettings(); A:RefreshSlots(); if A.StudioVisible and A:StudioVisible() then A:StudioRefresh(true) end; refresh()
                end},
            }),
        }},
    }

    local ordered={
        sectionHeader("01  |  General"),
        {type="dropdown",name="Language / Dil",choices={"English","Türkçe"},default="English",requiresReload=true,
            tooltip="Switches the Zera UI settings menu and Edit Mode between English and Turkish. Requires a UI reload.",
            getFunc=function() return A.settings.menuLanguage=="tr" and "Türkçe" or "English" end,
            setFunc=function(v) A.settings.menuLanguage=v=="Türkçe" and "tr" or "en" end},
        toggle("Enable Zera UI","enabled"),
        {type="button",name="Edit HUD (Interactive Editor)",width="half",
            tooltip="Open Interactive Edit Mode to drag, snap, resize and customize every widget's fonts, sizes and colors live with full Save/Cancel.",
            func=function() A:BeginEdit() end},
        {type="button",name="Toggle HUD preview",width="half",
            tooltip="Show sample timers, stacks, buffs, sets and meters while configuring Zera UI.",
            func=function() A:Command("preview") end},
        {type="dropdown",name="Font family",vabKey="fontFace",choices=A:FontChoices(),
            tooltip="Global default HUD font. Widgets set to 'HUD font' inherit this choice.",
            getFunc=function() return A.settings.fontFace end,
            setFunc=function(v) A.settings.fontFace=v; A:ApplySettings(); refresh() end},
        {type="dropdown",name="Duration outline",vabKey="fontStyle",
            choices={"thick-outline","outline","thin-outline","normal","shadow","soft-shadow-thin","soft-shadow-thick"},
            tooltip="Global default text outline. Widgets set to 'HUD outline' inherit this choice.",
            getFunc=function() return A.settings.fontStyle end,
            setFunc=function(v) A.settings.fontStyle=v; A:ApplySettings() end},
        {type="description",text=function() return A.fontStatus or "" end},
        {type="button",name="Reset appearance to defaults",
            tooltip="Restore HUD colors, sizes, positioning and animations. Custom skill tracking rules remain intact.",
            warning="Tracking rules are preserved.",
            func=function() A:ResetAppearance(); updateAttributeLayoutChoices() end},
    }
    for _,section in ipairs(sections) do
        ordered[#ordered+1]=sectionHeader(section[1])
        ordered[#ordered+1]={type="description",text=section[2],vabSectionIntro=true}
        for _,item in ipairs(section[3]) do ordered[#ordered+1]=item end
    end
    ordered[#ordered+1]={type="divider"}
    ordered[#ordered+1]={type="description",vabFooter=true,
        text="Zera UI 1.1.6  ·  /zera  ·  /zeraset  ·  Visual sizing, fonts & colors live in Edit HUD."}
    ordered[#ordered+1]={type="button",name="Reload UI",func=function() ReloadUI() end,width="half"}
    local options=ordered

    ------------------------------------------------------------------------
    -- Menu conventions: defaults, main switches, dependency disabling, help.
    ------------------------------------------------------------------------
    local function eachControl(list,fn,parent)
        for _,o in ipairs(list) do fn(o,parent); if o.controls then eachControl(o.controls,fn,o) end end
    end
    eachControl(options,function(o)
        if o.vabKey and o.default==nil and A.DefaultSetting then
            local v=A:DefaultSetting(o.vabKey)
            if o.type=="colorpicker" and type(v)=="table" then o.default={r=v[1],g=v[2],b=v[3],a=v[4] or 1}
            elseif v~=nil then o.default=v end
        end
    end)

    local SUB_SWITCH={
        ["Animations & glows"]="animations",
        ["Set tracking & special mechanics"]="setCooldownEnabled",
        ["Off Balance tracker"]="offBalanceEnabled",
    }
    local function arrangeSubmenu(s)
        local key=SUB_SWITCH[s.name]
        if key then
            for i,o in ipairs(s.controls) do
                if o.vabKey==key then
                    table.remove(s.controls,i); o.vabMain=true
                    table.insert(s.controls,1,o); table.insert(s.controls,2,{type="divider"})
                    break
                end
            end
        end
    end
    eachControl(options,function(o) if o.type=="submenu" then arrangeSubmenu(o) end end)

    local function on(k)
        if k=="attrEnabled" then return A.settings.attrMode~="Off" end
        return A.settings[k]~=false
    end
    local NEEDS={
        darkenResource={"showUnavailable"},darkenCorpse={"showUnavailable"},darkenTarget={"showUnavailable"},
        pressFlash={"animations"},expiryGlow={"animations"},expiryLoop={"animations"},
        loopSeconds={"animations","expiryLoop"},stackLoop={"animations"},loopStacks={"animations","stackLoop"},
        togglePulse={"toggleGlow"},procPulse={"procHighlight"},
        castShowGCD={"showGCD"},castShowChannels={"showGCD"},castShowHardcasts={"showGCD"},
        nwWarning={"showNothingWasted"},nwWarnSeconds={"showNothingWasted","nwWarning"},
        offBalanceFlashSeconds={"offBalanceEnabled","offBalanceFlash"},
    }
    local PREFIX_NEEDS={
        {"attr","attrEnabled"},{"setCooldown","setCooldownEnabled"},{"offBalance","offBalanceEnabled"},
    }
    local NAME_NEEDS={
        ["Synergy disappearance"]={"showSynergy"},["Synergy key label"]={"showSynergy"},
        ["Multi-target timer expiration"]={"showTargets"},["Multi-target blacklist skill"]={"showTargets"},
        ["Hide target count for selected skill"]={"showTargets"},
        ["Gold loop on inactive bar"]={"animations"},["Replay sample glow animations"]={"animations"},
        ["Test set proc sound"]={"setCooldownEnabled"},["Test set ready sound"]={"setCooldownEnabled"},
        ["Layout"]={"attrEnabled"},
    }
    for _,k in ipairs({"showSingleTarget","showSingleGroupBuff","groupRecipientsOnly"}) do NEEDS[k]={"showTargets"} end
    local function needsFor(o)
        if o.vabMain then return nil end
        if o.vabKey then
            if NEEDS[o.vabKey] then return NEEDS[o.vabKey] end
            for _,rule in ipairs(PREFIX_NEEDS) do
                local prefix,parent=rule[1],rule[2]
                if o.vabKey~=parent and o.vabKey:sub(1,#prefix)==prefix and o.vabKey:sub(#prefix+1,#prefix+1):match("%u") then return {parent} end
            end
        end
        return o.name and NAME_NEEDS[o.name]
    end
    local function addDisabled(o,fn)
        local prev=o.disabled
        if prev==nil then o.disabled=fn
        elseif type(prev)=="function" then o.disabled=function() return prev() or fn() end
        else o.disabled=function() return prev or fn() end end
    end
    local SWITCH_PARENTS={animations=true,attrEnabled=true,showGCD=true,showSynergy=true,showTargets=true,
        setCooldownEnabled=true,offBalanceEnabled=true}
    eachControl(options,function(o)
        if o.type=="header" or o.type=="submenu" or o.type=="description" or o.type=="divider" then return end
        local keys=needsFor(o)
        if keys then
            addDisabled(o,function() for _,k in ipairs(keys) do if not on(k) then return true end end return false end)
            if not SWITCH_PARENTS[keys[#keys]] then o.vabChild=true end
        end
        if o.vabKey~="enabled" and o.name~="Language / Dil" and o.name~="Reload UI" then
            addDisabled(o,function() return not on("enabled") end)
        end
    end)

    -- Active tooltip catalog (zero dead entries).
    local help={}
    for key,en,trText in ([=[
Enable Zera UI	Enables the custom HUD and trackers. Off restores the original ESO controls where Zera UI owns them.	Zera UI savaş arayüzünü ve takipçilerini açar. Kapatınca Zera UI'ın kullandığı orijinal ESO kontrolleri geri bırakılır.
Soon warning (seconds)	At or below this remaining time, skill timers use the soon-warning color when warning colors are enabled.	Uyarı renkleri açıksa süre bu değere indiğinde yaklaşan bitiş rengi kullanılır.
Last warning (seconds)	At or below this remaining time, skill timers use the final-warning color when warning colors are enabled.	Uyarı renkleri açıksa süre bu değere indiğinde son bitiş rengi kullanılır.
Show decimals below (seconds)	Show tenths on ordinary skill timers at or below this threshold. 0 disables ordinary timer decimals. Passive badges always use whole seconds.	Normal yetenek sürelerinde bu eşikte ondalık gösterir. 0 normal sayaçların ondalığını kapatır. Pasif rozetleri her zaman tam saniyedir.
Gold cast / synergy animations	Master switch for the addon's gold cast, expiry and loop effects. Disabling it removes those visual alerts.	Eklentinin altın cast, bitiş ve döngü efektleri için ana anahtardır. Kapatınca bu görsel uyarılar kaybolur.
Gold loop warning (seconds)	Start the repeating gold border when a skill has at most this many seconds remaining.	Bir yeteneğin kalan süresi bu değere indiğinde tekrarlayan altın çerçeveyi başlatır.
Gold loop stack threshold	Start the gold stack warning at this stack count unless the skill has its own override.	Yetenek için ayrı eşik yoksa altın stack uyarısını bu sayıda başlatır.
Gold loop on inactive bar	Allow the repeating gold warning on the inactive weapon bar as well as the active one.	Tekrarlayan altın uyarıyı aktif çubukla birlikte pasif silah çubuğunda da gösterir.
Show inactive ultimate	Shows the other weapon bar's ultimate meter beside the active one.	Aktif ultimate yanında diğer silah çubuğunun ultimate göstergesini de açar.
Show ultimate costs	Shows ultimate skill costs near their meters.	Ultimate göstergelerinin yanında yetenek maliyetlerini gösterir.
Show potion / quickslot meter	Shows the quickslot item, count and its cooldown meter.	Hızlı yuvadaki eşyayı, miktarını ve bekleme süresi göstergesini açar.
Show instant skill global cooldown	Show the short global cooldown for instant skills in the cast bar.	Anlık yeteneklerin kısa global bekleme süresini cast çubuğunda gösterir.
Show cast-time abilities	Show the cast bar for skills with a non-instant cast time.	Anında kullanılmayan yeteneklerin cast süresini çubukta gösterir.
Show synergy alert	Display the synergy prompt when ESO reports an available synergy.	ESO kullanılabilir bir sinerji bildirdiğinde sinerji göstergesini açar.
Multi-target blacklist skill	Select a front/back skill or ultimate to include in the target-count blacklist below.	Alttaki hedef sayısı hariç listesinde ayarlanacak ön/arka çubuk yeteneğini veya ultiyi seç.
Pulse proc highlight	Animate the glow repeatedly while the tracked proc is active. This adds drawing work while visible.	Takip edilen proc aktifken parlamayı tekrarlar. Görünürken ek çizim işi oluşturur.
Nothing Wasted warning seconds	Start the Nothing Wasted decay warning this many seconds before its observed or inferred end.	Nothing Wasted bitiş uyarısını gözlenen veya hesaplanan bitişten bu kadar saniye önce başlatır.
Animation skill slot	Choose a currently slotted skill. Saved overrides follow its ability and Scribing combination, not the slot.	Slottaki yeteneği seç. Kaydedilen özel ayarlar slota değil yeteneğe ve Scribing kombinasyonuna bağlıdır.
Skill cast flash	Choose whether the selected skill uses the global cast-flash setting, forces it on, or turns it off.	Seçili yeteneğin kullanım parlamasında genel ayarı kullanmasını, açık veya kapalı olmasını seç.
Skill expiration flash	Choose whether the selected skill uses the global expiration flash, forces it on, or turns it off.	Seçili yeteneğin bitiş parlamasında genel ayarı kullanmasını, açık veya kapalı olmasını seç.
Skill expiration gold loop	Choose the selected skill's repeating gold expiration warning. Global follows the main animation settings.	Seçili yeteneğin tekrarlayan altın bitiş uyarısını seç. Genel ana animasyon ayarlarını izler.
Skill stack gold loop	Choose the selected skill's repeating gold stack warning. Global follows the main animation settings.	Seçili yeteneğin tekrarlayan altın stack uyarısını seç. Genel ana animasyon ayarlarını izler.
Skill loop on inactive bar	Choose whether the selected skill's gold loop can appear on the inactive weapon bar.	Seçili yeteneğin altın döngüsünün pasif silah çubuğunda görünüp görünmeyeceğini seç.
Enable set cooldown tracker	Enable the separate widget for supported equipped set effects and cooldowns.	Desteklenen kuşanılmış set efektleri ve bekleme süreleri için ayrı göstergeyi açar.
Show outside combat	Keep the set widget visible when you are not in combat.	Savaş dışında da set göstergesini görünür tutar.
Show ready set icons	Include supported equipped sets when they are ready and no timed effect is active.	Desteklenen kuşanılmış setlerin aktif süreleri yokken hazır ikonlarını da gösterir.
Show off-bar set icons	Include sets that are equipped only on the currently inactive weapon bar.	Yalnız pasif silah çubuğunda tamamlanan setlerin ikonlarını da gösterir.
Show cooldown during active effects	Show a set's cooldown alongside its active effect when both values are available.	İkisi de mevcutsa setin aktif etkisiyle birlikte cooldown süresini gösterir.
Set filter mode	Choose whether to show all equipped sets, hide selected sets or show only selected sets.	Tüm kuşanılmış setleri gösterme, seçilenleri gizleme veya yalnız seçilenleri gösterme arasında seçim yap.
Select set	Choose the set edited by the filter, color, size and sound controls below.	Aşağıdaki filtre, renk, boyut ve ses ayarlarında düzenlenecek seti seç.
Add selected set to filter list	Add or remove the selected set from the list used by the chosen filter mode.	Seçili seti, seçilen filtre modunun kullandığı listeye ekler veya listeden çıkarır.
Clear set filter list	Remove all sets from the filter list. Individual set overrides are not removed.	Filtre listesindeki tüm setleri kaldırır. Setlere özel diğer ayarlar silinmez.
Reset selected set overrides	Remove size, color and sound overrides for the selected set; global settings apply again.	Seçili setin boyut, renk ve ses özel ayarlarını siler; genel ayarlar geri kullanılır.
Z'en: focus single boss	For Z'en, focus its damage-over-time tracking on a single identified boss when possible.	Z'en için mümkün olduğunda tek bir belirlenmiş boss üzerindeki hasar-zamanla etkilerine odaklanır.
Roaring Opportunist: predicted duration	Show the predicted Roaring Opportunist buff duration when supported information is available.	Desteklenen bilgiler mevcutsa tahmini Roaring Opportunist buff süresini gösterir.
Roaring Opportunist: affected recipients	Show observed affected-recipient counts for Roaring Opportunist when available.	Bilgi mevcutsa Roaring Opportunist'ten etkilenen gözlenen alıcı sayısını gösterir.
Pearls / Esoteric: resource percentage	Show the relevant resource percentage for supported Pearls / Esoteric indicators.	Desteklenen Pearls / Esoteric göstergelerinde ilgili kaynak yüzdesini gösterir.
Pearls / Esoteric: proc count	Show the observed proc count for supported Pearls / Esoteric indicators.	Desteklenen Pearls / Esoteric göstergelerinde gözlenen proc sayısını gösterir.
Show effects outside combat	Keep enabled custom buff and debuff grids visible outside combat.	Etkin özel buff ve debuff gruplarını savaş dışında da görünür tutar.
Enable Off Balance icon	Show the independent Off Balance widget for the current hostile target.	Mevcut düşman hedef için bağımsız Off Balance göstergesini açar.
Exclude Off Balance from target grid	Keep Off Balance in its separate widget instead of duplicating it in the target effects grid.	Off Balance'ı hedef efekt grubunda tekrarlamak yerine ayrı göstergede tutar.
Show when Off Balance is ready	Show the ready state even while no Off Balance or immunity timer is active.	Off Balance veya bağışıklık sayacı aktif değilken de hazır durumunu gösterir.
Off Balance expiry flash	Flash the Off Balance icon as its active timer approaches expiration.	Aktif Off Balance süresi bitmeye yaklaşınca ikonu parlatır.
Off Balance flash threshold (seconds)	Start the optional Off Balance expiration flash at this remaining time.	İsteğe bağlı Off Balance bitiş parlamasını bu kalan sürede başlatır.
Effect area sort order	Choose shortest remaining duration first or ESO's reported order.	En kısa süreyi önce veya ESO'nun bildirdiği sırayı seçer.
]=]):gmatch("([^\n\t]+)\t([^\n\t]+)\t([^\n]+)") do help[key]={en,trText} end

    local function fillHelp(controls)
        for _,option in ipairs(controls) do
            if option.controls then fillHelp(option.controls)
            else
                local kind=option.type
                if kind=="checkbox" or kind=="slider" or kind=="dropdown" or kind=="colorpicker" or kind=="editbox" or kind=="button" then
                    if not option.tooltip and type(option.name)=="string" then
                        local entry=help[option.name]
                        if entry then option.tooltip=turkish and entry[2] or entry[1]
                        else
                            local display=tr(option.name)
                            if kind=="slider" then option.tooltip=turkish and (display.." değerini ayarlar.") or ("Adjusts "..display..".")
                            elseif kind=="colorpicker" then option.tooltip=turkish and (display.." rengini seçer.") or ("Choose the color for "..display..".")
                            elseif kind=="checkbox" then option.tooltip=turkish and (display.." seçeneğini açar veya kapatır.") or ("Turns "..display.." on or off.")
                            elseif kind=="dropdown" then option.tooltip=turkish and (display.." için bir seçenek belirler.") or ("Choose an option for "..display..".")
                            elseif kind=="editbox" then option.tooltip=turkish and (display.." için kullanılacak değeri gir.") or ("Enter the value used for "..display..".")
                            elseif kind=="button" then option.tooltip=turkish and (display.." işlemini uygular.") or ("Run the "..display.." action.") end
                        end
                    end
                end
            end
        end
    end
    fillHelp(options)

    local titleRefs={}
    if turkish then
        local function localize(controls)
            for _,option in ipairs(controls) do
                for _,field in ipairs({"name","tooltip","text","warning"}) do
                    local original=option[field]
                    if type(original)=="function" then option[field]=function(...) return tr(original(...)) end
                    elseif type(original)=="string" then option[field]=tr(original) end
                end
                if option.type=="header" or option.type=="submenu" then
                    local title=option.name
                    if type(title)=="string" then option.name=turkishTitle(title)
                    elseif type(title)=="function" then option.name=function(...) return turkishTitle(title(...)) end end
                    option.reference=option.reference or name.."TRTitle"..(#titleRefs+1)
                    titleRefs[#titleRefs+1]=option.reference
                end
                if option.type=="dropdown" and option~=setChoiceOption then
                    if option.choicesValues then
                        for i,label in ipairs(option.choices) do option.choices[i]=tr(label) end
                    else translateChoices(option,option.choices) end
                end
                if option.controls then localize(option.controls) end
            end
        end
        localize(options)
    end
    for _,option in ipairs(options) do
        if option.vabSectionIntro then option.text="|cBFA980"..option.text.."|r" end
    end
    local function caps(v) return turkish and v or v:upper() end
    local function paint(o)
        if type(o.name)~="string" then return end
        if o.vabRole=="section" then
            local num,title=o.name:match("^(%d%d)%s*|%s*(.+)$")
            if num then
                local icon=o.vabIcon and string.format("|t24:24:%s|t ",o.vabIcon) or ""
                o.name=string.format("%s|cB98A3C%s|r  |cF2CF7A%s|r",icon,num,caps(title))
            end
        elseif o.type=="submenu" then o.name="|cEBD6A0"..o.name.."|r"
        elseif o.type=="header" then o.name="|cCDB78A"..caps(o.name).."|r"
        elseif o.vabMain or o.vabKey=="enabled" then o.name="|c9EDDA6"..o.name.."|r"
        elseif o.vabChild then o.name="   |c8F7A4E\226\128\148|r  "..o.name end
    end
    eachControl(options,paint)
    for _,option in ipairs(options) do
        if option.vabFooter then option.text="|cA8987A"..option.text.."|r" end
    end

    pcall(loadVisual)
    LAM:RegisterOptionControls(name,options)
    A.settingsRegistered=true
    if CALLBACK_MANAGER then
        if turkish then
            CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated",function(created)
                if created~=panel or not MODIFY_TEXT_TYPE_NONE then return end
                for _,ref in ipairs(titleRefs) do
                    local control=_G[ref]
                    local label=control and (control.header or control.label)
                    if label and label.SetModifyTextType then
                        label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
                        if control.UpdateValue then control:UpdateValue() end
                    end
                end
            end)
        end
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened",function(opened)
            if opened==panel then
                A.setCooldowns:MenuOpened(true); A.effectHUD:MenuOpened(true)
                loadVisual(); refreshSetChoices(); listUi.update(); updateAttributeLayoutChoices()
            end
        end)
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed",function(closed)
            if closed==panel then
                A.setCooldowns:MenuOpened(false); A.effectHUD:MenuOpened(false)
                if A.editing then A.editPreview=false
                elseif A.preview then A:Command("preview") end
            end
        end)
    end
    return true
end
