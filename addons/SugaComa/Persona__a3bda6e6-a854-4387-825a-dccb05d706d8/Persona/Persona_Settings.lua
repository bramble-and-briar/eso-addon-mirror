Persona = Persona or {}
Persona.Settings = Persona.Settings or {}

local IDLE_MODES={
    {name="DISABLED",data=Persona.IDLE_DISABLED},
    {name="PERSONALITY IDLE",data=Persona.IDLE_PERSONALITY},
    {name="CUSTOM ACT",data=Persona.IDLE_CUSTOM_ACT},
}

local QUALITY_ITEMS={
    {name="EPIC OR BETTER",data=4},
    {name="LEGENDARY ONLY",data=5},
}

local SETTINGS_MODES={
    {name="ACCOUNT-WIDE",data=true},
    {name="CURRENT CHARACTER",data=false},
}

local function FindName(items,value,fallback)
    for _,item in ipairs(items) do if item.data==value then return item.name end end
    return fallback
end

local function AddEmotePool(panel,L,prefix)
    for index=1,5 do
        panel:AddSetting({
            type=L.ST_DROPDOWN,
            label="Random Emote "..index,
            items=Persona.GetEmoteItems,
            getFunction=function()
                return Persona.GetEmoteName(PersonaDB[prefix.."Emote"..index])
            end,
            setFunction=function(_,_,item)
                PersonaDB[prefix.."Emote"..index]=item.data
            end,
            default="NONE",
        })
    end
end

local function AddTest(panel,L,label,name)
    panel:AddSetting({
        type=L.ST_BUTTON,label=label,
        buttonText=function()
            return Persona.IsTestArmed(name) and "Confirm Test" or "Test"
        end,
        clickHandler=function() Persona.Test(name) end,
    })
end

function Persona.Settings.Initialize()
    if not LibHarvensAddonSettings then
        Persona.Chat("LibHarvensAddonSettings missing")
        return
    end

    local L=LibHarvensAddonSettings
    local panel=L:AddAddon("Persona",{allowDefaults=true,allowRefresh=true})
    if not panel then return end

    panel:AddSetting({
        type=L.ST_DROPDOWN,
        label="Settings Profile",
        tooltip="Choose one shared profile for every character or a separate profile for each character. A new character profile starts as a copy of the account-wide settings. Switching profiles does not delete or overwrite an existing profile. Use Refresh or reopen the panel after changing this option.",
        items=SETTINGS_MODES,
        getFunction=Persona.GetSettingsModeName,
        setFunction=function(_,_,item)
            Persona.SetSettingsMode(item.data)
        end,
        default="ACCOUNT-WIDE",
    })

    panel:AddSetting({
        type=L.ST_CHECKBOX,label="Enable Persona",
        getFunction=function() return PersonaDB.enabled end,
        setFunction=function(v) PersonaDB.enabled=v end,
        default=true,
    })

    panel:AddSetting({
        type=L.ST_CHECKBOX,label="Debug",
        getFunction=function() return PersonaDB.debug end,
        setFunction=function(v) PersonaDB.debug=v end,
        default=false,
    })

    panel:AddSetting({
        type=L.ST_LABEL,
        label="|cFF5555PvP lockout is permanent.|r Quick Chats are separate and cannot be automated.",
    })

    panel:AddSetting({type=L.ST_SECTION,label="Idle Behaviour"})

    panel:AddSetting({
        type=L.ST_DROPDOWN,label="Idle Mode",items=IDLE_MODES,
        getFunction=function()
            return FindName(IDLE_MODES,PersonaDB.idleMode,"DISABLED")
        end,
        setFunction=function(_,_,item) PersonaDB.idleMode=item.data end,
        default="DISABLED",
    })

    panel:AddSetting({
        type=L.ST_SLIDER,label="Idle Timer",
        getFunction=function() return PersonaDB.idleSeconds end,
        setFunction=function(v) PersonaDB.idleSeconds=v end,
        default=60,min=15,max=300,step=5,unit="s",format="%d",
    })

    panel:AddSetting({
        type=L.ST_SLIDER,label="Idle Cooldown",
        getFunction=function() return PersonaDB.idleCooldownSeconds end,
        setFunction=function(v) PersonaDB.idleCooldownSeconds=v end,
        default=180,min=30,max=1800,step=30,unit="s",format="%d",
    })

    panel:AddSetting({
        type=L.ST_SLIDER,label="Personality Change Chance",
        getFunction=function() return PersonaDB.idlePersonalityChance end,
        setFunction=function(v) PersonaDB.idlePersonalityChance=v end,
        default=100,min=0,max=100,step=5,unit="%",format="%d",
    })

    panel:AddSetting({
        type=L.ST_DROPDOWN,
        label="Normal Personality",
        tooltip="Select the personality Persona should return to when an Idle personality ends. Important: ESO may save whichever personality is active when you log out or use /reloadui. If Persona has temporarily changed your personality at that moment, you may log back in with that personality still active. Allow Persona to return to your Normal Personality before logging out or reloading the UI.",
        items=Persona.GetPersonalityItems,
        getFunction=function()
            return Persona.GetPersonalityName(PersonaDB.normalPersonalityId)
        end,
        setFunction=function(_,_,item)
            PersonaDB.normalPersonalityId=item.data
        end,
        default="NONE / BASE PERSONALITY",
    })

    panel:AddSetting({
        type=L.ST_LABEL,
        label="Personality Idle selects an unlocked personality and lets ESO use its built-in idle animations. Custom Act ignores personality switching.",
    })

    panel:AddSetting({type=L.ST_SECTION,label="Personality Random Pool"})

    panel:AddSetting({
        type=L.ST_LABEL,
        label="Choose which of your unlocked personalities Persona may select during Personality Idle. Newly unlocked personalities are included automatically.",
    })

    local personalityItems=Persona.GetPersonalityItems()
    for index=1,#personalityItems do
        local item=personalityItems[index]
        if item.data~=0 then
            local collectibleId=item.data
            panel:AddSetting({
                type=L.ST_CHECKBOX,
                label=item.name,
                tooltip="Allow Persona to randomly select "..item.name.." during Personality Idle.",
                getFunction=function()
                    return Persona.IsPersonalityInIdlePool(collectibleId)
                end,
                setFunction=function(value)
                    Persona.SetPersonalityInIdlePool(collectibleId,value)
                end,
                default=true,
            })
        end
    end

    for index=1,5 do
        panel:AddSetting({
            type=L.ST_DROPDOWN,label="Act Step "..index.." Emote",
            items=Persona.GetEmoteItems,
            getFunction=function()
                return Persona.GetEmoteName(PersonaDB["idleEmote"..index])
            end,
            setFunction=function(_,_,item)
                PersonaDB["idleEmote"..index]=item.data
            end,
            default="NONE",
        })

        panel:AddSetting({
            type=L.ST_SLIDER,label="Act Step "..index.." Delay",
            getFunction=function() return PersonaDB["idleDelay"..index] end,
            setFunction=function(v) PersonaDB["idleDelay"..index]=v end,
            default=2000,min=500,max=10000,step=100,unit="ms",format="%d",
        })
    end

    AddTest(panel,L,"Test Idle","idle")

    panel:AddSetting({type=L.ST_SECTION,label="After Combat"})
    panel:AddSetting({
        type=L.ST_CHECKBOX,label="Enable",
        getFunction=function() return PersonaDB.combatEnabled end,
        setFunction=function(v) PersonaDB.combatEnabled=v end,
        default=false,
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Delay",
        getFunction=function() return PersonaDB.combatDelaySeconds end,
        setFunction=function(v) PersonaDB.combatDelaySeconds=v end,
        default=2,min=0,max=15,step=1,unit="s",format="%d",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Chance",
        getFunction=function() return PersonaDB.combatChance end,
        setFunction=function(v) PersonaDB.combatChance=v end,
        default=50,min=0,max=100,step=5,unit="%",format="%d",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Cooldown",
        getFunction=function() return PersonaDB.combatCooldownSeconds end,
        setFunction=function(v) PersonaDB.combatCooldownSeconds=v end,
        default=60,min=0,max=900,step=5,unit="s",format="%d",
    })
    AddEmotePool(panel,L,"combat")
    AddTest(panel,L,"Test After Combat","combat")

    panel:AddSetting({type=L.ST_SECTION,label="After Dismount"})
    panel:AddSetting({
        type=L.ST_CHECKBOX,label="Enable",
        getFunction=function() return PersonaDB.dismountEnabled end,
        setFunction=function(v) PersonaDB.dismountEnabled=v end,
        default=false,
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Post-Dismount Delay",
        tooltip="Wait this long after dismounting, then react when you are out of combat. Movement does not cancel the trigger.",
        getFunction=function() return PersonaDB.dismountStillSeconds end,
        setFunction=function(v) PersonaDB.dismountStillSeconds=v end,
        default=3,min=1,max=30,step=1,unit="s",format="%d",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Chance",
        getFunction=function() return PersonaDB.dismountChance end,
        setFunction=function(v) PersonaDB.dismountChance=v end,
        default=50,min=0,max=100,step=5,unit="%",format="%d",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Cooldown",
        getFunction=function() return PersonaDB.dismountCooldownSeconds end,
        setFunction=function(v) PersonaDB.dismountCooldownSeconds=v end,
        default=60,min=0,max=900,step=5,unit="s",format="%d",
    })
    AddEmotePool(panel,L,"dismount")
    AddTest(panel,L,"Test After Dismount","dismount")

    panel:AddSetting({type=L.ST_SECTION,label="Epic Loot"})
    panel:AddSetting({
        type=L.ST_CHECKBOX,label="Enable",
        getFunction=function() return PersonaDB.lootEnabled end,
        setFunction=function(v) PersonaDB.lootEnabled=v end,
        default=false,
    })
    panel:AddSetting({
        type=L.ST_DROPDOWN,label="Minimum Quality",items=QUALITY_ITEMS,
        getFunction=function()
            return FindName(QUALITY_ITEMS,PersonaDB.lootMinimumQuality,"EPIC OR BETTER")
        end,
        setFunction=function(_,_,item) PersonaDB.lootMinimumQuality=item.data end,
        default="EPIC OR BETTER",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Chance",
        getFunction=function() return PersonaDB.lootChance end,
        setFunction=function(v) PersonaDB.lootChance=v end,
        default=100,min=0,max=100,step=5,unit="%",format="%d",
    })
    panel:AddSetting({
        type=L.ST_SLIDER,label="Cooldown",
        getFunction=function() return PersonaDB.lootCooldownSeconds end,
        setFunction=function(v) PersonaDB.lootCooldownSeconds=v end,
        default=30,min=0,max=900,step=5,unit="s",format="%d",
    })
    AddEmotePool(panel,L,"loot")
    AddTest(panel,L,"Test Epic Loot","loot")

    panel:AddSetting({
        type=L.ST_LABEL,
        label="|cFFD700Built on tea, toast and ADHD — tested live on PS5.|r",
    })
end
