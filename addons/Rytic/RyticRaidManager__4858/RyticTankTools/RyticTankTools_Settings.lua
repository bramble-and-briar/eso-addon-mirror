------------------------------------------------------------
-- RYTICTANK SETTINGS v8.1 - local-reference optimization
-- LibAddonMenu-2.0 controls, including merged Set HUD controls.
------------------------------------------------------------

local RyticTank = RyticTank

RyticTank.Settings = RyticTank.Settings or {}
local Settings = RyticTank.Settings

local function ONOFF(v) return v and "ON" or "OFF" end
local function BOOL(v) return v == "ON" end

function Settings.Initialize()
    -- Settings must be able to register before the feature modules initialize.
    RyticTank.saved = RyticTank.saved or {}
    RyticTank.saved.sets = RyticTank.saved.sets or {
        enabled=true, hideOutOfCombat=true, locked=true, preview=false,
        orientation="HORIZONTAL", iconSize=36, spacing=8, abbreviateNames=false,
        position={x=700,y=300},
    }
    RyticTank.saved.resources = RyticTank.saved.resources or {
        enabled=true, hideOutOfCombat=true, locked=true, preview=false,
        scale=1.0,
        theme="REGULAR",
        potionHealthThreshold=30,
        potionResourceThreshold=30,
        position={x=650,y=250},
    }
    RyticTank.saved.block = RyticTank.saved.block or {
        enabled=true, locked=true, preview=false, combatOnly=true,
        scale=1.0, position={x=800,y=500},
    }
    RyticTank.saved.stats = RyticTank.saved.stats or {
        enabled=true, savedFights={},
    }
    if RyticTank.saved.stats.enabled == nil then
        RyticTank.saved.stats.enabled = true
    end

    local LAM = LibAddonMenu2

    local panelData = {
        type = "panel",
        name = "Rytic Combat & Raid Tools",
        displayName = "|cFFAA00Rytic Combat & Raid Tools|r",
        author = "Rytic",
        version = "3.1.0",
        registerForRefresh = false,
        registerForDefaults = true,
    }

    LAM:RegisterAddonPanel("RyticTankToolsOptions", panelData)

    local options = {
        {
            type="header",
            name="Set HUD",
        },
        {
            type="dropdown",
            name="Enable Set HUD",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.sets.enabled) end,
            setFunc=function(v)
                local enabled=BOOL(v)
                if RyticTank.Sets and RyticTank.Sets.SetEnabled then
                    RyticTank.Sets.SetEnabled(enabled)
                else
                    RyticTank.saved.sets.enabled=enabled
                end
            end,
            default="ON",
        },
        {
            type="dropdown",
            name="Hide Set HUD Out of Combat",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.sets.hideOutOfCombat) end,
            setFunc=function(v)
                RyticTank.saved.sets.hideOutOfCombat=BOOL(v)
                if RyticTank.Sets then RyticTank.Sets.Update() end
            end,
            default="ON",
        },
        {
            type="dropdown",
            name="Lock Set HUD",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.sets.locked) end,
            setFunc=function(v)
                RyticTank.saved.sets.locked=BOOL(v)
                if RyticTank.Sets then RyticTank.Sets.ApplyLock() end
            end,
            default="ON",
        },
        {
            type="dropdown",
            name="Preview Set HUD",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.sets.preview) end,
            setFunc=function(v)
                RyticTank.saved.sets.preview=BOOL(v)
                if RyticTank.Sets then RyticTank.Sets.Update() end
            end,
            default="OFF",
        },

        -- MERGED CONTROLS
        {
            type="dropdown", name="Set HUD Orientation",
            choices={"HORIZONTAL","VERTICAL"},
            getFunc=function() return RyticTank.saved.sets.orientation or "HORIZONTAL" end,
            setFunc=function(v)
                RyticTank.saved.sets.orientation=v
                if RyticTank.Sets and RyticTank.Sets.SetOrientation then
                    RyticTank.Sets.SetOrientation(v)
                end
            end,
            default="HORIZONTAL",
        },
        {
            type="slider",
            name="Set Icon Size",
            tooltip="Size of each equipped-set icon.",
            min=24, max=64, step=1,
            getFunc=function() return RyticTank.saved.sets.iconSize or 36 end,
            setFunc=function(v)
                if RyticTank.Sets and RyticTank.Sets.SetIconSize then RyticTank.Sets.SetIconSize(v) else RyticTank.saved.sets.iconSize=v end
            end,
            default=36,
        },
        {
            type="slider",
            name="Spacing Between Sets",
            tooltip="Horizontal space between equipped sets.",
            min=0, max=30, step=1,
            getFunc=function() return RyticTank.saved.sets.spacing or 8 end,
            setFunc=function(v)
                if RyticTank.Sets and RyticTank.Sets.SetSpacing then RyticTank.Sets.SetSpacing(v) else RyticTank.saved.sets.spacing=v end
            end,
            default=8,
        },
        {
            type="dropdown",
            name="Abbreviate Set Names",
            tooltip="Use short names below the icons for an even smaller HUD.",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.sets.abbreviateNames) end,
            setFunc=function(v)
                if RyticTank.Sets and RyticTank.Sets.SetAbbreviate then RyticTank.Sets.SetAbbreviate(BOOL(v)) else RyticTank.saved.sets.abbreviateNames=BOOL(v) end
            end,
            default="OFF",
        },

        {
            type="header",
            name="Resource HUD",
        },
        {
            type="dropdown",
            name="Resource HUD Theme",
            tooltip="Cosmetic corner artwork only. Regular keeps the original clean HUD.",
            choices={"REGULAR","MALE","FEMALE"},
            getFunc=function()
                return RyticTank.saved.resources.theme or "REGULAR"
            end,
            setFunc=function(v)
                RyticTank.saved.resources.theme=v
                if RyticTank.Resources and RyticTank.Resources.ApplyTheme then
                    RyticTank.Resources.ApplyTheme()
                end
            end,
            default="REGULAR",
        },
        {
            type="dropdown",
            name="Enable Resource HUD",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.resources.enabled) end,
            setFunc=function(v)
                local enabled=BOOL(v)
                if RyticTank.Resources and RyticTank.Resources.SetEnabled then
                    RyticTank.Resources.SetEnabled(enabled)
                else
                    RyticTank.saved.resources.enabled=enabled
                    if RyticTank.Resources and RyticTank.Resources.Update then RyticTank.Resources.Update() end
                end
            end,
            default="ON",
        },
        {
            type="checkbox",
            name="Unlock RSS HUD",
            tooltip="Unlock the curved Health/Stamina/Magicka HUD so it can be dragged anywhere on screen.",
            getFunc=function()
                return RyticTank.saved.resources.locked == false
            end,
            setFunc=function(v)
                if RyticTank.Resources and RyticTank.Resources.SetEditMode then
                    RyticTank.Resources.SetEditMode(v)
                else
                    RyticTank.saved.resources.locked = not v
                end
            end,
            default=false,
        },
        {
            type="button",
            name="Reset RSS HUD Position",
            tooltip="Moves the curved Resource HUD back to its default visible position.",
            func=function()
                if RyticTank.Resources and RyticTank.Resources.ResetPosition then
                    RyticTank.Resources.ResetPosition()
                else
                    RyticTank.saved.resources.position={x=650,y=250}
                end
            end,
            width="half",
        },
        {
            type="dropdown",
            name="Hide Resources Out of Combat",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.resources.hideOutOfCombat) end,
            setFunc=function(v)
                local hide=BOOL(v)
                if RyticTank.Resources and RyticTank.Resources.SetHideOutOfCombat then
                    RyticTank.Resources.SetHideOutOfCombat(hide)
                else
                    RyticTank.saved.resources.hideOutOfCombat=hide
                    if RyticTank.Resources and RyticTank.Resources.Update then
                        RyticTank.Resources.Update()
                    end
                end
            end,
            default="ON",
        },
        {
            type="slider",
            name="Resource HUD Scale",
            min=50,max=150,step=1,
            getFunc=function() return math.floor((RyticTank.saved.resources.scale or 1)*100+.5) end,
            setFunc=function(v)
                RyticTank.saved.resources.scale=v/100
                if RyticTank.Resources and RyticTank.Resources.ApplyScale then
                    RyticTank.Resources.ApplyScale()
                elseif RyticTank.Resources and RyticTank.Resources.window then
                    RyticTank.Resources.window:SetScale(v/100)
                end
            end,
            default=100,
        },

        {
            type="header",
            name="Potion Warning Thresholds",
        },
        {
            type="slider",
            name="Health Potion Threshold",
            tooltip="Health percentage that triggers the potion warning.",
            min=5, max=100, step=1,
            getFunc=function()
                return RyticTank.saved.resources.potionHealthThreshold
                    or RyticTank.saved.resources.potionThreshold
                    or 30
            end,
            setFunc=function(v)
                RyticTank.saved.resources.potionHealthThreshold=v
                if RyticTank.Resources and RyticTank.Resources.Update then
                    RyticTank.Resources.Update()
                end
            end,
            default=30,
        },
        {
            type="slider",
            name="Stamina / Magicka Potion Threshold",
            tooltip="Shared Stamina and Magicka percentage that triggers the potion warning.",
            min=5, max=100, step=1,
            getFunc=function()
                return RyticTank.saved.resources.potionResourceThreshold
                    or RyticTank.saved.resources.potionThreshold
                    or 30
            end,
            setFunc=function(v)
                RyticTank.saved.resources.potionResourceThreshold=v
                if RyticTank.Resources and RyticTank.Resources.Update then
                    RyticTank.Resources.Update()
                end
            end,
            default=30,
        },

        {
            type="header",
            name="TankStats",
        },
        {
            type="dropdown",
            name="Enable TankStats",
            tooltip="Enable or disable RyticTankStats combat tracking and the TankStats window.",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.stats.enabled) end,
            setFunc=function(v)
                RyticTank.saved.stats.enabled=BOOL(v)
                if RyticTank.Stats and RyticTank.Stats.SetEnabled then
                    RyticTank.Stats.SetEnabled(RyticTank.saved.stats.enabled)
                elseif not RyticTank.saved.stats.enabled and RyticTank.Stats and RyticTank.Stats.CloseWindow then
                    RyticTank.Stats.CloseWindow()
                end
            end,
            default="ON",
        },

        {
            type="header",
            name="Block HUD",
        },
        {
            type="dropdown",
            name="Enable Block HUD",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.block.enabled) end,
            setFunc=function(v)
                local enabled=BOOL(v)
                if RyticTank.Block and RyticTank.Block.SetEnabled then
                    RyticTank.Block.SetEnabled(enabled)
                else
                    RyticTank.saved.block.enabled=enabled
                    if RyticTank.Block and RyticTank.Block.Update then RyticTank.Block.Update() end
                end
            end,
            default="ON",
        },
        {
            type="checkbox",
            name="Unlock Block HUD",
            tooltip="Unlock the Block HUD so it can be dragged. Turn OFF to lock it in place.",
            getFunc=function() return RyticTank.saved.block.locked == false end,
            setFunc=function(v)
                RyticTank.saved.block.locked = not v
                if RyticTank.Block and RyticTank.Block.ApplyLock then
                    RyticTank.Block.ApplyLock()
                elseif RyticTank.Block and RyticTank.Block.SetLocked then
                    RyticTank.Block.SetLocked(not v)
                end
            end,
            default=false,
        },
        {
            type="dropdown",
            name="Hide Block HUD Out of Combat",
            choices={"ON","OFF"},
            getFunc=function() return ONOFF(RyticTank.saved.block.combatOnly) end,
            setFunc=function(v)
                RyticTank.saved.block.combatOnly=BOOL(v)
                if RyticTank.Block and RyticTank.Block.Update then RyticTank.Block.Update() end
            end,
            default="OFF",
        },

        {
            type="slider",
            name="Block HUD Scale",
            min=50,max=150,step=1,
            getFunc=function() return math.floor((RyticTank.saved.block.scale or 1)*100+.5) end,
            setFunc=function(v)
                RyticTank.saved.block.scale=v/100
                if RyticTank.Block and RyticTank.Block.window then
                    RyticTank.Block.window:SetScale(v/100)
                end
            end,
            default=100,
        },
    }

    table.insert(options,{type="header",name="Rytic HUD / Raid Tools"})
    table.insert(options,{type="dropdown",name="Rytic Action Bar",choices={"ON","OFF"},getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.actionBar=RyticTank.saved.actionBar or {enabled=true}
        return RyticTank.saved.actionBar.enabled~=false and "ON" or "OFF" end,
        setFunc=function(v) local on=v=="ON"; if RyticTank.ActionBar and RyticTank.ActionBar.SetEnabled then RyticTank.ActionBar.SetEnabled(on) else RyticTank.saved.actionBar.enabled=on end end,width="full"})
    table.insert(options,{type="checkbox",name="Lock Action Bar",tooltip="Lock the Rytic Action Bar in place. Turn OFF to make it movable.",getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.actionBar=RyticTank.saved.actionBar or {enabled=true,scale=1.0,unlocked=false}; return RyticTank.saved.actionBar.unlocked~=true end,
        setFunc=function(v) local unlocked=not (v and true or false); if RyticTank.ActionBar and RyticTank.ActionBar.SetUnlocked then RyticTank.ActionBar.SetUnlocked(unlocked) else RyticTank.saved.actionBar.unlocked=unlocked end end,width="full"})
    table.insert(options,{type="slider",name="Action Bar Scale",tooltip="Scale the Rytic Action Bar.",min=50,max=200,step=5,default=100,getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.actionBar=RyticTank.saved.actionBar or {enabled=true,scale=1.0,unlocked=false}; return math.floor((RyticTank.saved.actionBar.scale or 1.0)*100+0.5) end,
        setFunc=function(v) local scale=v/100; if RyticTank.ActionBar and RyticTank.ActionBar.SetScale then RyticTank.ActionBar.SetScale(scale) else RyticTank.saved.actionBar.scale=scale end end,width="full"})
    table.insert(options,{type="header",name="Group Frames"})
    table.insert(options,{type="dropdown",name="Rytic Group Frames",choices={"ON","OFF"},getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true}
        return RyticTank.saved.groupFrames.enabled~=false and "ON" or "OFF" end,
        setFunc=function(v) local on=v=="ON"; if RyticTank.GroupFrames and RyticTank.GroupFrames.SetEnabled then RyticTank.GroupFrames.SetEnabled(on) else RyticTank.saved.groupFrames.enabled=on end end,width="full"})

    table.insert(options,{type="checkbox",name="Show Shield Overlay",tooltip="Show damage shields over the health bar in Rytic Group Frames. Turn OFF to hide only the shield overlay.",getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true}
        if RyticTank.saved.groupFrames.showShieldOverlay==nil then RyticTank.saved.groupFrames.showShieldOverlay=true end
        return RyticTank.saved.groupFrames.showShieldOverlay~=false end,
        setFunc=function(v)
            if RyticTank.GroupFrames and RyticTank.GroupFrames.SetShieldOverlayEnabled then
                RyticTank.GroupFrames.SetShieldOverlayEnabled(v==true)
            else
                RyticTank.saved.groupFrames.showShieldOverlay=(v==true)
            end
        end,default=true,width="full"})

    table.insert(options,{type="dropdown",name="Group Member Name",tooltip="Choose whether group frames show the ESO account/gamer tag, character name, or both.",choices={"GAMER TAG","CHARACTER NAME","BOTH"},getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true}; return RyticTank.saved.groupFrames.nameDisplay or "GAMER TAG" end,
        setFunc=function(v) if RyticTank.GroupFrames and RyticTank.GroupFrames.SetNameDisplay then RyticTank.GroupFrames.SetNameDisplay(v) else RyticTank.saved.groupFrames.nameDisplay=v end end,default="GAMER TAG",width="full"})

    table.insert(options,{type="checkbox",name="Unlock Group Frames",tooltip="Unlock the Rytic group frame panel so it can be dragged with the left mouse button. Turn this OFF again after positioning it.",getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true,locked=true,scale=1.0}
        return RyticTank.saved.groupFrames.locked==false end,
        setFunc=function(v) if RyticTank.GroupFrames and RyticTank.GroupFrames.SetLocked then RyticTank.GroupFrames.SetLocked(not v) else RyticTank.saved.groupFrames.locked=not v end end,width="full"})
    table.insert(options,{type="slider",name="Group Frame Scale",tooltip="Scale the complete Rytic group frame panel.",min=50,max=200,step=5,default=100,getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true,locked=true,scale=1.0}
        return math.floor((RyticTank.saved.groupFrames.scale or 1.0)*100+0.5) end,
        setFunc=function(v) local scale=v/100; if RyticTank.GroupFrames and RyticTank.GroupFrames.SetScale then RyticTank.GroupFrames.SetScale(scale) else RyticTank.saved.groupFrames.scale=scale end end,width="full"})
    table.insert(options,{type="slider",name="Group Frame Range",tooltip="Distance in meters before a grouped player is shaded as out of range.",min=5,max=50,step=1,default=15,getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true,rangeMeters=15}
        if RyticTank.GroupFrames and RyticTank.GroupFrames.GetRangeMeters then return RyticTank.GroupFrames.GetRangeMeters() end
        return RyticTank.saved.groupFrames.rangeMeters or 15 end,
        setFunc=function(v) if RyticTank.GroupFrames and RyticTank.GroupFrames.SetRangeMeters then RyticTank.GroupFrames.SetRangeMeters(v) else RyticTank.saved.groupFrames.rangeMeters=v end end,width="full"})
    table.insert(options,{type="button",name="Reset Group Frame Position",tooltip="Move the Rytic group frames back to their default position.",func=function()
        if RyticTank.GroupFrames and RyticTank.GroupFrames.ResetPosition then RyticTank.GroupFrames.ResetPosition() else RyticTank.saved.groupFrames.x=40; RyticTank.saved.groupFrames.y=220 end
    end,width="half"})

    local function roleColor(role,defaults)
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.groupFrames=RyticTank.saved.groupFrames or {enabled=true}; RyticTank.saved.groupFrames.roleColors=RyticTank.saved.groupFrames.roleColors or {}
        local c=RyticTank.saved.groupFrames.roleColors[role]
        if not c then c={defaults[1],defaults[2],defaults[3],defaults[4]}; RyticTank.saved.groupFrames.roleColors[role]=c end
        return c
    end
    local function addRoleColor(name,role,default)
        table.insert(options,{type="colorpicker",name=name,getFunc=function() local c=roleColor(role,default); return c[1],c[2],c[3],c[4] end,
            setFunc=function(r,g,b,a) if RyticTank.GroupFrames and RyticTank.GroupFrames.SetRoleColor then RyticTank.GroupFrames.SetRoleColor(role,r,g,b,a) else RyticTank.saved.groupFrames.roleColors[role]={r,g,b,a} end end,
            default={r=default[1],g=default[2],b=default[3],a=default[4]},width="full"})
    end
    addRoleColor("Tank Frame Color","tank",{0.20,0.85,0.30,1})
    addRoleColor("Healer Frame Color","healer",{1.00,0.35,0.70,1})
    addRoleColor("DPS Frame Color","dps",{0.20,0.55,1.00,1})

    table.insert(options,{type="header",name="Raid Controls"})
    table.insert(options,{type="checkbox",name="Enable Raid Warnings",tooltip="Show RCRT /rw warning popups and play their warning sound on this client. Turning this OFF only suppresses local popup/sound presentation; RCRT communication remains active.",getFunc=function()
        RyticTank.saved=RyticTank.saved or {}
        if RyticTank.saved.raidWarningsEnabled==nil then RyticTank.saved.raidWarningsEnabled=true end
        return RyticTank.saved.raidWarningsEnabled~=false
    end,setFunc=function(v)
        RyticTank.saved=RyticTank.saved or {}
        RyticTank.saved.raidWarningsEnabled=(v==true)
        if not v and RyticTank.GroupSync and RyticTank.GroupSync.rwNotice then RyticTank.UI.Refresh(RyticTank.GroupSync.rwNotice) end
    end,default=true,width="full"})
    table.insert(options,{type="dropdown",name="Enable Raid Controls",choices={"ON","OFF"},getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.raidLead=RyticTank.saved.raidLead or {enabled=true,pullSeconds=5,scale=1.0,unlocked=false}
        return RyticTank.saved.raidLead.enabled~=false and "ON" or "OFF" end,
        setFunc=function(v) local on=v=="ON"; if RyticTank.RaidLead and RyticTank.RaidLead.SetEnabled then RyticTank.RaidLead.SetEnabled(on) else RyticTank.saved.raidLead.enabled=on end end,width="full"})
    table.insert(options,{type="checkbox",name="Unlock Raid Controls",tooltip="Unlock READY CHECK / PULL so the panel can be dragged. Lock it again when positioned.",getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.raidLead=RyticTank.saved.raidLead or {enabled=true,pullSeconds=5,scale=1.0,unlocked=false}; return RyticTank.saved.raidLead.unlocked==true end,
        setFunc=function(v) if RyticTank.RaidLead and RyticTank.RaidLead.SetUnlocked then RyticTank.RaidLead.SetUnlocked(v) else RyticTank.saved.raidLead.unlocked=v end end,width="full"})
    table.insert(options,{type="slider",name="Raid Controls Scale",tooltip="Scale READY CHECK and PULL together.",min=50,max=200,step=5,default=100,getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.raidLead=RyticTank.saved.raidLead or {enabled=true,pullSeconds=5,scale=1.0,unlocked=false}; return math.floor((RyticTank.saved.raidLead.scale or 1.0)*100+0.5) end,
        setFunc=function(v) local scale=v/100; if RyticTank.RaidLead and RyticTank.RaidLead.SetScale then RyticTank.RaidLead.SetScale(scale) else RyticTank.saved.raidLead.scale=scale end end,width="full"})

    table.insert(options,{type="slider",name="Pull Countdown",min=3,max=30,step=1,default=5,getFunc=function()
        RyticTank.saved=RyticTank.saved or {}; RyticTank.saved.raidLead=RyticTank.saved.raidLead or {enabled=true,pullSeconds=5,scale=1.0,unlocked=false}; return RyticTank.saved.raidLead.pullSeconds or 5 end,
        setFunc=function(v) RyticTank.saved.raidLead.pullSeconds=v; if RyticTank.RaidLead and RyticTank.RaidLead.pull then RyticTank.RaidLead.pull:SetText("PULL "..tostring(v).."s") end end,width="full"})

    -- Keep the settings page compact: every former header becomes a collapsed LAM submenu.
    -- This uses LAM's documented submenu/controls structure rather than custom UI hooks.
    local collapsedOptions={}
    local currentSection=nil
    for _,control in ipairs(options) do
        if control.type=="header" then
            currentSection={type="submenu",name=control.name,controls={}}
            collapsedOptions[#collapsedOptions+1]=currentSection
        elseif currentSection then
            currentSection.controls[#currentSection.controls+1]=control
        else
            collapsedOptions[#collapsedOptions+1]=control
        end
    end

    LAM:RegisterOptionControls("RyticTankToolsOptions", collapsedOptions)
end
