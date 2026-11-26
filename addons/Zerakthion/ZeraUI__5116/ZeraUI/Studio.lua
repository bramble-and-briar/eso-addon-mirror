-- Skill tracking window. Flat panels in the Zera palette: pick a skill, see
-- in plain words what its timers show, optionally set your own, and find
-- effect IDs by casting. Built on first open; nothing runs in normal play.
function ZeraUIAttachStudio(A)
    local WM=WINDOW_MANAGER
    local T=ZeraUITracker
    local PRIMARY=HOTBAR_CATEGORY_PRIMARY or 0
    local BACKUP=HOTBAR_CATEGORY_BACKUP or 1
    local WEREWOLF=HOTBAR_CATEGORY_WEREWOLF
    -- One compact screen: the sections themselves replace the old step cards.
    local W,H=1100,770
    local ROWS=6
    local ROW_H=34
    -- Palette (pale cream; text is dark ink)
    local CREAM={.906,.875,.800,1}; local CARD={.941,.914,.855,1}; local FIELD={.886,.847,.761,1}
    local INK={.086,.086,.086,1}; local INK_SOFT={.33,.32,.30,1}
    local YELLOW={.953,.800,.310,1}; local TEAL={.373,.776,.682,1}; local CORAL={.871,.353,.447,1}; local BLUE={.365,.604,.827,1}
    local LINKED={.835,.953,.910,1}; local WARN_FILL={.980,.878,.855,1}
    -- Semantic text colors used by the logic below
    local TEXT=INK; local MUTED=INK_SOFT; local GREEN={.067,.525,.369,1}; local CYAN={.13,.40,.66,1}; local AMBER={.70,.36,.04,1}
    local TIP_GOLD={.95,.78,.36,1}
    local function tr(text) return A.settings and A.settings.menuLanguage=="tr" and ZeraUITranslate and ZeraUITranslate(text) or text end
    local function fmt(text,...) return string.format(tr(text),...) end
    -- Rajdhani ships with Zera UI (Fonts.xml); ESO's bold font if it is missing.
    local RAJ_SEMI,RAJ_BOLD="ZeraUI/fonts/Rajdhani-SemiBold-OL.slug","ZeraUI/fonts/Rajdhani-Bold-OL.slug"
    local useRajdhani
    local function font(size,bold)
        if useRajdhani then return string.format("%s|%d",bold and RAJ_BOLD or RAJ_SEMI,math.floor(size*1.12+.5)) end
        return string.format("$(BOLD_FONT)|$(KB_%d)",size)
    end
    local function nudge(size) return useRajdhani and math.floor(.22*size*1.12+.5) or 0 end
    local function rgba(c) return c[1],c[2],c[3],c[4] or 1 end
    local POSITIONS={"Middle","Lower left","Lower right"}
    local SCOPES={self="On you",group="Group",enemy="Enemy",other="Other"}
    local POLICIES={nil,"first","last"}
    local POLICY_NAMES={first="Soonest to expire",last="Latest to expire",target="Follow my target"}
    local S={cat=PRIMARY,num=1,rows={},ruleRows={},scroll=0,ruleScroll=0,view="finder",step=1,bars={},barLabels={}}
    A.studio=S

    ------------------------------------------------------------------
    -- Building blocks
    ------------------------------------------------------------------
    local function fill(parent,x,y,w,h,color,edge,thickness,level)
        local b=WM:CreateControl(nil,parent,CT_BACKDROP)
        b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
        b:SetCenterColor(rgba(color or CARD))
        b:SetEdgeColor(rgba(edge or INK)); b:SetEdgeTexture("",1,1,thickness or 2)
        if b.SetPixelRoundingEnabled then b:SetPixelRoundingEnabled(true) end
        b:SetDrawLayer(DL_BACKGROUND); b:SetDrawLevel(level or 1)
        return b
    end
    -- A panel with its flat ink shadow (offset, no blur).
    local function block(parent,x,y,w,h,color,shadow,level)
        local sh
        if shadow and shadow>0 then sh=fill(parent,x+shadow,y+shadow,w,h,INK,INK,1,(level or 1)) end
        local b=fill(parent,x,y,w,h,color,INK,2,(level or 1)+1)
        b.shadow=sh
        return b
    end
    local function label(parent,value,x,y,w,size,color,align,h,bold)
        local l=WM:CreateControl(nil,parent,CT_LABEL)
        l:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y+nudge(size or 15)); l:SetDimensions(w,h or (size+8))
        l:SetFont(font(size or 15,bold)); l:SetColor(rgba(color or TEXT))
        l:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT); l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if not h then l:SetMaxLineCount(1) end
        if TEXT_WRAP_MODE_ELLIPSIS and l.SetWrapMode then l:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
        l:SetDrawLayer(DL_TEXT or DL_CONTROLS)
        l:SetText(value or "")
        return l
    end
    local function hoverTip(control,fn)
        control:SetMouseEnabled(true)
        local enter=control:GetHandler("OnMouseEnter")
        local exit=control:GetHandler("OnMouseExit")
        control:SetHandler("OnMouseEnter",function(self,...)
            if enter then enter(self,...) end
            if not InformationTooltip or not InitializeTooltip then return end
            local title,body=fn()
            if not title then return end
            InitializeTooltip(InformationTooltip,self,BOTTOM,0,-6,TOP)
            InformationTooltip:AddLine(title,"ZoFontWinH4",rgba(TIP_GOLD))
            if body and body~="" then InformationTooltip:AddLine(body,"ZoFontGame",1,1,1) end
        end)
        control:SetHandler("OnMouseExit",function(self,...)
            if exit then exit(self,...) end
            if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip) end
        end)
    end
    -- Children inherit the parent's draw layer: an icon inside an opaque
    -- backdrop must be lifted above it explicitly or it stays hidden.
    local function onTop(control,level)
        control:SetDrawLayer(DL_CONTROLS or 1); control:SetDrawLevel(level or 10)
        return control
    end
    local function textOn(color) return (color==CORAL or color==BLUE) and {1,1,1,1} or INK end
    -- Neo button: colored face, 2 px ink edge and a 3 px flat shadow. The
    -- face sinks onto its shadow while pressed. accent = face color.
    local function button(parent,value,x,y,w,h,fn,accent,small)
        h=h or 30
        local b=WM:CreateControl(nil,parent,CT_BUTTON)
        b:SetDimensions(w,h); b:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y)
        b:SetMouseEnabled(true)
        local sh=small and 2 or 3
        local shadow=WM:CreateControl(nil,b,CT_BACKDROP)
        shadow:SetDimensions(w,h); shadow:SetAnchor(TOPLEFT,b,TOPLEFT,sh,sh)
        shadow:SetCenterColor(rgba(INK)); shadow:SetEdgeColor(rgba(INK)); shadow:SetEdgeTexture("",1,1,1)
        shadow:SetDrawLayer(DL_BACKGROUND); shadow:SetDrawLevel(2)
        local face=WM:CreateControl(nil,b,CT_BACKDROP)
        face:SetDimensions(w,h); face:SetAnchor(TOPLEFT,b,TOPLEFT,0,0)
        face:SetEdgeColor(rgba(INK)); face:SetEdgeTexture("",1,1,2)
        face:SetDrawLayer(DL_BACKGROUND); face:SetDrawLevel(3)
        local size=small and 13 or 15
        local text=label(face,value,4,0,w-8,size,INK,TEXT_ALIGN_CENTER,nil,true)
        text:ClearAnchors(); text:SetAnchor(TOPLEFT,face,TOPLEFT,4,nudge(size)); text:SetAnchor(BOTTOMRIGHT,face,BOTTOMRIGHT,-4,nudge(size))
        b.bg,b.face,b.text,b.shadow=face,face,text,shadow
        local function paint(hover)
            local c=b.accent or CARD
            local k=hover and 1.06 or 1
            face:SetCenterColor(math.min(1,c[1]*k),math.min(1,c[2]*k),math.min(1,c[3]*k),1)
            text:SetColor(rgba(b.textColor or textOn(b.accent)))
        end
        local function press(down)
            face:ClearAnchors(); face:SetAnchor(TOPLEFT,b,TOPLEFT,down and sh or 0,down and sh or 0)
        end
        b:SetHandler("OnMouseEnter",function() paint(true) end)
        b:SetHandler("OnMouseExit",function() paint(false); press(false) end)
        b:SetHandler("OnMouseDown",function() press(true) end)
        b:SetHandler("OnMouseUp",function(_,mouse,inside)
            press(false)
            if inside and (not MOUSE_BUTTON_INDEX_LEFT or mouse==MOUSE_BUTTON_INDEX_LEFT) then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
                fn(b)
            end
        end)
        function b:SetLabel(v) text:SetText(v or "") end
        function b:SetAccent(c) b.accent=c; paint(false) end
        function b:SetTextColor(c) b.textColor=c; paint(false) end
        b.accent=accent; paint(false)
        return b
    end
    -- Text input on ESO's own edit template, inside a sunken ink-edged field.
    local function input(parent,x,y,w,chars)
        local bg=fill(parent,x,y,w,30,FIELD,INK,2,2)
        local box
        if WM.CreateControlFromVirtual then
            local ok,created=pcall(WM.CreateControlFromVirtual,WM,nil,bg,"ZO_DefaultEditForBackdrop")
            if ok then box=created end
        end
        if not box then
            box=WM:CreateControl(nil,bg,CT_EDITBOX)
            box:SetAnchor(TOPLEFT,bg,TOPLEFT,7,5); box:SetAnchor(BOTTOMRIGHT,bg,BOTTOMRIGHT,-7,-5)
        end
        box:SetFont(font(16)); box:SetMaxInputChars(chars or 10)
        box:SetDrawLayer(DL_CONTROLS or 1); box:SetDrawLevel(10)
        box:SetMouseEnabled(true)
        box:SetHandler("OnMouseDown",function(self) if not self:HasFocus() then self:TakeFocus() end end)
        if box.SetColor then box:SetColor(rgba(INK)) end
        box:SetHandler("OnEnter",function(self) self:LoseFocus() end)
        box:SetHandler("OnEscape",function(self) self:LoseFocus() end)
        box:SetHandler("OnFocusGained",function() bg:SetEdgeTexture("",1,1,3); bg:SetCenterColor(rgba(CARD)) end)
        box:SetHandler("OnFocusLost",function() bg:SetEdgeTexture("",1,1,2); bg:SetCenterColor(rgba(FIELD)) end)
        box.bg=bg
        return box
    end
    -- White-ish card with a 4 px shadow and a bold title.
    local function card(parent,title,x,y,w,h)
        local c=block(parent,x,y,w,h,CARD,4,1)
        if title and title~="" then c.title=label(c,title,16,12,w-32,20,INK,nil,nil,true) end
        return c
    end
    -- Small ink "(?)" mark for column headers.
    local function qmark(parent,x,y)
        local q=fill(parent,x,y,16,16,YELLOW,INK,2,3)
        label(q,"?",0,-3,16,11,INK,TEXT_ALIGN_CENTER,nil,true)
        return q
    end

    ------------------------------------------------------------------
    -- Data helpers
    ------------------------------------------------------------------
    local function slotIndex(num) return num<=5 and num+2 or 8 end
    local function barName(cat)
        if WEREWOLF~=nil and cat==WEREWOLF then return "Werewolf" end
        return cat==PRIMARY and "Front" or "Back"
    end
    local function syncStudioBars()
        local active=GetActiveHotbarCategory and GetActiveHotbarCategory() or A.active
        local wolf=WEREWOLF~=nil and active==WEREWOLF
        if wolf==S.werewolf then return false end
        if wolf then
            S.normalCat,S.normalNum=S.cat,S.num
            S.cat,S.num=WEREWOLF,S.wolfNum or 1
        elseif S.werewolf then
            S.wolfNum=S.num
            S.cat,S.num=S.normalCat or PRIMARY,S.normalNum or 1
        end
        S.werewolf=wolf
        for row,label in ipairs(S.barLabels) do
            label:SetHidden(wolf and row==2)
            label:SetText(tr(barName(row==1 and (wolf and WEREWOLF or PRIMARY) or BACKUP)))
        end
        for _,b in ipairs(S.bars) do
            b.cat=b.row==1 and (wolf and WEREWOLF or PRIMARY) or BACKUP
            b.hidden=wolf and b.row==2
            b.frame:SetHidden(b.hidden); b.shadow:SetHidden(b.hidden)
        end
        return true
    end
    local function selected() return T.IdentifySlot(slotIndex(S.num),S.cat) end
    local function slotState()
        local row=A.categories and (A.categories[1]==S.cat and 1 or A.categories[2]==S.cat and 2) or nil
        return row and A.slots[row] and A.slots[row][S.num<=5 and S.num or 6] or nil
    end
    local function effectName(id)
        local n=GetAbilityName and GetAbilityName(id) or ""
        n=type(n)=="string" and n:gsub("%^.*$","") or ""
        return n
    end
    local function seconds(ms) return string.format("%gs",math.floor(ms/100+.5)/10) end
    -- Shown in step 3 and step 4, so a note is never on a hidden pane.
    local function message(text,color)
        for _,l in ipairs(S.messages or {}) do l:SetText(text or ""); l:SetColor(rgba(color or GREEN)) end
    end
    local function isOff(r) return not r or r.mode=="off" end

    -- One or two plain sentences: what the player sees on this skill now.
    local function describe(key,id)
        if not key then return tr("No skill in this slot."),"" end
        local custom=A.tracker.rules[key] or (id and A.tracker.rules["a:"..id])
        if custom then
            local parts={}
            for i,r in ipairs(custom) do
                if not isOff(r) then
                    local name=r.mode=="cast" and tr("Fake effect") or (effectName(r.effect)~="" and effectName(r.effect) or "#"..r.effect)
                    parts[#parts+1]=string.format("%s: %s%s",tr(POSITIONS[i]),name,r.mode=="cast" and string.format(" %gs",r.duration) or string.format(" (%d)",r.effect))
                end
            end
            return tr("Your own timers"),table.concat(parts,"  ·  ")
        end
        local state=slotState()
        local chain=state and state.abilityKey==key and state.chain or A.tracker:ChainSpec(key,id)
        if chain and chain.phases and #chain.phases>0 then
            local head=chain.trigger=="contingency" and tr("Built-in: starts when the rune triggers") or tr("Built-in phase timers")
            local function phase(i)
                local name=chain.names and chain.names[i] or ""
                return (name~="" and tr(name).." " or "")..seconds(chain.phases[i])
            end
            local body=fmt("Middle: %s",phase(1))
            if chain.phases[2] then body=body.."  ·  "..fmt("Lower left: %s",phase(2)) end
            if chain.phases[3] then body=body.."  ·  "..fmt("then %s",phase(3)) end
            if chain.phases[2] then
                body=body.."\n"..tr(chain.trigger=="contingency" and "When the middle one ends, the next one moves to the middle. No effect ID needed: the scripts on the skill decide."
                    or "When the middle one ends, the next one moves to the middle. No effect ID needed: both start when you cast.")
            end
            return head,body
        end
        local list=A.tracker:RulesFor(key,id)
        if list and list[1] then
            return tr("Built-in effect tracking"),fmt("Middle follows %s (%d).",effectName(list[1].effect),list[1].effect)
        end
        return tr("The game's own skill timer"),tr("Nothing to set up unless the timer is wrong.")
    end
    local LOCKS={
        nw="Nothing Wasted is shown on this Siphon (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.",
        arcanist="The Arcanist mastery timer is shown on this skill (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.",
        vampire="The Strike from the Shadows timer is shown on this skill (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.",
        landslide="Landslide is shown on this Whip (04 Tracking & class mechanics > Class mechanics), so its timers can't be changed here.",
    }
    local MIDDLE_REASON={
        whip="The middle timer can't be used for this skill: it always shows Off Balance / its immunity and the Power Lash charges.",
        exhausting="The middle timer can't be used for this skill: it shows the channel while you cast it.",
    }
    local function currentRules(key,id)
        if not key then return {},false end
        local custom=A.tracker.rules[key] or (id and A.tracker.rules["a:"..id])
        if custom then return custom,true end
        return A.tracker:RulesFor(key,id) or {},false
    end

    -- Live name of the typed effect ID under its box.
    local function paintName(i)
        local row=S.timerRows[i]
        local id=tonumber(row.effect:GetText())
        if not id then
            row.nameLabel:SetText(row.fixed and tr("no effect ID needed") or "")
            row.nameLabel:SetColor(rgba(MUTED)); return
        end
        local name=effectName(id)
        if name~="" then row.nameLabel:SetText(name); row.nameLabel:SetColor(rgba(GREEN))
        else row.nameLabel:SetText(tr("unknown ID")); row.nameLabel:SetColor(1,.55,.4,1) end
    end
    local function paintRow(i)
        local row=S.timerRows[i]
        local fixed=row.fixed
        -- Segmented "What it counts": the chosen half is ink with yellow text.
        row.follow:SetAccent(not fixed and INK or CARD); row.follow:SetTextColor(not fixed and YELLOW or INK)
        row.fake:SetAccent(fixed and INK or CARD); row.fake:SetTextColor(fixed and YELLOW or INK)
        -- The Seconds box only exists for a fake effect.
        row.seconds.bg:SetHidden(not fixed)
        row.noSeconds:SetHidden(fixed)
        if row.promote then
            local on=S.promote==i
            row.promote:SetCenterColor(rgba(on and TEAL or CARD))
            row.promote.knob:ClearAnchors()
            row.promote.knob:SetAnchor(TOPLEFT,row.promote,TOPLEFT,on and 20 or 4,4)
        end
        paintName(i)
    end
    local function paintPromote() for i=2,3 do paintRow(i) end end
    local function paintBar()
        for _,b in ipairs(S.bars) do
            local on=not b.hidden and b.cat==S.cat and b.num==S.num
            b.frame:SetEdgeTexture("",1,1,on and 3 or 2)
            b.frame:SetEdgeColor(rgba(on and CORAL or INK))
            if b.under then b.under:SetHidden(not on) end
        end
    end
    local function loadSkill()
        local key,id=selected()
        S.key,S.id=key,id
        local index=slotIndex(S.num)
        local name=id and GetSlotName and GetSlotName(index,S.cat) or ""
        local icon=id and GetSlotTexture and GetSlotTexture(index,S.cat) or ""
        S.icon:SetTexture(icon~="" and icon or "/esoui/art/icons/icon_missing.dds")
        S.icon:SetHidden(not id)
        S.name:SetText(id and (name~="" and zo_strformat and zo_strformat("<<1>>",name) or name) or tr("Empty slot"))
        S.info:SetText(id and fmt("%s %s  ·  Ability ID %d",tr(barName(S.cat)),tostring(S.num),id) or "")
        local head,body=describe(key,id)
        S.sourceHead:SetText(head); S.sourceBody:SetText(body)
        local list,custom=currentRules(key,id)
        local state=slotState()
        local bound=state and state.abilityKey==key
        local chain=not custom and (bound and state.chain or A.tracker:ChainSpec(key,id)) or nil
        S.promote=nil
        S.loaded={custom=custom}
        for i=1,3 do
            local r=list[i]; if isOff(r) then r=nil end
            local row=S.timerRows[i]
            row.effect:SetText(r and r.mode~="cast" and tostring(r.effect) or (r and r.effect~=id and tostring(r.effect)) or "")
            row.seconds:SetText(r and r.duration and r.duration>0 and string.format("%g",r.duration) or "")
            row.fixed=r and r.mode=="cast" or false
            if r and r.promote and i>=2 then S.promote=i end
            -- Built-in phases have no IDs; show their script name in grey.
            local hint=""
            if chain and chain.phases and chain.phases[i] and i<=2 then
                local phaseName=chain.names and chain.names[i] or ""
                hint=(phaseName~="" and tr(phaseName) or tr("Built-in")).." · "..seconds(chain.phases[i])
            end
            if row.effect.SetDefaultText then row.effect:SetDefaultText(hint) end
            paintRow(i)
            -- What was loaded, so an unchanged row keeps its full rule.
            S.loaded[i]={effect=row.effect:GetText(),seconds=row.seconds:GetText(),fixed=row.fixed,rule=r}
        end
        S.loaded.promote=S.promote
        local flag=custom and tr("saved") or ((list[1] or chain) and tr("built-in values shown") or "")
        S.customFlag:SetText(flag); S.customTag:SetHidden(flag=="")
        if S.customTag.SetWidth then
            local width=S.customFlag.GetTextWidth and S.customFlag:GetTextWidth() or 80
            S.customTag:SetWidth(math.max(40,math.min(220,(tonumber(width) or 80)+18)))
        end
        S.customTag:SetCenterColor(rgba(custom and TEAL or FIELD))
        local middle=bound and A:MiddleBlocked(state) or nil
        S.middleReason=middle
        S.middleBlock:SetHidden(not middle)
        S.middleText:SetText(middle and tr(MIDDLE_REASON[middle]) or "")
        local lock=bound and A:TrackingLock(state) or nil
        S.lock:SetHidden(not lock)
        S.lockText:SetText(lock and (tr(LOCKS[lock]).."\n"..tr("Turn that option off to use your own timers. Saved timers are preserved while the feature takes priority.")) or "")
        local proc=key and A.tracker.procRules[key]
        S.proc:SetText(type(proc)=="number" and tostring(proc) or "")
        S.procAuto:SetAccent(proc==nil and TEAL or nil)
        S.procOff:SetAccent(proc==false and TEAL or nil)
        local p=key and A.settings.trackingPolicies[key]
        local mode=p and p.timer
        S.policy:SetLabel(tr(POLICY_NAMES[mode] or (A.settings.followTargetTimers~=false and "Follow my target" or "Default")))
        S.external:SetLabel(tr(p and p.external and "ON: also from other players" or "OFF: only your own"))
        -- Header chip: the selected skill is always in view.
        S.chipIcon:SetTexture(icon~="" and icon or "/esoui/art/icons/icon_missing.dds")
        S.chipText:SetText(id and string.format("%s · %s %d",(name~="" and zo_strformat and zo_strformat("<<1>>",name) or name),tr(barName(S.cat)),S.num) or tr("Empty slot"))
        paintBar()
        S.scroll=0
        A:RefreshStudioResults()
    end
    function A:StudioSelect(cat,num) S.cat,S.num=cat,math.max(1,math.min(5,num or 1)); S.focus=nil; message(""); loadSkill() end
    local function refreshBar()
        local changed=syncStudioBars()
        for _,b in ipairs(S.bars) do
            if not b.hidden then
                local icon=GetSlotTexture and GetSlotTexture(slotIndex(b.num),b.cat) or ""
                local id=GetSlotBoundId and GetSlotBoundId(slotIndex(b.num),b.cat) or 0
                b.icon:SetTexture(icon~="" and icon or "/esoui/art/actionbar/abilityframe64_up.dds")
                b.icon:SetAlpha(id and id>0 and 1 or .25)
                if b.nameLabel then
                    local name=id and id>0 and GetSlotName and GetSlotName(slotIndex(b.num),b.cat) or ""
                    b.nameLabel:SetText(name~="" and (zo_strformat and zo_strformat("<<1>>",name) or name) or tr("Empty slot"))
                end
            end
        end
        return changed
    end

    ------------------------------------------------------------------
    -- Saved rules: every skill with own timers, proc or target settings,
    -- also skills that are no longer on the bars.
    ------------------------------------------------------------------
    local function keyInfo(key)
        local id=tonumber(key:match("^a:(%d+)$"))
        local crafted=tonumber(key:match("^c:(%d+):"))
        local name,icon="",""
        if crafted then
            local base=GetAbilityIdForCraftedAbilityId and GetAbilityIdForCraftedAbilityId(crafted)
            name=GetCraftedAbilityDisplayName and GetCraftedAbilityDisplayName(crafted) or ""
            local scripts={}
            for sid in key:gmatch(":(%d+)") do scripts[#scripts+1]=tonumber(sid) end
            local names={}
            for k=2,4 do
                local n=scripts[k] and scripts[k]>0 and GetCraftedAbilityScriptDisplayName and GetCraftedAbilityScriptDisplayName(scripts[k]) or ""
                if n~="" then names[#names+1]=n end
            end
            if #names>0 then name=name.." ("..table.concat(names," / ")..")" end
            icon=base and GetAbilityIcon and GetAbilityIcon(base) or ""
        elseif id then
            name=effectName(id); icon=GetAbilityIcon and GetAbilityIcon(id) or ""
        end
        if name=="" then name=key end
        return name,icon
    end
    local function onBar(key)
        for r=1,2 do for i=1,5 do local s=A.slots[r] and A.slots[r][i]; if s and s.abilityKey==key then return true end end end
        return false
    end
    local function savedKeys()
        local keys,seen={},{}
        local function add(key) if type(key)=="string" and not seen[key] then seen[key]=true; keys[#keys+1]=key end end
        for key in pairs(A.settings.tracking or {}) do add(key) end
        for key in pairs(A.settings.procRules or {}) do add(key) end
        for key in pairs(A.settings.trackingPolicies or {}) do add(key) end
        table.sort(keys)
        return keys
    end
    local function ruleSummary(key)
        local parts={}
        local list=A.settings.tracking and A.settings.tracking[key]
        if type(list)=="table" then
            local n=0
            for _,r in ipairs(list) do if not isOff(r) then n=n+1 end end
            if n>0 then parts[#parts+1]=fmt("%d timer(s)",n) end
        end
        local proc=A.settings.procRules and A.settings.procRules[key]
        if proc~=nil then parts[#parts+1]=tr(proc==false and "proc off" or "own proc") end
        if A.settings.trackingPolicies and A.settings.trackingPolicies[key] then parts[#parts+1]=tr("target option") end
        return table.concat(parts," · ")
    end
    function A:RefreshStudioRules()
        if not S.window or S.window:IsHidden() then return end
        local keys=savedKeys()
        S.ruleScroll=math.max(0,math.min(S.ruleScroll,math.max(0,#keys-ROWS)))
        for i=1,ROWS do
            local key=keys[i+S.ruleScroll]; local row=S.ruleRows[i]
            row.key=key
            row.p:SetHidden(not key)
            if key then
                local name,icon=keyInfo(key)
                row.icon:SetTexture(icon~="" and icon or "/esoui/art/icons/icon_missing.dds")
                row.name:SetText(zo_strformat and zo_strformat("<<1>>",name) or name)
                local here=onBar(key)
                row.meta:SetText(ruleSummary(key).."  ·  "..tr(here and "on your bar" or "not on your bars"))
                row.meta:SetColor(rgba(here and GREEN or MUTED))
            end
        end
        S.rulesEmpty:SetHidden(#keys>0)
        S.ruleTab:SetLabel(fmt("My saved rules (%d)",#keys))
        S.rulesInfo:SetText(#keys>ROWS and string.format("%d–%d / %d",S.ruleScroll+1,math.min(#keys,S.ruleScroll+ROWS),#keys) or "")
        if S.rulesBar then S.rulesBar:Update(S.ruleScroll,#keys) end
    end
    local function removeSaved(key)
        if not key then return end
        A.tracker:ClearRule(key)
        if A.settings.procRules then A.settings.procRules[key]=nil end
        if A.settings.trackingPolicies then A.settings.trackingPolicies[key]=nil end
        A:ApplySettings(); A:RefreshSlots()
        if CALLBACK_MANAGER and A.settingsPanel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel",A.settingsPanel) end
        if key==S.key then loadSkill() end
        A:RefreshStudioRules()
        message(tr("Rule removed; built-in tracking is back for that skill."))
    end
    local function showView(view)
        S.view=view
        S.finderView:SetHidden(view~="finder")
        S.rulesView:SetHidden(view~="rules")
        S.finderTab:SetAccent(view=="finder" and YELLOW or nil)
        S.ruleTab:SetAccent(view=="rules" and YELLOW or nil)
        if view~="rules" then A:RefreshStudioResults() end
        A:RefreshStudioRules()
    end

    function A:RefreshStudioResults()
        if not S.window or S.window:IsHidden() then return end
        local f=self.finder
        local list=f:List(S.key,false)
        S.list=list
        local maxScroll=math.max(0,#list-ROWS)
        S.scroll=math.max(0,math.min(S.scroll,maxScroll))
        local casts=f:CastCount(S.key)
        for i=1,ROWS do
            local r=list[i+S.scroll]; local row=S.rows[i]
            row.data=r
            row.p:SetHidden(not r)
            if r then
                local linked=S.key and r.after[S.key] or 0
                row.icon:SetTexture(r.icon~="" and r.icon or "/esoui/art/icons/icon_missing.dds")
                row.name:SetText(string.format("%s  |c6B665C%d|r",r.name,r.id))
                row.name:SetColor(rgba(linked>0 and GREEN or TEXT))
                local where=tr(SCOPES[r.scope] or r.scope)
                local time=r.duration>0 and string.format("%.1fs",r.duration) or tr("no timer")
                row.meta:SetText(linked>0 and fmt("%s · %s · %d/%d",time,where,linked,math.max(linked,casts)) or (time.." · "..where))
                row.meta:SetColor(rgba(linked>0 and GREEN or MUTED))
                row.bg:SetCenterColor(rgba(linked>0 and LINKED or (i%2==0 and FIELD or CARD)))
            end
        end
        local status
        if f.active then
            status=fmt("Recording, %d s left. Cast %s 2-3 times on a target dummy.",f:SecondsLeft(),S.name:GetText())
        elseif #f.results>0 then
            status=casts>0 and fmt("%d effects. Green rows came right after %s; 3/3 means seen after 3 of 3 casts.",#f.results,S.name:GetText())
                or fmt("%d effects. Cast the selected skill while recording to see which belong to it.",#f.results)
        else
            status=tr("No results yet. Press Record, then use the skill.")
        end
        S.finderStatus:SetText(status)
        S.recordButton:SetLabel(tr(f.active and "Stop recording" or "Record 60 s"))
        S.recordButton:SetAccent(f.active and CORAL or YELLOW)
        S.empty:SetHidden(#list>0)
        S.scrollInfo:SetText(#list>ROWS and string.format("%d–%d / %d",S.scroll+1,math.min(#list,S.scroll+ROWS),#list) or "")
        if S.finderBar then S.finderBar:Update(S.scroll,#list) end
    end

    local function assign(r,target)
        if not r then return end
        if target=="proc" then
            S.proc:SetText(tostring(r.id)); A:StudioShowStep(3)
            message(fmt("%s copied to Proc glow. Press Save.",r.name)); return
        end
        if target==1 and not S.middleBlock:IsHidden() then message(tr(MIDDLE_REASON[S.middleReason] or MIDDLE_REASON.whip),AMBER); return end
        local row=S.timerRows[target]
        row.effect:SetText(tostring(r.id)); row.seconds:SetText(""); row.fixed=false
        paintRow(target)
        -- The filled row is in step 3: show it there, ready to save.
        A:StudioShowStep(3)
        message(fmt("%s: %s. Press Save to apply.",tr(POSITIONS[target]),r.name),AMBER)
    end
    -- Rows as typed, by position (nil = empty row). nil plus a message if invalid.
    local function trim(text) return tostring(text or ""):gsub("^%s+",""):gsub("%s+$","") end
    local function unchanged(i)
        local l=S.loaded and S.loaded[i]
        local row=S.timerRows[i]
        return l and l.rule and trim(row.effect:GetText())==trim(l.effect) and trim(row.seconds:GetText())==trim(l.seconds) and row.fixed==l.fixed
    end
    local function collectRows(id)
        local list={}
        for i=1,3 do
            local row=S.timerRows[i]
            local blocked=i==1 and not S.middleBlock:IsHidden()
            local text,secsText=trim(row.effect:GetText()),trim(row.seconds:GetText())
            local effect=tonumber(text)
            local secs=tonumber(secsText)
            -- An untouched row keeps its saved rule as it is; only rows the
            -- user edited are checked.
            local keep=not blocked and unchanged(i)
            if not blocked and not keep and text~="" and (not effect or effect<=0 or effect~=math.floor(effect) or effect==math.huge) then
                return nil,fmt("%s: the effect ID must be a whole number.",tr(POSITIONS[i]))
            end
            if blocked then
                -- A locked middle is not editable here, but a rule saved for
                -- it earlier must survive a corner edit or an unchanged Save.
                -- It is carried as kept (and never played by Test).
                local saved=S.loaded and S.loaded[1] and S.loaded[1].rule
                if saved then list[i]={keep=saved,blocked=true} end
            elseif keep then
                list[i]={keep=S.loaded[i].rule}
            elseif row.fixed then
                if not secs or secs<=0 then return nil,fmt("%s: enter the seconds for a fixed timer.",tr(POSITIONS[i])) end
                -- A fake effect needs no effect ID; the skill's own ID keys it.
                list[i]={effect=effect or id,duration=secs,mode="cast"}
            elseif effect then
                list[i]={effect=effect,duration=0,mode="effect"}
            end
            if list[i] and i>=2 and S.promote==i then list[i].promote=true end
        end
        return list
    end
    local function save()
        local key,id=selected()
        if key~=S.key then loadSkill(); message(tr("The skill in this slot changed. Check it and save again."),AMBER); return end
        if not key then message(tr("No skill in this slot."),AMBER); return end
        local state=slotState()
        if state and state.abilityKey==key and A:TrackingLock(state) then message(tr("This skill is locked by another feature."),AMBER); return end
        local list,problem=collectRows(id)
        if not list then message(problem,AMBER); return end
        local n,same=0,S.promote==(S.loaded and S.loaded.promote)
        for i=1,3 do
            if list[i] then n=n+1 end
            local l=S.loaded and S.loaded[i]
            if (list[i] and not list[i].keep) or (not list[i] and l and l.rule) then same=false end
        end
        -- Nothing edited: keep the rule as it is (built-in stays built-in).
        if same then message(tr("Nothing changed.")); return end
        local ok,result=A.tracker:SetRules(key,list)
        if not ok then message(tr(result),AMBER); return end
        A:RefreshSlots(); loadSkill(); A:RefreshStudioRules()
        if CALLBACK_MANAGER and A.settingsPanel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel",A.settingsPanel) end
        message(n>0 and fmt("Saved %d timer(s).",n) or tr("Your timers removed; built-in tracking is back."))
    end
    -- Test: play the rows as typed on the HUD for a few seconds, without saving.
    local function test()
        if A.preview then message(tr("Turn off HUD preview to test on your bar."),AMBER); return end
        local key,id=selected()
        if not key or key~=S.key then message(tr("No skill in this slot."),AMBER); return end
        local list,problem=collectRows(id)
        if not list then message(problem,AMBER); return end
        local phases={}
        local any=false
        for i=1,3 do
            local r=list[i]
            if r and not r.blocked then
                -- An untouched row is {keep=rule}: read the saved rule itself.
                local rule=r.keep or r
                local secs=tonumber(rule.duration) or 0
                local ms
                if rule.castDurationAPI and GetAbilityDuration then ms=tonumber(GetAbilityDuration(id,nil,"player"))
                elseif rule.mode=="cast" then ms=secs*1000
                else
                    ms=GetAbilityDuration and rule.effect and tonumber(GetAbilityDuration(rule.effect,nil,"player")) or 0
                    if (not ms or ms<1000) and secs>0 then ms=secs*1000 end
                end
                if not ms or ms<1000 or ms>3600000 then ms=({6000,10000,14000})[i] end
                phases[i]={ms=ms,promote=r.promote}
                any=true
            end
        end
        if not any then message(tr("Fill in at least one row to test it."),AMBER); return end
        A.studioTest={key=key,start=GetFrameTimeMilliseconds(),phases=phases}
        message(tr("Test running on your bar: watch the skill's middle and corners."),CYAN)
    end
    S.save,S.test,S.assign,S.removeSaved=save,test,function(r,target) assign(r,target) end,removeSaved

    ------------------------------------------------------------------
    -- Window
    ------------------------------------------------------------------
    local function prepareFont()
        if useRajdhani~=nil then return end
        -- Rajdhani if its .slug loaded (Fonts.xml), else ESO's bold font.
        do
            local probe=WM:CreateControl(nil,GuiRoot,CT_LABEL)
            probe:SetFont("$(BOLD_FONT)|20")
            local base=probe.GetFont and probe:GetFont()
            local ok=pcall(probe.SetFont,probe,RAJ_SEMI.."|20")
            local measured=false
            if ok and probe.GetStringWidth then
                local okw,width=pcall(probe.GetStringWidth,probe,"0123456789")
                measured=okw and type(width)=="number" and width>0
            end
            useRajdhani=ok and measured and not (base and probe.GetFont and probe:GetFont()==base) or false
            probe:SetHidden(true)
        end
    end
    A.studioStyle={prepareFont=prepareFont,fill=fill,block=block,label=label,button=button,
        cream=CREAM,card=CARD,field=FIELD,ink=INK,soft=INK_SOFT,yellow=YELLOW,teal=TEAL}
    function A:BuildStudio()
        if S.window then return end
        prepareFont()
        local w=WM:CreateTopLevelWindow("ZeraUISkillTracking")
        S.window=w
        w:SetDimensions(W,H); w:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
        w:SetScale(A:HUDCanvasScale())
        w:SetDrawTier(DT_HIGH); w:SetMouseEnabled(true); w:SetMovable(true); w:SetClampedToScreen(true)
        fill(w,7,7,W,H,INK,INK,1,0)
        S.frame=fill(w,0,0,W,H,CREAM,INK,3,1)
        S.messages={}
        local function step(n,title) return string.format("%d · %s",n,tr(title)) end

        -- Header: title, the selected skill as a chip, Close.
        label(w,tr("Skill tracking"),22,14,210,28,INK,nil,nil,true)
        local chip=block(w,236,14,340,38,CARD,3,2)
        local chipFrame=fill(chip,6,6,26,26,INK,INK,2,3)
        S.chipIcon=WM:CreateControl(nil,chipFrame,CT_TEXTURE); S.chipIcon:SetDimensions(22,22); S.chipIcon:SetAnchor(CENTER,chipFrame,CENTER,0,0); onTop(S.chipIcon)
        S.chipText=label(chip,"",40,7,292,16,INK,nil,nil,true)
        label(w,tr("Pick a skill, check what its timer shows, change it only if it is wrong."),596,14,370,13,INK_SOFT,nil,38)
        button(w,tr("Close"),W-112,16,90,34,function() A:CloseStudio() end)

        -- One screen: own timers (left), skill + more options (right),
        -- effect finder (bottom).
        local MY=72
        local LW=704
        local RX,RW=20+LW+16,W-40-LW-16
        local MAIN_H=364
        local FY=MY+MAIN_H+16
        local FH=H-FY-22
        S.sections={}

        -- A selectable action-bar slot.
        local function slotButton(parent,row,cat,num,x,y,size)
            local sh=fill(parent,x+2,y+2,size,size,INK,INK,1,2)
            local frame=fill(parent,x,y,size,size,CARD,INK,2,3)
            local icon=WM:CreateControl(nil,frame,CT_TEXTURE)
            icon:SetDimensions(size-6,size-6); icon:SetAnchor(CENTER,frame,CENTER,0,0); onTop(icon)
            local hit=WM:CreateControl(nil,frame,CT_BUTTON)
            hit:SetAnchorFill(frame); hit:SetMouseEnabled(true); hit:SetDrawLevel(12)
            local entry={row=row,cat=cat,num=num,frame=frame,icon=icon,shadow=sh}
            hit:SetHandler("OnMouseEnter",function() if not (entry.cat==S.cat and num==S.num) then frame:SetEdgeTexture("",1,1,3) end end)
            hit:SetHandler("OnMouseExit",function() paintBar() end)
            hit:SetHandler("OnMouseUp",function(_,mouse,inside)
                if inside and (not MOUSE_BUTTON_INDEX_LEFT or mouse==MOUSE_BUTTON_INDEX_LEFT) then
                    if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then PlaySound(SOUNDS.DEFAULT_CLICK) end
                    A:StudioSelect(entry.cat,num)
                else paintBar() end
            end)
            hoverTip(hit,function()
                local name=GetSlotName and GetSlotName(slotIndex(num),entry.cat) or ""
                if name=="" then return nil end
                return zo_strformat and zo_strformat("<<1>>",name) or name,tr(barName(entry.cat)).." "..num
            end)
            S.bars[#S.bars+1]=entry
            return entry
        end
        local refreshTip=function() return tr("Refresh"),tr("Reads your bars again, e.g. after you changed a skill while this window was open.") end
        local function doRefresh() refreshBar(); loadSkill(); message(tr("Bars refreshed.")) end

        ------------------------------------------------------------------
        -- 3 · Your own timers (with what the timer shows now on top)
        ------------------------------------------------------------------
        local c3=card(w,step(3,"Your own timers"),20,MY,LW,MAIN_H)
        S.sections[3]=c3
        S.customTag=fill(c3,250,12,120,26,TEAL,INK,2,3)
        -- Skill name (summary text) and its ability ID next to the title;
        -- the icon is the one in the header chip.
        S.icon=S.chipIcon
        S.name=label(c3,"",0,0,10,12,INK); S.name:SetHidden(true)
        S.info=label(c3,"",LW-310,16,286,12,INK_SOFT,TEXT_ALIGN_RIGHT,nil,true)
        S.customFlag=label(S.customTag,"",9,2,200,13,INK,nil,nil,true)
        -- What the timer shows now (step 2): a yellow strip with its text.
        local now=fill(c3,16,46,LW-36,46,YELLOW,INK,2,3)
        S.sections[2]=now
        S.sourceHead=label(now,"",10,3,LW-56,14,INK,nil,nil,true)
        S.sourceBody=label(now,"",10,21,LW-56,12,INK,nil,22)
        hoverTip(now,function() return S.sourceHead:GetText(),S.sourceBody:GetText() end)
        local HY=104
        label(c3,tr("Where"),20,HY,100,13,INK,nil,nil,true)
        local hMove=label(c3,tr("To middle"),114,HY,90,13,INK,nil,nil,true)
        local qMove=qmark(c3,196,HY+2)
        local hId=label(c3,tr("Effect ID"),216,HY,120,13,INK,nil,nil,true)
        local qId=qmark(c3,312,HY+2)
        local hKind=label(c3,tr("What it counts"),388,HY,140,13,INK,nil,nil,true)
        local qKind=qmark(c3,504,HY+2)
        local hSec=label(c3,tr("Seconds"),598,HY,60,13,INK,nil,nil,true)
        local qSec=qmark(c3,654,HY+2)
        fill(c3,20,HY+24,LW-48,3,INK,INK,1,2)
        local moveTip=function() return tr("Move to the middle"),tr("When the middle timer ends, this corner timer moves to the middle. Only one corner can do this.") end
        local idTip=function() return tr("Effect ID"),tr("The number of the buff or debuff this timer follows. Find it with section 4: record, cast the skill, click Middle / Left / Right on its green row.") end
        local kindTip=function() return tr("What it counts"),tr("Follow the effect: the real time left on that buff/debuff, as the game reports it.").."\n"..tr("Fake effect (from cast): no real effect is read; a timer simply counts the Seconds you enter from the moment you press the skill. For effects the game doesn't report.") end
        local secTip=function() return tr("Seconds"),tr("Only for a fake effect: how long the timer counts after you press the skill.") end
        for _,pair in ipairs({{hMove,moveTip},{qMove,moveTip},{hId,idTip},{qId,idTip},{hKind,kindTip},{qKind,kindTip},{hSec,secTip},{qSec,secTip}}) do hoverTip(pair[1],pair[2]) end
        S.timerRows={}
        for i=1,3 do
            local y=140+(i-1)*56
            local row={}
            label(c3,tr(POSITIONS[i]),20,y+6,100,17,INK,nil,nil,true)
            local index=i
            if i>=2 then
                -- Move to the middle when the middle timer ends (one corner only).
                local track=fill(c3,114,y+5,38,22,CARD,INK,2,3)
                track.knob=fill(track,4,4,14,14,INK,INK,1,4)
                -- A backdrop in DL_BACKGROUND is not a reliable hit target.
                -- Keep the artwork there but put a real button above it.
                local hit=WM:CreateControl(nil,track,CT_BUTTON)
                hit:SetAnchorFill(track); hit:SetMouseEnabled(true)
                hit:SetDrawLayer(DL_CONTROLS); hit:SetDrawLevel(20)
                hit:SetHandler("OnMouseUp",function(_,mouse,inside)
                    if inside==false or (MOUSE_BUTTON_INDEX_LEFT and mouse~=MOUSE_BUTTON_INDEX_LEFT) then return end
                    S.promote=S.promote~=index and index or nil; paintPromote()
                end)
                hoverTip(hit,moveTip)
                row.promote=track
            else
                label(c3,"–",116,y+6,38,16,INK_SOFT)
            end
            row.effect=input(c3,216,y,150,9)
            row.effect:SetHandler("OnTextChanged",function() paintName(index) end)
            row.nameLabel=label(c3,"",218,y+33,170,12,INK_SOFT,nil,nil,true)
            local function setKind(fixed) local r=S.timerRows[index]; r.fixed=fixed; paintRow(index) end
            row.follow=button(c3,tr("Follow the effect"),388,y,108,30,function() setKind(false) end,nil,true)
            row.fake=button(c3,tr("Fake effect"),496,y,90,30,function() setKind(true) end,nil,true)
            hoverTip(row.follow,kindTip); hoverTip(row.fake,kindTip)
            row.seconds=input(c3,598,y,56,5)
            row.noSeconds=label(c3,"–",602,y+6,50,16,INK_SOFT)
            local clear=button(c3,"X",662,y,28,30,function()
                local r=S.timerRows[index]; r.effect:SetText(""); r.seconds:SetText(""); r.fixed=false
                if S.promote==index then S.promote=nil end
                paintRow(index)
            end,nil,true)
            hoverTip(clear,function() return tr("Clear row"),tr("Empties this row. Press Save to apply.") end)
            if i<3 then local dash=fill(c3,20,y+50,LW-48,2,INK_SOFT,INK_SOFT,1,2); dash:SetAlpha(.45) end
            S.timerRows[i]=row
        end
        -- Middle row cover for skills whose middle timer belongs to their mechanic.
        S.middleBlock=fill(c3,210,136,486,50,WARN_FILL,INK,2,6)
        S.middleBlock:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); S.middleBlock:SetMouseEnabled(true)
        S.middleText=label(S.middleBlock,"",10,3,466,13,INK,nil,42,true)
        S.middleText:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); S.middleText:SetDrawLevel(7)
        S.middleBlock:SetHidden(true)
        label(c3,tr("Empty rows are ignored. A ticked corner timer moves to the middle when the middle one ends."),20,298,LW-48,12,INK_SOFT)
        button(c3,tr("Save"),20,318,104,32,save,YELLOW)
        button(c3,tr("Back to default"),136,318,170,32,function()
            if not S.key then return end
            A.tracker:ClearRule(S.key); A:RefreshSlots(); loadSkill(); A:RefreshStudioRules()
            if CALLBACK_MANAGER and A.settingsPanel then CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel",A.settingsPanel) end
            message(tr("Built-in tracking restored for this skill."))
        end)
        local testButton=button(c3,tr("Test"),318,318,88,32,test,BLUE)
        hoverTip(testButton,function() return tr("Test"),tr("Plays the rows as typed on your bar for a few seconds, without saving. Follow-the-effect rows use a sample time.") end)
        S.message=label(c3,"",422,318,LW-446,13,GREEN,nil,36,true)
        S.messages[#S.messages+1]=S.message
        -- Lock: covers the rows when another feature owns this skill's timers.
        S.lock=fill(c3,10,98,LW-24,MAIN_H-110,WARN_FILL,INK,3,8)
        S.lock:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); S.lock:SetMouseEnabled(true)
        local lockTitle=label(S.lock,tr("LOCKED FOR THIS SKILL"),18,16,LW-60,20,CORAL,nil,nil,true)
        S.lockText=label(S.lock,"",18,48,LW-60,15,INK,nil,150,true)
        for _,l in ipairs({lockTitle,S.lockText}) do l:SetDrawLayer(DL_OVERLAY or DL_CONTROLS); l:SetDrawLevel(9) end
        S.lockText:SetVerticalAlignment(TEXT_ALIGN_TOP)
        S.lock:SetHidden(true)

        ------------------------------------------------------------------
        -- 1 · Skill (right, top) and More options (right, below)
        ------------------------------------------------------------------
        local cm=card(w,step(1,"Choose a skill"),RX,MY,RW,170)
        S.sections[1]=cm
        for r,cat in ipairs({PRIMARY,BACKUP}) do
            local y=46+(r-1)*42
            S.barLabels[r]=label(cm,tr(barName(cat)),16,y+6,72,13,INK,nil,nil,true)
            for num=1,5 do slotButton(cm,r,cat,num,90+(num-1)*42,y,34) end
        end
        label(cm,tr("Ultimates keep their built-in tracking."),16,132,RW-150,11,INK_SOFT,nil,28)
        local r3=button(cm,tr("Refresh"),RW-124,130,100,28,doRefresh,nil,true)
        hoverTip(r3,refreshTip)

        local co=card(w,tr("More options"),RX,MY+184,RW,MAIN_H-184)
        S.sections[5]=co
        label(co,tr("Proc glow ID"),16,44,RW-40,12,INK,nil,nil,true)
        S.proc=input(co,16,64,86,9)
        button(co,tr("Save"),110,64,62,30,function()
            if not S.key then return end
            local ok,msg=A.tracker:SetProcRule(S.key,S.proc:GetText())
            if ok then A:RefreshSlots(); loadSkill(); A:RefreshStudioRules(); message(tr("Proc effect saved.")) else message(tr(msg),AMBER) end
        end,nil,true)
        S.procAuto=button(co,tr("Automatic"),180,64,78,30,function() if S.key then A.tracker:ClearProcRule(S.key,false); A:RefreshSlots(); loadSkill(); A:RefreshStudioRules() end end,nil,true)
        S.procOff=button(co,tr("Off"),266,64,52,30,function() if S.key then A.tracker:ClearProcRule(S.key,true); A:RefreshSlots(); loadSkill(); A:RefreshStudioRules() end end,nil,true)
        label(co,tr("Several targets"),16,108,100,12,INK,nil,28,true)
        S.policy=button(co,"",118,106,RW-142,30,function()
            if not S.key then return end
            local p=A.settings.trackingPolicies[S.key] or {}
            local index=1
            for k=1,3 do if POLICIES[k]==p.timer then index=k end end
            p.timer=POLICIES[index%3+1]
            A.settings.trackingPolicies[S.key]=next(p) and p or nil
            A:ApplySettings(); loadSkill(); A:RefreshStudioRules()
        end,nil,true)
        hoverTip(S.policy,function() return tr("Several targets"),tr("When this skill's debuff is on more than one enemy: follow the enemy you look at, or show the soonest / latest one.") end)
        label(co,tr("Others' buff"),16,146,100,12,INK,nil,28,true)
        S.external=button(co,"",118,144,RW-142,30,function()
            if not S.key then return end
            local p=A.settings.trackingPolicies[S.key] or {}
            p.external=not p.external or nil
            A.settings.trackingPolicies[S.key]=next(p) and p or nil
            A:ApplySettings(); loadSkill(); A:RefreshStudioRules()
        end,nil,true)
        hoverTip(S.external,function() return tr("Same buff from others"),tr("If you have no own copy of the tracked buff, show the same buff given by another player.") end)

        ------------------------------------------------------------------
        -- 4 · Find the effect ID (bottom): finder or saved rules
        ------------------------------------------------------------------
        local FW=W-44
        local c4=card(w,step(4,"Find the effect ID"),20,FY,FW,FH)
        S.sections[4]=c4
        S.finderTab=button(c4,tr("Find effects"),FW-24-232-8-90,10,90,28,function() showView("finder") end,nil,true)
        S.ruleTab=button(c4,"",FW-24-232,10,232,28,function() showView("rules") end,nil,true)
        local LX,LISTX=24,372
        local LISTW=FW-LISTX-44
        local LISTY=68
        -- Bounded, virtualized lists: wheel, arrow buttons, track clicks and
        -- a draggable thumb all use the same integer scroll position.
        local function scrollbar(parent,getScroll,setScroll,refreshList)
            local height=ROWS*ROW_H
            local bar=WM:CreateControl(nil,parent,CT_CONTROL)
            bar:SetDimensions(18,height); bar:SetAnchor(TOPLEFT,parent,TOPLEFT,LISTX+LISTW+4,LISTY)
            local rail=fill(bar,0,20,18,height-40,FIELD,INK,1,2)
            local thumb=WM:CreateControl(nil,bar,CT_BUTTON)
            thumb:SetMouseEnabled(true); thumb:SetDrawLayer(DL_CONTROLS); thumb:SetDrawLevel(20)
            local face=fill(thumb,0,0,18,20,INK_SOFT,INK,1,3)
            local maxScroll,travel,thumbHeight=0,0,20
            local function moveFromMouse()
                if maxScroll<=0 or not GetUIMousePosition or not rail.GetTop then return end
                local _,mouseY=GetUIMousePosition()
                local top=rail:GetTop()
                if not mouseY or not top then return end
                local scale=S.window and S.window.GetScale and S.window:GetScale() or 1
                if type(scale)~="number" or scale<=0 then scale=1 end
                local ratio=travel>0 and math.max(0,math.min(1,((mouseY-top)/scale-thumbHeight/2)/travel)) or 0
                setScroll(math.floor(ratio*maxScroll+.5)); refreshList()
            end
            local hit=WM:CreateControl(nil,rail,CT_BUTTON)
            hit:SetAnchorFill(rail); hit:SetMouseEnabled(true); hit:SetDrawLayer(DL_CONTROLS); hit:SetDrawLevel(10)
            hit:SetHandler("OnMouseUp",function(_,mouse,inside)
                if inside~=false and (not MOUSE_BUTTON_INDEX_LEFT or mouse==MOUSE_BUTTON_INDEX_LEFT) then moveFromMouse() end
            end)
            local function stopDrag()
                if bar.dragging then bar.dragging=false; bar:SetHandler("OnUpdate",nil) end
            end
            bar.StopDrag=stopDrag
            bar:SetHandler("OnHide",stopDrag)
            thumb:SetHandler("OnMouseDown",function(_,mouse)
                if MOUSE_BUTTON_INDEX_LEFT and mouse~=MOUSE_BUTTON_INDEX_LEFT then return end
                bar.dragging=true
                bar:SetHandler("OnUpdate",moveFromMouse)
            end)
            thumb:SetHandler("OnMouseUp",stopDrag)
            button(bar,"^",0,0,18,18,function() setScroll(getScroll()-1); refreshList() end,nil,true)
            button(bar,"v",0,height-18,18,18,function() setScroll(getScroll()+1); refreshList() end,nil,true)
            function bar:Update(offset,total)
                maxScroll=math.max(0,total-ROWS)
                local railHeight=height-40
                thumbHeight=math.max(20,math.floor(railHeight*math.min(1,ROWS/math.max(1,total))))
                travel=railHeight-thumbHeight
                local y=20+(maxScroll>0 and math.floor(travel*offset/maxScroll+.5) or 0)
                thumb:ClearAnchors(); thumb:SetAnchor(TOPLEFT,bar,TOPLEFT,0,y)
                thumb:SetDimensions(18,thumbHeight); face:SetDimensions(18,thumbHeight)
                thumb:SetHidden(maxScroll==0)
            end
            return bar
        end
        local function rowsArea(parent,wheel,make)
            local list=WM:CreateControl(nil,parent,CT_CONTROL)
            list:SetAnchor(TOPLEFT,parent,TOPLEFT,LISTX,LISTY); list:SetDimensions(LISTW,ROWS*ROW_H)
            list:SetMouseEnabled(true); list:SetHandler("OnMouseWheel",wheel)
            for i=1,ROWS do
                local p=WM:CreateControl(nil,list,CT_CONTROL)
                p:SetAnchor(TOPLEFT,list,TOPLEFT,0,(i-1)*ROW_H); p:SetDimensions(LISTW,ROW_H-2)
                p:SetMouseEnabled(true); p:SetHandler("OnMouseWheel",wheel)
                local row={p=p}
                row.bg=fill(p,0,0,LISTW,ROW_H-2,CARD,INK_SOFT,1,2); row.bg:SetEdgeColor(0,0,0,0)
                local line=fill(p,0,ROW_H-3,LISTW,1,INK_SOFT,INK_SOFT,1,3); line:SetAlpha(.4)
                row.icon=WM:CreateControl(nil,p,CT_TEXTURE); row.icon:SetDimensions(24,24); row.icon:SetAnchor(LEFT,p,LEFT,6,0); onTop(row.icon)
                row.name=label(p,"",38,0,LISTW-250,14,INK,nil,nil,true); row.name:SetHeight(17)
                row.meta=label(p,"",38,16,LISTW-250,11,INK_SOFT); row.meta:SetHeight(14)
                make(row,p,i)
            end
            return list
        end
        local fv=WM:CreateControl(nil,c4,CT_CONTROL); fv:SetAnchor(TOPLEFT,c4,TOPLEFT,0,0); fv:SetDimensions(FW,FH)
        S.finderView=fv
        label(fv,tr("Record, cast the selected skill 2-3 times, then click Middle / Left / Right on the green row that belongs to it."),LX,46,320,13,INK,nil,48)
        S.recordButton=button(fv,"",LX,100,154,32,function()
            if A.finder.active then A.finder:Stop("stopped") else A.finder:Start() end
            A:RefreshStudioResults()
        end,YELLOW)
        button(fv,tr("Effects on me"),LX+166,100,154,32,function() A.finder:Snapshot("player"); A:RefreshStudioResults() end)
        button(fv,tr("On target"),LX,142,154,32,function()
            if A.finder:Snapshot("reticleover")==0 then message(tr("Look at a target first."),AMBER) end
            A:RefreshStudioResults()
        end)
        button(fv,tr("Clear"),LX+166,142,154,32,function() A.finder:Clear(); A:RefreshStudioResults() end)
        S.finderStatus=label(fv,"",LX,186,320,12,INK_SOFT,nil,50)
        S.finderStatus:SetVerticalAlignment(TEXT_ALIGN_TOP)
        local m4=label(fv,"",LX,240,320,13,GREEN,nil,36,true)
        m4:SetVerticalAlignment(TEXT_ALIGN_TOP)
        S.messages[#S.messages+1]=m4
        label(fv,tr("Effect"),LISTX+38,46,200,12,INK,nil,nil,true)
        label(fv,tr("Use as"),FW-24-200,46,196,12,INK,TEXT_ALIGN_RIGHT,nil,true)
        local function wheel(_,delta) S.scroll=S.scroll-(delta>0 and 3 or -3); A:RefreshStudioResults() end
        local list=rowsArea(fv,wheel,function(row,p,i)
            local function hit(target) return function() assign(row.data,target) end end
            button(p,tr("Middle"),LISTW-206,3,64,26,hit(1),nil,true)
            button(p,tr("Left"),LISTW-136,3,58,26,hit(2),nil,true)
            button(p,tr("Right"),LISTW-72,3,64,26,hit(3),nil,true)
            hoverTip(row.icon,function()
                local r=row.data; if not r then return nil end
                return string.format("%s  (%d)",r.name,r.id),GetAbilityDescription and GetAbilityDescription(r.id) or ""
            end)
            row.p:SetHidden(true)
            S.rows[i]=row
        end)
        S.empty=label(list,tr("Results appear here."),0,40,LISTW,15,INK_SOFT,TEXT_ALIGN_CENTER,nil,true)
        S.scrollInfo=label(fv,"",LISTX,LISTY+ROWS*ROW_H+2,LISTW,11,INK_SOFT,TEXT_ALIGN_RIGHT)
        S.finderBar=scrollbar(fv,function() return S.scroll end,function(v) S.scroll=v end,function() A:RefreshStudioResults() end)
        -- Saved rules view
        local rv=WM:CreateControl(nil,c4,CT_CONTROL); rv:SetAnchor(TOPLEFT,c4,TOPLEFT,0,0); rv:SetDimensions(FW,FH)
        S.rulesView=rv
        label(rv,tr("Every skill you changed, also skills no longer on your bars. Remove sets it back to built-in tracking."),LX,46,320,13,INK,nil,64)
        local function rwheel(_,delta) S.ruleScroll=S.ruleScroll-(delta>0 and 3 or -3); A:RefreshStudioRules() end
        local rlist=rowsArea(rv,rwheel,function(row,p,i)
            row.bg:SetCenterColor(rgba(i%2==0 and FIELD or CARD))
            button(p,tr("Remove"),LISTW-92,3,84,26,function() removeSaved(row.key) end,CORAL,true)
            S.ruleRows[i]=row
        end)
        S.rulesEmpty=label(rlist,tr("You have no saved rules."),0,40,LISTW,15,INK_SOFT,TEXT_ALIGN_CENTER,nil,true)
        S.rulesInfo=label(rv,"",LISTX,LISTY+ROWS*ROW_H+2,LISTW,11,INK_SOFT,TEXT_ALIGN_RIGHT)
        S.rulesBar=scrollbar(rv,function() return S.ruleScroll end,function(v) S.ruleScroll=v end,function() A:RefreshStudioRules() end)
        rv:SetHidden(true)

        A.finder:OnChange(function() A:RefreshStudioResults() end)
        w:SetHandler("OnHide",function()
            if S.finderBar and S.finderBar.StopDrag then S.finderBar:StopDrag() end
            if S.rulesBar and S.rulesBar.StopDrag then S.rulesBar:StopDrag() end
            if ClearTooltip and InformationTooltip then ClearTooltip(InformationTooltip) end
        end)
        w:SetHidden(true)
    end
    -- Filling a row from the finder briefly highlights the relevant section.
    function A:StudioShowStep(n)
        n=math.max(1,math.min(4,n or 1))
        S.focus=n
        local part=S.sections and S.sections[n]
        if part then
            part:SetEdgeColor(rgba(YELLOW)); part:SetEdgeTexture("",1,1,4)
            part.flashGen=(part.flashGen or 0)+1
            local gen=part.flashGen
            local function restore() if part.flashGen==gen then part:SetEdgeColor(rgba(INK)); part:SetEdgeTexture("",1,1,2) end end
            if type(zo_callLater)=="function" then zo_callLater(restore,900) else restore() end
        end
    end

    function A:OpenStudio(cat,num)
        if self.editing or (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen()) then d("Zera UI: "..tr("finish HUD editing first.")); return end
        self:BuildStudio()
        refreshBar()
        if cat and ((S.werewolf and cat==WEREWOLF) or (not S.werewolf and (cat==PRIMARY or cat==BACKUP))) then S.cat=cat end
        if num then S.num=math.max(1,math.min(5,num)) end
        S.window:SetHidden(false)
        A.RaiseWindow(S.window)
        loadSkill(); showView(S.view or "finder")
        S.focus=nil
        -- Entering UI mode can show the HUD again; raise the window after it.
        if type(zo_callLater)=="function" then zo_callLater(function() if S.window and not S.window:IsHidden() then self:EnterEditorInput(); A.RaiseWindow(S.window) end end,50)
        else self:EnterEditorInput(); A.RaiseWindow(S.window) end
    end
    function A:CloseStudio()
        if not S.window or S.window:IsHidden() then return end
        S.window:SetHidden(true)
        self.studioTest=nil
        if not self.editing and not (self.IsNativeHudEditorOpen and self:IsNativeHudEditorOpen()) then self:ReleaseEditorInput() end
    end
    function A:StudioVisible() return S.window~=nil and not S.window:IsHidden() end
    -- After a slot refresh: icons always; the skill panel only if the selected
    -- slot now holds a different skill (never wipes what is being typed).
    function A:StudioRefresh(force)
        if not S.window or S.window:IsHidden() or self.studioRefreshing then return end
        self.studioRefreshing=true
        local changed=refreshBar()
        local key=selected()
        if force or changed or key~=S.key then loadSkill() end
        if force or S.view=="rules" then self:RefreshStudioRules() end
        self.studioRefreshing=nil
    end
    -- Test playback for one slot: left, duration for a position (or nil).
    function A:StudioTestTimer(slot,now,index)
        local t=self.studioTest
        if not t or t.key~=slot.abilityKey then return nil end
        local total=0
        for i=1,3 do local p=t.phases[i]; if p and p.ms>total then total=p.ms end end
        if now-t.start>total+600 then self.studioTest=nil; return nil end
        local p=t.phases[index]
        if not p then return 0,0 end
        return math.max(0,t.start+p.ms-now),p.ms
    end
end
