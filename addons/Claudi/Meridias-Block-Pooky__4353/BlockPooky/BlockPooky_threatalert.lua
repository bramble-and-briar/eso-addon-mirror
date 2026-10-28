--[[ basic initialization -------------------------------------------------------------------------------------------]]
BlockPooky = BlockPooky or {}
local BlockPooky = BlockPooky

local BlockPooky_threatAlertActive = false
local BlockPooky_threatAlertTimer = nil
local BlockPooky_lastThreatAlert = 0

-- Ordered list of configured threat ability IDs (mirrors config.threatalert.abilities)
BlockPooky.THREAT_ABILITY_IDS = nil
-- Maps cleaned ability name -> configured representative ability ID
BlockPooky.THREAT_ABILITY_NAMES = nil

---Resolves the text shown when a threat ability is detected:
---the custom label assigned to that ability if one is set, otherwise the localized ability name
---@param abilityId number the ability ID that triggered the alert
---@return string text to display on the overlay
function BlockPooky.GetThreatAlertText(abilityId)
    local cleanName = BlockPooky.CleanAbilityName(abilityId)
    if BlockPooky.config.threatalert.labels and BlockPooky.THREAT_ABILITY_NAMES then
        -- Look the label up by the configured representative ID so custom text still
        -- matches when an equivalent ability ID (e.g. a different rank) fires the alert.
        local configuredId = BlockPooky.THREAT_ABILITY_NAMES[cleanName]
        if configuredId then
            local custom = BlockPooky.config.threatalert.labels[configuredId]
            if custom and custom ~= "" then
                return custom
            end
        end
    end
    return cleanName
end

---Checks if an ability ID is one of the configured threat abilities
---@param id number the ability ID to check
---@return boolean true if it is a tracked threat ability
local function BlockPooky_IsThreatAbility(id)
    return BlockPooky.THREAT_ABILITY_NAMES[BlockPooky.CleanAbilityName(id)] ~= nil
end


--[[ Threat Alert implementation --------------------------------------------------------------------------------------]]

function BlockPooky.SetThreatAlertTexture()
    if BlockPookyThreatAlertTexture then
        -- Set dimensions to screen size
        local screenWidth, screenHeight = GuiRoot:GetDimensions()
        BlockPookyThreatAlert:SetDimensions(screenWidth, screenHeight)
        BlockPookyThreatAlertTexture:SetDimensions(screenWidth, screenHeight)

        -- Set texture from config
        local textureFile = BlockPooky.config.threatalert.texture or "red.dds"
        local texturePath = "BlockPooky/textures/" .. textureFile
        BlockPookyThreatAlertTexture:SetTexture(texturePath)

        -- Ensure overlay starts hidden
        BlockPookyThreatAlert:SetAlpha(0.0)
        BlockPookyThreatAlertTexture:SetAlpha(0.0)
        if BlockPookyThreatAlertLabel then
            BlockPookyThreatAlertLabel:SetHidden(true)
            BlockPookyThreatAlertLabel:SetText("")
        end
    else
        d("ERROR: BlockPookyThreatAlertTexture not found!")
    end
end

function BlockPooky.ShowThreatAlert(duration, text)
    if BlockPookyThreatAlert then
        local alpha = BlockPooky.config.threatalert.alpha or 0.3
        BlockPookyThreatAlert:SetAlpha(alpha)
        BlockPookyThreatAlertTexture:SetAlpha(alpha)
        BlockPooky_threatAlertActive = true

        -- Show the text label (custom text or the ability name) together with the overlay
        if BlockPookyThreatAlertLabel then
            -- showLabel defaults to ON; treat a missing key (~= false) as enabled
            if BlockPooky.config.threatalert.showLabel ~= false and text and text ~= "" then
                BlockPookyThreatAlertLabel:SetText(text)
                BlockPookyThreatAlertLabel:SetAlpha(1.0)
                BlockPookyThreatAlertLabel:SetHidden(false)
            else
                BlockPookyThreatAlertLabel:SetHidden(true)
            end
        end

        -- Clear any existing timer
        if BlockPooky_threatAlertTimer then
            zo_removeCallLater(BlockPooky_threatAlertTimer)
        end

        -- Use actual effect duration (in milliseconds from event) or default to 8 seconds
        local hideDuration = duration or 8000
        BlockPooky_threatAlertTimer = zo_callLater(function() BlockPooky.HideThreatAlert() end, hideDuration)
    end
end

function BlockPooky.HideThreatAlert()
    if BlockPookyThreatAlert then
        BlockPookyThreatAlert:SetAlpha(0.0)
        BlockPookyThreatAlertTexture:SetAlpha(0.0)
        BlockPooky_threatAlertActive = false

        -- Hide and clear the text label
        if BlockPookyThreatAlertLabel then
            BlockPookyThreatAlertLabel:SetHidden(true)
            BlockPookyThreatAlertLabel:SetText("")
        end

        -- Clear timer if active
        if BlockPooky_threatAlertTimer then
            zo_removeCallLater(BlockPooky_threatAlertTimer)
            BlockPooky_threatAlertTimer = nil
        end
    end
end

--[[ AOE Overlay Helper Functions ]]

function BlockPooky.AddThreatAbility(abilityId)
    if not BlockPooky.config.threatalert.abilities then
        BlockPooky.config.threatalert.abilities = {}
    end
    table.insert(BlockPooky.config.threatalert.abilities, abilityId)
    BlockPooky.RebuildThreatAbilityList()
end

function BlockPooky.RemoveThreatAbility(abilityId)
    if BlockPooky.config.threatalert.abilities then
        for idx, id in ipairs(BlockPooky.config.threatalert.abilities) do
            if id == abilityId then
                table.remove(BlockPooky.config.threatalert.abilities, idx)
                break
            end
        end
        BlockPooky.RebuildThreatAbilityList()
    end
end

function BlockPooky.RebuildThreatAbilityList()
    -- Ensure abilities array exists and has defaults
    if not BlockPooky.config.threatalert.abilities or #BlockPooky.config.threatalert.abilities == 0 then
        BlockPooky.config.threatalert.abilities = {}
    end

    -- Rebuild the name map and the ordered ID list (deduplicated)
    BlockPooky.THREAT_ABILITY_NAMES = {}
    BlockPooky.THREAT_ABILITY_IDS = {}
    for _, id in ipairs(BlockPooky.config.threatalert.abilities) do
        local cleanName = BlockPooky.CleanAbilityName(id)
        BlockPooky.THREAT_ABILITY_NAMES[cleanName] = id
        local alreadyListed = false
        for _, listedId in ipairs(BlockPooky.THREAT_ABILITY_IDS) do
            if listedId == id then
                alreadyListed = true
                break
            end
        end
        if not alreadyListed then
            table.insert(BlockPooky.THREAT_ABILITY_IDS, id)
        end
    end
end

function BlockPooky.UpdateThreatAlertTexture()
    -- Texture change requires XML reload, just log the change
    d("Threat Alert texture changed to: " .. (BlockPooky.config.threatalert.texture or "Indigo.dds"))
    d("Note: Reload the addon to apply texture changes in-game")
end

function BlockPooky.UpdateThreatAlertAlpha()
    if BlockPookyThreatAlert then
        BlockPookyThreatAlert:SetAlpha(BlockPooky.config.threatalert.alpha or 0.3)
        d("Threat Alert alpha changed to: " .. tostring(BlockPooky.config.threatalert.alpha or 0.3))
    end
end

function BlockPooky.RegisterThreatAlert()
    if LibCombat then
        -- Register for DAMAGE_IN events (incoming damage from enemies)
        BlockPooky.threatAlertCallback = function(eventType, timems, result, sourceUnitId, targetUnitId, abilityId,
                                                  hitValue, damageType, overflow)
            -- d("BlockPooky: DAMAGE_IN fired! sourceId=" .. tostring(sourceUnitId) .. " abilityId=" .. tostring(abilityId) .. " hitValue=" .. tostring(hitValue))
            BlockPooky.OnThreatAlert(timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType,
                overflow)
        end
        LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_DAMAGE_IN, BlockPooky.threatAlertCallback, "BlockPooky")
        BlockPooky.threatAlertRegistered = true
        d("BlockPooky: Threat alert registered")
    else
        d("BlockPooky: LibCombat not available!")
        BlockPooky.threatAlertRegistered = false
    end
end

function BlockPooky.UnRegisterThreatAlert()
    if LibCombat and BlockPooky.threatAlertRegistered and BlockPooky.threatAlertCallback then
        LibCombat:UnregisterCallbackType(LIBCOMBAT_EVENT_DAMAGE_IN, BlockPooky.threatAlertCallback, "BlockPooky")
        BlockPooky.threatAlertCallback = nil
        BlockPooky.threatAlertRegistered = false
        d("BlockPooky: Threat alert unregistered")
    end
end

function BlockPooky.InitThreatAlert()
    -- Rebuild from config to ensure sync with saved variables
    BlockPooky.RebuildThreatAbilityList()
    if BlockPooky.config.threatalert.show then
        BlockPooky.RegisterThreatAlert()
    end
end

--[[ event handling -------------------------------------------------------------------------------------------------]]

function BlockPooky.OnThreatAlert(timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType, overflow)
    -- Check if PvP only and not in Cyrodiil
    if BlockPooky.config.threatalert.pvpOnly and not BlockPooky.IsInCyro() then
        return
    end

    if BlockPooky_IsThreatAbility(abilityId) and not BlockPooky_threatAlertActive then
        -- Apply cooldown to prevent spam
        local now = GetGameTimeMilliseconds()
        if (now - BlockPooky_lastThreatAlert) < (BlockPooky.config.threatalert.cooldown or 5000) then
            return
        end
        BlockPooky_lastThreatAlert = now

        -- Get duration from config or use default
        local duration = BlockPooky.config.threatalert.duration or 8000 -- 8 seconds default
        BlockPooky.ShowThreatAlert(duration, BlockPooky.GetThreatAlertText(abilityId))
    end
end
