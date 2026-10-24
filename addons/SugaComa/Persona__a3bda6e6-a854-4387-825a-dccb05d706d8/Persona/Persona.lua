Persona = Persona or {}

local ADDON_NAME = "Persona"
local EM = EVENT_MANAGER

Persona.version = "1.2.0-test1"
Persona.savedVersion = 1

Persona.IDLE_DISABLED = 0
Persona.IDLE_PERSONALITY = 1
Persona.IDLE_CUSTOM_ACT = 2

Persona.defaults = {
    _personaStorageInitialized = false,
    _personaOutfits = {},

    enabled = true,
    debug = false,

    idleMode = 0,
    idleSeconds = 60,
    idleCooldownSeconds = 180,
    idlePersonalityChance = 100,
    normalPersonalityId = 0,
    idlePersonalityPool = {},

    idleEmote1 = "NONE", idleDelay1 = 2000,
    idleEmote2 = "NONE", idleDelay2 = 2000,
    idleEmote3 = "NONE", idleDelay3 = 2000,
    idleEmote4 = "NONE", idleDelay4 = 2000,
    idleEmote5 = "NONE", idleDelay5 = 2000,

    combatEnabled = false,
    combatDelaySeconds = 2,
    combatChance = 50,
    combatCooldownSeconds = 60,
    combatEmote1 = "NONE", combatEmote2 = "NONE",
    combatEmote3 = "NONE", combatEmote4 = "NONE",
    combatEmote5 = "NONE",

    dismountEnabled = false,
    dismountStillSeconds = 3,
    dismountChance = 50,
    dismountCooldownSeconds = 60,
    dismountEmote1 = "NONE", dismountEmote2 = "NONE",
    dismountEmote3 = "NONE", dismountEmote4 = "NONE",
    dismountEmote5 = "NONE",

    lootEnabled = false,
    lootMinimumQuality = 4,
    lootChance = 100,
    lootCooldownSeconds = 30,
    lootEmote1 = "NONE", lootEmote2 = "NONE",
    lootEmote3 = "NONE", lootEmote4 = "NONE",
    lootEmote5 = "NONE",
}

Persona.storageDefaults = {
    useAccountWide = true,
}

local accountSettings
local characterSettings
local storageSettings

local function DeepCopy(value)
    if type(value) ~= "table" then return value end

    local copy = {}
    for key, childValue in pairs(value) do
        copy[DeepCopy(key)] = DeepCopy(childValue)
    end
    return copy
end

local function CopySettings(source, target)
    for key in pairs(Persona.defaults) do
        if key ~= "_personaStorageInitialized" then
            target[key] = DeepCopy(source[key])
        end
    end
    target._personaStorageInitialized = true
end

local function CopyRuntimeSettings(source, target)
    for key in pairs(Persona.defaults) do
        if key ~= "_personaStorageInitialized" and key ~= "_personaOutfits" then
            target[key] = DeepCopy(source[key])
        end
    end
end

function Persona.UsesAccountWideSettings()
    return not storageSettings or storageSettings.useAccountWide ~= false
end

function Persona.GetSettingsModeName()
    if Persona.UsesAccountWideSettings() then return "ACCOUNT-WIDE" end
    return "CURRENT CHARACTER"
end

local function GetBaseSettings()
    return Persona.UsesAccountWideSettings() and accountSettings or characterSettings
end

local function SafeGetEquippedOutfitIndex()
    if not GetEquippedOutfitIndex then return 0 end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, index = pcall(GetEquippedOutfitIndex, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if ok and index ~= nil then return index end
    end

    local ok, index = pcall(GetEquippedOutfitIndex)
    if ok and index ~= nil then return index end
    return 0
end

local function SafeGetNumOutfits()
    if not GetNumUnlockedOutfits then return 0 end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, count = pcall(GetNumUnlockedOutfits, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if ok and count then return count end
    end

    local ok, count = pcall(GetNumUnlockedOutfits)
    if ok and count then return count end
    return 0
end

local function CleanName(value)
    if not value or value == "" then return "" end
    return value:gsub("%^.*", "")
end

local function SafeGetOutfitName(index)
    if not GetOutfitName then return nil end

    if GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        local ok, name = pcall(GetOutfitName, GAMEPLAY_ACTOR_CATEGORY_PLAYER, index)
        if ok and name and name ~= "" then return CleanName(name) end
    end

    local ok, name = pcall(GetOutfitName, index)
    if ok and name and name ~= "" then return CleanName(name) end
    return nil
end

function Persona.GetOutfitDisplayName(index)
    index = tonumber(index) or 0
    if index == 0 then return "Base appearance (no outfit)" end
    local name = SafeGetOutfitName(index)
    if name then return string.format("Outfit %d - %s", index, name) end
    return string.format("Outfit %d", index)
end

function Persona.GetCurrentOutfitIndex()
    return SafeGetEquippedOutfitIndex()
end

function Persona.GetOutfitItems()
    local items = {
        { name = Persona.GetOutfitDisplayName(0), data = 0 },
    }
    for index = 1, SafeGetNumOutfits() do
        table.insert(items, {
            name = Persona.GetOutfitDisplayName(index),
            data = index,
        })
    end
    return items
end

local function GetOutfitProfiles(baseSettings)
    if not baseSettings then return nil end
    baseSettings._personaOutfits = baseSettings._personaOutfits or {}
    return baseSettings._personaOutfits
end

local function SelectActiveSettings()
    local baseSettings = GetBaseSettings()
    local outfitIndex = Persona.GetCurrentOutfitIndex()
    local outfitProfiles = GetOutfitProfiles(baseSettings)
    local outfitSettings = outfitIndex > 0 and outfitProfiles[outfitIndex] or nil
    PersonaDB = type(outfitSettings) == "table" and outfitSettings or baseSettings
end

function Persona.HasOutfitSettings(outfitIndex)
    local profiles = GetOutfitProfiles(GetBaseSettings())
    return profiles and type(profiles[tonumber(outfitIndex) or 0]) == "table" or false
end

function Persona.GetOutfitSettingsStatus(outfitIndex)
    outfitIndex = tonumber(outfitIndex) or 0
    if outfitIndex == 0 then
        return "Base appearance uses the selected profile's normal settings."
    end
    if Persona.HasOutfitSettings(outfitIndex) then
        return "A Persona profile is saved for " .. Persona.GetOutfitDisplayName(outfitIndex) .. "."
    end
    return "No Persona profile is saved for " .. Persona.GetOutfitDisplayName(outfitIndex)
        .. "; it uses the selected profile's normal settings."
end

function Persona.SaveSettingsToOutfit(outfitIndex)
    outfitIndex = tonumber(outfitIndex) or 0
    if outfitIndex == 0 then
        Persona.Chat("Base appearance cannot have a separate outfit profile.")
        return
    end

    local profiles = GetOutfitProfiles(GetBaseSettings())
    local savedSettings = {}
    CopyRuntimeSettings(PersonaDB, savedSettings)
    profiles[outfitIndex] = savedSettings

    if Persona.GetCurrentOutfitIndex() == outfitIndex then
        PersonaDB = savedSettings
    end
    Persona.Chat("Saved Persona settings for " .. Persona.GetOutfitDisplayName(outfitIndex) .. ".")
end

function Persona.RemoveSettingsFromOutfit(outfitIndex)
    outfitIndex = tonumber(outfitIndex) or 0
    local profiles = GetOutfitProfiles(GetBaseSettings())
    if outfitIndex == 0 or not profiles[outfitIndex] then return end

    profiles[outfitIndex] = nil
    if Persona.GetCurrentOutfitIndex() == outfitIndex then
        SelectActiveSettings()
    end
    Persona.Chat("Removed Persona settings for " .. Persona.GetOutfitDisplayName(outfitIndex) .. ".")
end

function Persona.SetSettingsMode(useAccountWide)
    useAccountWide = useAccountWide ~= false
    if not storageSettings or storageSettings.useAccountWide == useAccountWide then return end

    if not useAccountWide and characterSettings._personaStorageInitialized ~= true then
        CopySettings(accountSettings, characterSettings)
        Persona.Chat("Account settings copied to this character's new profile.")
    end

    storageSettings.useAccountWide = useAccountWide
    SelectActiveSettings()
    Persona.Chat(
        useAccountWide
        and "Using account-wide settings. Refresh or reopen settings to update the panel."
        or "Using this character's settings. Refresh or reopen settings to update the panel."
    )
end

local runtime = {
    ready = false,
    queueRunning = false,
    idleSince = 0,
    idleFired = false,
    lastIdle = 0,
    lastCombat = 0,
    lastDismount = 0,
    lastLoot = 0,
    pendingDismount = 0,
    lastMounted = nil,
    dismountWaitLogged = false,
    testName = "",
    testExpires = 0,
    personalityIdleActive = false,
}

local emoteItems = {}
local emoteBySlash = {}
local personalities = {}
local personalityItems = {
    { name = "NONE / BASE PERSONALITY", data = 0 },
}
local personalityNames = {
    [0] = "NONE / BASE PERSONALITY",
}

function Persona.NowMs()
    return (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds())
        or (GetGameTimeMilliseconds and GetGameTimeMilliseconds())
        or 0
end

function Persona.Chat(text)
    local msg = "|cB427D3[Persona]|r " .. tostring(text)
    zo_callLater(function()
        if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
            CHAT_ROUTER:AddSystemMessage(msg)
        else
            d(msg)
        end
    end, 0)
end

function Persona.Debug(text)
    if PersonaDB and PersonaDB.debug then Persona.Chat(text) end
end

function Persona.IsPvPBlocked()
    if IsInAvAZone and IsInAvAZone() then return true end
    if IsInImperialCity and IsInImperialCity() then return true end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return true end
    return false
end

function Persona.IsSafe()
    if not PersonaDB or not PersonaDB.enabled then return false end
    if Persona.IsPvPBlocked() then return false end
    if IsUnitInCombat("player") then return false end
    if IsUnitDead("player") then return false end
    if IsMounted() then return false end
    if IsUnitSwimming("player") then return false end
    if GetInteractionType and GetInteractionType() ~= INTERACTION_NONE then return false end
    return true
end

local function NormalizeSlash(value)
    if type(value) ~= "string" or value == "" then return nil end
    value = string.lower(value)
    if string.sub(value, 1, 1) ~= "/" then value = "/" .. value end
    return value
end

local function EmoteAvailable(index)
    if not GetEmoteCollectibleId then return true end
    local collectibleId = GetEmoteCollectibleId(index)
    if not collectibleId or collectibleId == 0 then return true end
    if IsCollectibleUnlocked then return IsCollectibleUnlocked(collectibleId) end
    return true
end

local function BuildEmotes()
    emoteItems = {{name="NONE", data="NONE", index=0}}
    emoteBySlash = {NONE=emoteItems[1]}

    if GetNumEmotes and GetEmoteInfo then
        for index=1,GetNumEmotes() do
            local slashName, _, _, displayName, showInGamepadUI = GetEmoteInfo(index)
            local slash = NormalizeSlash(slashName)
            if slash and showInGamepadUI and EmoteAvailable(index) then
                local item={name=string.upper(displayName or slash),data=slash,index=index}
                table.insert(emoteItems,item)
                emoteBySlash[slash]=item
            end
        end
    end

    table.sort(emoteItems,function(a,b)
        if a.data=="NONE" then return true end
        if b.data=="NONE" then return false end
        return a.name<b.name
    end)
end

function Persona.GetEmoteItems()
    return emoteItems
end

function Persona.GetEmoteName(value)
    if value=="NONE" then return "NONE" end
    local item=emoteBySlash[NormalizeSlash(value)]
    return item and item.name or "NONE"
end

local function PlayEmote(value)
    if value=="NONE" then return false end
    local item=emoteBySlash[NormalizeSlash(value)]
    if not item or not item.index or item.index==0 then return false end
    PlayEmoteByIndex(item.index)
    return true
end

local function ScanPersonalityCategory(topLevelIndex, subCategoryIndex)
    if not GetNumCollectiblesInCollectibleCategory then return end
    local count=GetNumCollectiblesInCollectibleCategory(topLevelIndex,subCategoryIndex)

    for collectibleIndex=1,count do
        local collectibleId=GetCollectibleId(topLevelIndex,subCategoryIndex,collectibleIndex)
        if collectibleId and collectibleId~=0 then
            local _,_,_,_,unlocked,_,_,categoryType=GetCollectibleInfo(collectibleId)
            if unlocked and categoryType==COLLECTIBLE_CATEGORY_TYPE_PERSONALITY then
                local collectibleName = GetCollectibleName
                    and GetCollectibleName(collectibleId)
                    or ("PERSONALITY " .. tostring(collectibleId))

                table.insert(personalities,collectibleId)
                table.insert(personalityItems,{
                    name=string.upper(collectibleName),
                    data=collectibleId,
                })
                personalityNames[collectibleId]=string.upper(collectibleName)
            end
        end
    end
end

local function BuildPersonalities()
    personalities={}
    personalityItems={
        {name="NONE / BASE PERSONALITY",data=0},
    }
    personalityNames={
        [0]="NONE / BASE PERSONALITY",
    }
    if not GetNumCollectibleCategories
        or not GetCollectibleCategoryInfo
        or not GetCollectibleId
        or not GetCollectibleInfo then return end

    for topLevelIndex=1,GetNumCollectibleCategories() do
        local _,numSubCategories=GetCollectibleCategoryInfo(topLevelIndex)
        ScanPersonalityCategory(topLevelIndex,nil)
        for subCategoryIndex=1,(numSubCategories or 0) do
            ScanPersonalityCategory(topLevelIndex,subCategoryIndex)
        end
    end

    table.sort(personalityItems,function(a,b)
        if a.data==0 then return true end
        if b.data==0 then return false end
        return a.name<b.name
    end)
end

function Persona.GetPersonalityItems()
    return personalityItems
end

function Persona.GetPersonalityName(collectibleId)
    return personalityNames[collectibleId or 0] or "NONE / BASE PERSONALITY"
end

function Persona.IsPersonalityInIdlePool(collectibleId)
    if not collectibleId or collectibleId==0 then return false end
    if not PersonaDB then return true end
    PersonaDB.idlePersonalityPool=PersonaDB.idlePersonalityPool or {}
    return PersonaDB.idlePersonalityPool[collectibleId]~=false
end

function Persona.SetPersonalityInIdlePool(collectibleId,enabled)
    if not PersonaDB or not collectibleId or collectibleId==0 then return end
    PersonaDB.idlePersonalityPool=PersonaDB.idlePersonalityPool or {}
    if enabled then
        PersonaDB.idlePersonalityPool[collectibleId]=nil
    else
        PersonaDB.idlePersonalityPool[collectibleId]=false
    end
end

local function GetActivePersonality()
    if not GetActiveCollectibleByType then return 0 end

    return GetActiveCollectibleByType(
        COLLECTIBLE_CATEGORY_TYPE_PERSONALITY,
        GAMEPLAY_ACTOR_CATEGORY_PLAYER
    ) or 0
end

local function UsePersonality(collectibleId)
    if not UseCollectible then return false end

    collectibleId=collectibleId or 0
    local activePersonality=GetActivePersonality()

    if collectibleId==0 then
        -- Selecting the equipped personality again toggles it off and returns
        -- the player to ESO's base/no-personality state.
        if activePersonality and activePersonality~=0 then
            UseCollectible(activePersonality,GAMEPLAY_ACTOR_CATEGORY_PLAYER)
            return true
        end
        return false
    end

    if activePersonality==collectibleId then
        return true
    end

    UseCollectible(collectibleId,GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    return true
end

local function RestoreNormalPersonality()
    if not runtime.personalityIdleActive then return end
    runtime.personalityIdleActive=false
    UsePersonality(PersonaDB.normalPersonalityId or 0)
end

local function RandomizePersonality()
    if #personalities==0 or not UseCollectible then return false end
    if math.random(100)>(PersonaDB.idlePersonalityChance or 100) then return false end

    local choices={}
    for _,collectibleId in ipairs(personalities) do
        if Persona.IsPersonalityInIdlePool(collectibleId) then
            table.insert(choices,collectibleId)
        end
    end

    if #choices==0 then return false end

    local changed=UsePersonality(choices[math.random(#choices)])
    if changed then runtime.personalityIdleActive=true end
    return changed
end

local function ResetIdle()
    runtime.idleSince=Persona.NowMs()
    runtime.idleFired=false
end

local function OnOutfitChanged(_, actorCategory)
    if actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_PLAYER then return end
    RestoreNormalPersonality()
    SelectActiveSettings()
    ResetIdle()
    Persona.Debug("Persona profile refreshed for "
        .. Persona.GetOutfitDisplayName(Persona.GetCurrentOutfitIndex()) .. ".")
end

local function FinishQueue()
    runtime.queueRunning=false
end

local function PlayActStep(step)
    if not runtime.queueRunning then return end
    if not Persona.IsSafe() then FinishQueue() ResetIdle() return end
    if step>5 then FinishQueue() ResetIdle() return end

    local emote=PersonaDB["idleEmote"..step] or "NONE"
    local delay=PersonaDB["idleDelay"..step] or 2000
    if emote~="NONE" then PlayEmote(emote) end

    zo_callLater(function() PlayActStep(step+1) end,delay)
end

local function RandomReaction(prefix)
    local choices={}
    for index=1,5 do
        local value=PersonaDB[prefix.."Emote"..index] or "NONE"
        if value~="NONE" then table.insert(choices,value) end
    end
    if #choices==0 then return false end
    return PlayEmote(choices[math.random(#choices)])
end

local function PlayIdle()
    if runtime.queueRunning or not Persona.IsSafe() then return false end

    if PersonaDB.idleMode==Persona.IDLE_PERSONALITY then
        RandomizePersonality()
        ResetIdle()
        return true
    elseif PersonaDB.idleMode==Persona.IDLE_CUSTOM_ACT then
        runtime.queueRunning=true
        PlayActStep(1)
        return true
    end
    return false
end

local function PlayReaction(prefix)
    if runtime.queueRunning or not Persona.IsSafe() then return false end
    runtime.queueRunning=true
    RandomReaction(prefix)
    FinishQueue()
    return true
end

function Persona.IsTestArmed(name)
    return runtime.testName==name and Persona.NowMs()<=runtime.testExpires
end

function Persona.Test(name)
    if not Persona.IsTestArmed(name) then
        runtime.testName=name
        runtime.testExpires=Persona.NowMs()+10000
        Persona.Chat("Press Test again within 10 seconds. Settings will close.")
        return
    end

    runtime.testName=""
    runtime.testExpires=0

    if SCENE_MANAGER and SCENE_MANAGER.ShowBaseScene then
        SCENE_MANAGER:ShowBaseScene()
    end

    zo_callLater(function()
        if name=="idle" then PlayIdle() else PlayReaction(name) end
    end,2000)
end

local function CooldownReady(lastTime,cooldownSeconds)
    return Persona.NowMs()-lastTime >= (cooldownSeconds or 0)*1000
end

local function Tick()
    if not runtime.ready or not PersonaDB.enabled then return end

    local now=Persona.NowMs()
    local moving=IsPlayerMoving()
    local mounted=IsMounted()

    -- Track the actual mounted state every update. This catches Block-triggered
    -- dismounts even if EVENT_MOUNTED_STATE_CHANGED is missed or unreliable.
    if runtime.lastMounted == nil then
        runtime.lastMounted=mounted
    elseif runtime.lastMounted and not mounted then
        runtime.lastMounted=false
        runtime.dismountWaitLogged=false
        Persona.Debug("Dismount detected (mounted -> unmounted).")
        if PersonaDB.dismountEnabled then
            runtime.pendingDismount=now
            Persona.Debug("Post-dismount reaction queued.")
        else
            runtime.pendingDismount=0
            Persona.Debug("Post-dismount reactions are disabled in settings.")
        end
    elseif not runtime.lastMounted and mounted then
        runtime.lastMounted=true
        runtime.pendingDismount=0
        runtime.dismountWaitLogged=false
        Persona.Debug("Mounted state detected; pending dismount reaction cleared.")
    end

    if moving or not Persona.IsSafe() then
        RestoreNormalPersonality()
        ResetIdle()
    elseif not runtime.idleFired
        and PersonaDB.idleMode~=Persona.IDLE_DISABLED
        and CooldownReady(runtime.lastIdle,PersonaDB.idleCooldownSeconds)
        and now-runtime.idleSince >= (PersonaDB.idleSeconds or 60)*1000 then
        runtime.idleFired=true
        runtime.lastIdle=now
        PlayIdle()
    end

    if runtime.pendingDismount>0 then
        -- Movement/inertia never cancels this. After the configured delay,
        -- wait until the player is safe and out of combat.
        if mounted then
            runtime.pendingDismount=0
            runtime.dismountWaitLogged=false
        elseif now-runtime.pendingDismount >= (PersonaDB.dismountStillSeconds or 3)*1000 then
            if not Persona.IsSafe() then
                if not runtime.dismountWaitLogged then
                    runtime.dismountWaitLogged=true
                    Persona.Debug("Post-dismount delay elapsed; waiting for a safe out-of-combat state.")
                end
            else
                runtime.pendingDismount=0
                runtime.dismountWaitLogged=false

                if not PersonaDB.dismountEnabled then
                    Persona.Debug("Post-dismount reaction cancelled: feature disabled.")
                elseif not CooldownReady(runtime.lastDismount,PersonaDB.dismountCooldownSeconds) then
                    Persona.Debug("Post-dismount reaction skipped: cooldown not ready.")
                else
                    local roll=math.random(100)
                    local chance=PersonaDB.dismountChance or 100
                    if roll>chance then
                        Persona.Debug("Post-dismount reaction skipped: chance roll "..tostring(roll).." > "..tostring(chance)..".")
                    else
                        runtime.lastDismount=now
                        Persona.Debug("Post-dismount reaction firing.")
                        PlayReaction("dismount")
                    end
                end
            end
        end
    end
end

local function OnCombatState(_,inCombat)
    if inCombat or not PersonaDB.combatEnabled then return end
    zo_callLater(function()
        if not Persona.IsSafe() then return end
        if not CooldownReady(runtime.lastCombat,PersonaDB.combatCooldownSeconds) then return end
        if math.random(100)>(PersonaDB.combatChance or 100) then return end
        runtime.lastCombat=Persona.NowMs()
        PlayReaction("combat")
    end,(PersonaDB.combatDelaySeconds or 2)*1000)
end

local function OnMountedStateChanged()
    -- Keep the event as a secondary fast refresh, but always read the actual
    -- mounted state directly. Tick() remains the authoritative fallback.
    local mounted=IsMounted()
    if mounted and runtime.lastMounted == false then
        runtime.lastMounted=true
        runtime.pendingDismount=0
        runtime.dismountWaitLogged=false
        Persona.Debug("Mounted state event received.")
    elseif not mounted and runtime.lastMounted == true then
        runtime.lastMounted=false
        runtime.dismountWaitLogged=false
        Persona.Debug("Dismount event received.")
        if PersonaDB.dismountEnabled then
            runtime.pendingDismount=Persona.NowMs()
            Persona.Debug("Post-dismount reaction queued.")
        else
            Persona.Debug("Post-dismount reactions are disabled in settings.")
        end
    end
end

local function IsCelebrationQuality(quality)
    local epic = ITEM_DISPLAY_QUALITY_EPIC or ITEM_QUALITY_ARTIFACT or 4
    local legendary = ITEM_DISPLAY_QUALITY_LEGENDARY or ITEM_QUALITY_LEGENDARY or 5
    local mythic = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE or 6

    return quality == epic
        or quality == legendary
        or quality == mythic
        or quality > legendary
end

local function OnInventorySlotUpdated(
    _,
    bagId,
    slotIndex,
    isNewItem,
    itemSoundCategory,
    updateReason,
    stackCountChange
)
    if not PersonaDB.lootEnabled then return end
    if bagId ~= BAG_BACKPACK then return end
    if not isNewItem then return end

    local itemLink = GetItemLink(bagId, slotIndex)
    if not itemLink or itemLink == "" then
        Persona.Debug("new inventory item has no item link")
        return
    end

    if not GetItemLinkDisplayQuality then
        Persona.Debug("GetItemLinkDisplayQuality unavailable")
        return
    end

    local quality = GetItemLinkDisplayQuality(itemLink)

    Persona.Debug(
        "new item quality "
        .. tostring(quality)
        .. ": "
        .. tostring(itemLink)
    )

    if not quality or not IsCelebrationQuality(quality) then return end
    if not CooldownReady(runtime.lastLoot, PersonaDB.lootCooldownSeconds) then return end
    if math.random(100) > (PersonaDB.lootChance or 100) then return end

    runtime.lastLoot = Persona.NowMs()
    PlayReaction("loot")
end

local function Initialize()
    accountSettings=ZO_SavedVars:NewAccountWide(
        "Persona_SV",Persona.savedVersion,nil,Persona.defaults
    )
    characterSettings=ZO_SavedVars:NewCharacterIdSettings(
        "Persona_SV",Persona.savedVersion,nil,Persona.defaults
    )
    storageSettings=ZO_SavedVars:NewAccountWide(
        "Persona_SV",Persona.savedVersion,"Storage",Persona.storageDefaults
    )

    -- Persona 1.0.0 stored settings account-wide at the un-namespaced path.
    -- Keep that path unchanged so existing users retain their configuration.
    accountSettings._personaStorageInitialized=true

    -- The first time character mode is used on a character, seed it from the
    -- account profile. Later switches never overwrite either stored profile.
    if not Persona.UsesAccountWideSettings()
        and characterSettings._personaStorageInitialized ~= true then
        CopySettings(accountSettings,characterSettings)
    end

    SelectActiveSettings()

    BuildEmotes()
    BuildPersonalities()
    Persona.Settings.Initialize()

    ResetIdle()
    runtime.lastMounted=IsMounted()
    runtime.ready=true

    -- Tick drives idle processing and delayed post-dismount reactions.
    -- Without this registration a dismount can be detected and queued,
    -- but the queued reaction is never evaluated.
    EM:RegisterForUpdate("PersonaTick",1000,Tick)

    EM:RegisterForEvent("PersonaCombat",EVENT_PLAYER_COMBAT_STATE,OnCombatState)
    EM:RegisterForEvent("PersonaMount",EVENT_MOUNTED_STATE_CHANGED,OnMountedStateChanged)
    EM:RegisterForEvent(
        "PersonaOutfit",
        EVENT_OUTFIT_EQUIPMENT_CHANGED,
        OnOutfitChanged
    )
    EM:RegisterForEvent(
        "PersonaLoot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        OnInventorySlotUpdated
    )
    EM:AddFilterForEvent(
        "PersonaLoot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_IS_NEW_ITEM,
        true
    )
    EM:AddFilterForEvent(
        "PersonaLoot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID,
        BAG_BACKPACK
    )
    EM:AddFilterForEvent(
        "PersonaLoot",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_INVENTORY_UPDATE_REASON,
        INVENTORY_UPDATE_REASON_DEFAULT
    )

    Persona.Chat("loaded version "..Persona.version)
end

local function OnAddonLoaded(_,addonName)
    if addonName~=ADDON_NAME then return end
    EM:UnregisterForEvent(ADDON_NAME,EVENT_ADD_ON_LOADED)
    Initialize()
end

EM:RegisterForEvent(ADDON_NAME,EVENT_ADD_ON_LOADED,OnAddonLoaded)
