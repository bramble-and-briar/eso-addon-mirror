-----------------------------------------------------------
-- MasterThief v2.33 - HUD Remaining Fence Transactions
-----------------------------------------------------------
local MasterThief = MasterThief or {}
MasterThief.name = "MasterThief"

local GetTimeStamp = GetTimeStamp
local string_format = string.format
local table_insert = table.insert
local string_lower = string.lower
local string_find = string.find
local string_match = string.match
local tonumber = tonumber
local tostring = tostring

MasterThief.defaultSettings = {
    showHUD = true,
    showSessionStats = true,
    showTimer = true,
    announceInChat = true,
    playLootSound = true,
    autoSellFences = true,
    autoDestroyGreens = false,
    autoDestroyBlues = false,
    autoDestroyPurples = false,
    fontSize = 11,
    posX = 60,
    posY = 100,
    bgColorR = 0.05,
    bgColorG = 0.05,
    bgColorB = 0.1,
    bgColorA = 0.75,
    lastResetDay = 0,
    charStats = {},
}

-----------------------------------------------------------
-- HELPERS & SAFE API WRAPPERS
-----------------------------------------------------------
function MasterThief.SafeGetItemQuality(bagId, slotIndex, link)
    local apiQuality = 1
    if type(GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)
        if quality and quality > 0 then apiQuality = tonumber(quality) end
    end
    if apiQuality <= 1 and link and link ~= "" and type(GetItemLinkDisplayQuality) == "function" then
        local ok, qual = pcall(GetItemLinkDisplayQuality, link)
        if ok and qual then apiQuality = tonumber(qual) or 1 end
    end
    return apiQuality
end

function MasterThief.SafeIsItemStolen(bagId, slotIndex)
    if type(IsItemStolen) == "function" then
        local ok, stolen = pcall(IsItemStolen, bagId, slotIndex)
        if ok and stolen then return true end
    end
    return false
end

function MasterThief.SafeGetItemStackCount(bagId, slotIndex)
    local stackCount = 1
    if type(GetSlotStackSize) == "function" then
        local ok, sc = pcall(GetSlotStackSize, bagId, slotIndex)
        if ok and sc and sc > 0 then
            return sc
        end
    end
    if type(GetItemStackInfo) == "function" then
        local _, sc = pcall(GetItemStackInfo, bagId, slotIndex)
        if sc and type(sc) == "number" and sc > 0 then
            stackCount = sc
        end
    end
    return stackCount
end

-----------------------------------------------------------
-- FENCE TRANSACTION HUD DISPLAY WRAPPER
-----------------------------------------------------------
function MasterThief.SafeGetFenceSellTransactionInfo()
    if type(GetFenceSellTransactionInfo) == "function" then
        local ok, v1, v2 = pcall(GetFenceSellTransactionInfo)
        if ok and v1 and v2 then
            local maxSellsAllowed = v1
            local totalSellsUsed = v2
            local remaining = maxSellsAllowed - totalSellsUsed
            return maxSellsAllowed, totalSellsUsed, remaining, string_format("%d/%d", totalSellsUsed, maxSellsAllowed)
        end
    end
    return 120, 0, 120, "N/A"
end

function MasterThief.GetCustomFont(size)
    return string_format("$(CHAT_FONT)|%d|soft-shadow-thick", size or 11)
end

function MasterThief.GetFormattedSessionTime()
    if not MasterThief.sessionStartTime then
        return "00:00:00"
    end
    local elapsedSeconds = GetTimeStamp() - MasterThief.sessionStartTime
    local hours = math.floor(elapsedSeconds / 3600)
    local mins = math.floor((elapsedSeconds % 3600) / 60)
    local secs = elapsedSeconds % 60
    return string_format("%02d:%02d:%02d", hours, mins, secs)
end

function MasterThief.ResetSessionTimer()
    MasterThief.sessionStartTime = GetTimeStamp()
    local stats = MasterThief.GetActiveCharacterStats()
    if stats then
        stats.totalStolen = 0
        stats.whiteJunkDestroyed = 0
        stats.greenLoot = 0
        stats.blueLoot = 0
        stats.purpleLoot = 0
        stats.estimatedGold = 0
    end
    MasterThief.UpdateHUDContent()
end

function MasterThief.CheckDailyReset()
    if not MasterThief.savedVars then return end
    
    local currentTime = GetTimeStamp()
    local dailyResetOffset = 21600 
    local currentDayId = math.floor((currentTime - dailyResetOffset) / 86400)

    if MasterThief.savedVars.lastResetDay == 0 then
        MasterThief.savedVars.lastResetDay = currentDayId
    elseif MasterThief.savedVars.lastResetDay ~= currentDayId then
        MasterThief.savedVars.lastResetDay = currentDayId
        MasterThief.ResetSessionTimer()
    end
end

function MasterThief.GetActiveCharacterStats()
    if not MasterThief.savedVars then return nil end
    MasterThief.savedVars.charStats = MasterThief.savedVars.charStats or {}
    
    local charName = GetUnitName("player")
    if not charName or charName == "" then charName = "Default" end
    
    if not MasterThief.savedVars.charStats[charName] then
        MasterThief.savedVars.charStats[charName] = {
            totalStolen = 0,
            whiteJunkDestroyed = 0,
            greenLoot = 0,
            blueLoot = 0,
            purpleLoot = 0,
            estimatedGold = 0,
        }
    end
    return MasterThief.savedVars.charStats[charName]
end

-----------------------------------------------------------
-- VALIDATE TREASURE
-----------------------------------------------------------
local function IsValidTreasure(bagId, slotIndex, link)
    if not link or link == "" then return false end
    if not MasterThief.SafeIsItemStolen(bagId, slotIndex) then return false end

    local itemType = 0
    if type(GetItemLinkItemType) == "function" then
        pcall(function() itemType = GetItemLinkItemType(link) or 0 end)
    end

    local quality = MasterThief.SafeGetItemQuality(bagId, slotIndex, link)
    
    if itemType == ITEMTYPE_TREASURE or (quality >= 2 and quality <= 5) then
        return true
    end

    return false
end

-----------------------------------------------------------
-- AUTO-SELL TO FENCES LOGIC (EVENT_OPEN_FENCE)
-----------------------------------------------------------
local function OnFenceOpen(eventCode)
    if not MasterThief.savedVars then return end
    if not MasterThief.savedVars.autoSellFences then return end

    local maxLimit, used, remaining, sellsText = MasterThief.SafeGetFenceSellTransactionInfo()
    
    if remaining and remaining <= 0 then
        if MasterThief.savedVars.announceInChat then
            CHAT_ROUTER:AddSystemMessage("|cFF6666[MasterThief]|r Daily fence transaction limit reached! Skipping auto-sell.")
        end
        return
    end

    local bagId = BAG_BACKPACK
    local totalSlots = (type(GetBagSize) == "function" and GetBagSize(bagId)) or 200
    local delay = 0
    local soldCount = 0

    local targetQualities = { 4, 3, 2 }

    for _, targetQuality in ipairs(targetQualities) do
        for slotIndex = 0, totalSlots - 1 do
            local link = (type(GetItemLink) == "function") and GetItemLink(bagId, slotIndex) or ""
            
            if link and link ~= "" and MasterThief.SafeIsItemStolen(bagId, slotIndex) then
                local itemType = 0
                if type(GetItemLinkItemType) == "function" then
                    pcall(function() itemType = GetItemLinkItemType(link) or 0 end)
                end

                -- Skip motifs, recipes, and furnishing items from auto-selling
                local isExemptFromFence = (itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or 
                                           itemType == ITEMTYPE_RECIPE or 
                                           itemType == ITEMTYPE_FURNISHING)

                if not isExemptFromFence then
                    local quality = MasterThief.SafeGetItemQuality(bagId, slotIndex, link)
                    if quality >= 4 then quality = 4 end

                    if IsValidTreasure(bagId, slotIndex, link) and quality == targetQuality then
                        local currentStackSize = MasterThief.SafeGetItemStackCount(bagId, slotIndex)
                        
                        local capturedSlot = slotIndex
                        local capturedStack = currentStackSize
                        local capturedLink = link

                        zo_callLater(function()
                            if type(SellInventoryItem) == "function" then
                                SellInventoryItem(bagId, capturedSlot, capturedStack)
                                if MasterThief.savedVars.announceInChat then
                                    CHAT_ROUTER:AddSystemMessage(string_format("|c00FF00[MasterThief]|r Sold: %s x%d", capturedLink, capturedStack))
                                end
                            end
                        end, delay)
                        
                        soldCount = soldCount + 1
                        delay = delay + 50
                    end
                end
            end
        end
    end

    if soldCount > 0 and MasterThief.savedVars.announceInChat then
        zo_callLater(function()
            CHAT_ROUTER:AddSystemMessage(string_format("|c00FF00[MasterThief]|r Finished queuing |cFFD700%d|r items to sell.", soldCount))
        end, delay + 25)
    end
    
    zo_callLater(function()
        MasterThief.ScanExistingInventory()
    end, delay + 50)
end

-----------------------------------------------------------
-- LAUNDER EVENT HANDLER (EVENT_OPEN_LAUNDER)
-----------------------------------------------------------
local function OnLaunderOpen(eventCode)
    -- Reserved placeholder for launder actions if needed
end

-----------------------------------------------------------
-- SCAN EXISTING INVENTORY
-----------------------------------------------------------
function MasterThief.ScanExistingInventory()
    if not MasterThief.savedVars then return end
    local stats = MasterThief.GetActiveCharacterStats()
    
    stats.greenLoot = 0
    stats.blueLoot = 0
    stats.purpleLoot = 0
    stats.estimatedGold = 0
    stats.totalStolen = 0

    local treasureValues = {
        [2] = 100,  -- Green = 100g
        [3] = 250,  -- Blue = 250g
        [4] = 500,  -- Purple = 500g
    }

    local bagId = BAG_BACKPACK
    local totalSlots = (type(GetBagSize) == "function" and GetBagSize(bagId)) or 200

    for slotIndex = 0, totalSlots - 1 do
        local link = (type(GetItemLink) == "function") and GetItemLink(bagId, slotIndex) or ""
        
        if link and link ~= "" then
            if IsValidTreasure(bagId, slotIndex, link) then
                local quality = MasterThief.SafeGetItemQuality(bagId, slotIndex, link)
                local stackCount = MasterThief.SafeGetItemStackCount(bagId, slotIndex)

                local itemName = (type(GetItemLinkName) == "function") and GetItemLinkName(link) or ""
                if string_find(string_lower(itemName), "red squirrel paw") then
                    quality = 3 
                end

                stats.totalStolen = stats.totalStolen + 1

                if quality == 2 then
                    stats.greenLoot = stats.greenLoot + stackCount
                elseif quality == 3 then
                    stats.blueLoot = stats.blueLoot + stackCount
                elseif quality >= 4 then
                    stats.purpleLoot = stats.purpleLoot + stackCount
                end
                
                local treasureValue = treasureValues[quality] or 100
                stats.estimatedGold = stats.estimatedGold + (treasureValue * stackCount)
            end
        end
    end
    MasterThief.UpdateHUDContent()
end

------------------------------------------------------------
-- INVENTORY EVENT TRACKER
-----------------------------------------------------------
function MasterThief.OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNew)
    if not MasterThief.savedVars then return end
    if bagId ~= BAG_BACKPACK then return end

    MasterThief.CheckDailyReset()
    MasterThief.ScanExistingInventory()

    if isNew then
        local link = (type(GetItemLink) == "function") and GetItemLink(bagId, slotIndex) or ""
        if link == "" then return end

        local itemName = (type(GetItemLinkName) == "function") and GetItemLinkName(link) or ""
        local isQuestItem = false
        if type(IsItemQuest) == "function" then
            pcall(function() isQuestItem = IsItemQuest(bagId, slotIndex) end)
        end
        
        local isStolen = MasterThief.SafeIsItemStolen(bagId, slotIndex)
        local quality = MasterThief.SafeGetItemQuality(bagId, slotIndex, link)
        local stackCount = MasterThief.SafeGetItemStackCount(bagId, slotIndex)
        
        if string_find(string_lower(itemName), "red squirrel paw") then
            quality = 3
        end

        local itemType = 0
        if type(GetItemLinkItemType) == "function" then
            pcall(function() itemType = GetItemLinkItemType(link) or 0 end)
        end

        local isLockpick = (itemType == ITEMTYPE_TOOL) or string_find(link, "item:44874") or string_match(string_lower(itemName), "lockpick")
        
        local isProtectedMaterial = (itemType == ITEMTYPE_CRAFTING_MAT_ADDITIVE or 
                                   itemType == ITEMTYPE_WEAPON_TRAIT_MAT or 
                                   itemType == ITEMTYPE_ARMOR_TRAIT_MAT or 
                                   itemType == ITEMTYPE_ENCHANTING_RUNE or 
                                   itemType == ITEMTYPE_BLACKSMITHING_BOOSTER or 
                                   itemType == ITEMTYPE_CLOTHIER_BOOSTER or 
                                   itemType == ITEMTYPE_WOODWORKING_BOOSTER or 
                                   itemType == ITEMTYPE_JEWELRYCRAFTING_BOOSTER or 
                                   itemType == ITEMTYPE_JEWELRYCRAFTING_MAT or 
                                   itemType == ITEMTYPE_INGREDIENT or 
                                   itemType == ITEMTYPE_POTION or 
                                   itemType == ITEMTYPE_POISON or
                                   itemType == ITEMTYPE_STYLE_MATERIAL or
                                   itemType == ITEMTYPE_TOOL or
                                   itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or
                                   itemType == ITEMTYPE_RECIPE or
                                   itemType == ITEMTYPE_FURNISHING or
                                   isLockpick)

        local isGear = (itemType == ITEMTYPE_WEAPON or 
                        itemType == ITEMTYPE_ARMOR or 
                        itemType == ITEMTYPE_ENCHANTMENT or 
                        itemType == ITEMTYPE_JEWELRY or
                        itemType == ITEMTYPE_SHIELD)

        if not isQuestItem and not isProtectedMaterial and isStolen then
            if MasterThief.savedVars.showTimer and not MasterThief.sessionStartTime then
                MasterThief.sessionStartTime = GetTimeStamp()
            end
        end

        -- Read exact current boolean settings
        local destroyGreens = (MasterThief.savedVars.autoDestroyGreens == true)
        local destroyBlues = (MasterThief.savedVars.autoDestroyBlues == true)
        local destroyPurples = (MasterThief.savedVars.autoDestroyPurples == true)

        local shouldDestroyJunk = (not isQuestItem and not isProtectedMaterial and isStolen and quality <= 1)
        local shouldDestroyGear = (not isQuestItem and isStolen and isGear)
        local shouldDestroyGreen = (not isQuestItem and not isProtectedMaterial and isStolen and quality == 2 and destroyGreens)
        local shouldDestroyBlue = (not isQuestItem and not isProtectedMaterial and isStolen and quality == 3 and destroyBlues)
        local shouldDestroyPurple = (not isQuestItem and not isProtectedMaterial and isStolen and quality >= 4 and destroyPurples)

        if shouldDestroyJunk or shouldDestroyGear or shouldDestroyGreen or shouldDestroyBlue or shouldDestroyPurple then
            local stats = MasterThief.GetActiveCharacterStats()
            stats.whiteJunkDestroyed = (tonumber(stats.whiteJunkDestroyed) or 0) + stackCount
            
            if MasterThief.savedVars.announceInChat then
                local destroyTypeLabel = "Destroyed Stolen Item"
                if shouldDestroyGear then destroyTypeLabel = "Destroyed Stolen Gear"
                elseif shouldDestroyGreen then destroyTypeLabel = "Destroyed Stolen Green"
                elseif shouldDestroyBlue then destroyTypeLabel = "Destroyed Stolen Blue"
                elseif shouldDestroyPurple then destroyTypeLabel = "Destroyed Stolen Purple"
                elseif shouldDestroyJunk then destroyTypeLabel = "Destroyed Stolen Junk" end
                
                CHAT_ROUTER:AddSystemMessage(string_format("|cFF6666[MasterThief] %s:|r %s", destroyTypeLabel, link))
            end
            
            if type(DestroyItem) == "function" then
                DestroyItem(bagId, slotIndex)
            end
            MasterThief.UpdateHUDContent()
            return
        end

        if quality >= 2 and MasterThief.savedVars.playLootSound and type(PlaySound) == "function" then
            PlaySound(SOUNDS.TELVAR_GAINED)
        end
    end
end

-----------------------------------------------------------
-- HUD DISPLAY & POSITIONS
-----------------------------------------------------------
function MasterThief.ApplyPosition()
    if not MasterThief.hudFrame then return end
    MasterThief.hudFrame:ClearAnchors()
    MasterThief.hudFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, MasterThief.savedVars.posX or 60, MasterThief.savedVars.posY or 100)
end

function MasterThief.ApplyBackgroundColor()
    if not MasterThief.hudBg then return end
    MasterThief.hudBg:SetColor(
        MasterThief.savedVars.bgColorR or 0.05,
        MasterThief.savedVars.bgColorG or 0.05,
        MasterThief.savedVars.bgColorB or 0.1,
        MasterThief.savedVars.bgColorA or 0.75
    )
end

function MasterThief.CreateHUD()
    if MasterThief.hudFrame then return end

    local wm = WINDOW_MANAGER
    local mainFrame = wm:CreateTopLevelWindow("MasterThiefHUD")
    mainFrame:SetMovable(true)
    mainFrame:SetMouseEnabled(true)
    mainFrame:SetClampedToScreen(true)
    MasterThief.hudFrame = mainFrame

    local bg = wm:CreateControl("$(parent)BG", mainFrame, CT_TEXTURE)
    bg:SetAnchorFill(mainFrame)
    MasterThief.hudBg = bg
    MasterThief.ApplyBackgroundColor()

    mainFrame:SetHandler("OnMoveStop", function(self)
        MasterThief.savedVars.posX = self:GetLeft()
        MasterThief.savedVars.posY = self:GetTop()
        if LibAddonMenu2 and MasterThief.optionsPanel then
            CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", MasterThief.optionsPanel)
        end
    end)

    local content = wm:CreateControl("$(parent)Content", mainFrame, CT_LABEL)
    content:SetAnchor(TOPLEFT, mainFrame, TOPLEFT, 12, 12)
    MasterThief.contentLabel = content

    MasterThief.ApplyPosition()
    MasterThief.UpdateHUDContent()
    MasterThief.hudFrame:SetHidden(not MasterThief.savedVars.showHUD)
end

function MasterThief.UpdateHUDContent()
    if not MasterThief.contentLabel or not MasterThief.hudFrame then return end

    MasterThief.contentLabel:SetFont(MasterThief.GetCustomFont(MasterThief.savedVars.fontSize or 11))
    local buffer = {}

    table_insert(buffer, "|cFFD700- MASTER THIEF : CRIME TRACKER -|r")
    
    if MasterThief.savedVars.showSessionStats ~= false then
        local stats = MasterThief.GetActiveCharacterStats()
        local timerText = ""
        if MasterThief.savedVars.showTimer ~= false then
            timerText = string_format("Time: |cFFD700%s|r   ", MasterThief.GetFormattedSessionTime())
        end

        table_insert(buffer, string_format("%sDestroyed: |cFF6666%d|r   Green: |c2DC800%d|r   Blue: |c3A92FF%d|r   Purple: |cA335EE%d|r", 
            timerText,
            stats.whiteJunkDestroyed or 0, 
            stats.greenLoot or 0, 
            stats.blueLoot or 0, 
            stats.purpleLoot or 0
        ))

        local _, _, _, sellsText = MasterThief.SafeGetFenceSellTransactionInfo()

        table_insert(buffer, string_format("Est. Value: |cFFD700%d g|r   Sells: |c00BFFF%s|r", stats.estimatedGold or 0, sellsText or "N/A"))
    end

    MasterThief.contentLabel:SetText(table.concat(buffer, "\n"))
    MasterThief.hudFrame:SetDimensions(MasterThief.contentLabel:GetTextWidth() + 24, MasterThief.contentLabel:GetTextHeight() + 24)
end

-----------------------------------------------------------
-- SETTINGS PANEL (LibAddonMenu2)
-----------------------------------------------------------
function MasterThief.CreateSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = "MasterThief_OptionsPanel"
    local panelData = {
        type = "panel",
        name = "Master Thief",
        displayName = "|cFFD700Master |c00BFFFThief |cFF69B4Settings|r",
        author = "|c00FF00Thief|r",
        version = "2.33",
        slashCommand = "/thiefsettings",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    MasterThief.optionsPanel = LAM:RegisterAddonPanel(panelName, panelData)

    local optionsData = {
        {
            type = "description",
            text = "|cFFD700Track stolen treasures, auto-destroy worthless white trash and stolen gear, and monitor daily fence transaction limits directly on your HUD!|r",
        },
        {
            type = "header",
            name = "|c00BFFFDisplay & Notifications|r",
        },
        {
            type = "checkbox",
            name = "|cFFFFFFShow Stealing HUD|r",
            tooltip = "Toggles the on-screen crime stats display.",
            getFunc = function() return MasterThief.savedVars.showHUD end,
            setFunc = function(value)
                MasterThief.savedVars.showHUD = value
                if MasterThief.hudFrame then MasterThief.hudFrame:SetHidden(not value) end
            end,
            default = MasterThief.defaultSettings.showHUD,
        },
        {
            type = "checkbox",
            name = "|c00FF00Auto-Sell Treasures to Fence|r",
            tooltip = "Automatically sells stolen treasures to the fence in order of rarity (Purple -> Blue -> Green).",
            getFunc = function() return MasterThief.savedVars.autoSellFences end,
            setFunc = function(value) MasterThief.savedVars.autoSellFences = value end,
            default = MasterThief.defaultSettings.autoSellFences,
        },
        {
            type = "header",
            name = "|cFF6666Auto-Destroy Specific Rarity Toggles|r",
        },
        {
            type = "checkbox",
            name = "|c2DC800Auto-Destroy Stolen Greens|r",
            tooltip = "Automatically delete stolen green items on pick-up.",
            getFunc = function() return (MasterThief.savedVars.autoDestroyGreens == true) end,
            setFunc = function(value) MasterThief.savedVars.autoDestroyGreens = (value == true) end,
            default = MasterThief.defaultSettings.autoDestroyGreens,
        },
        {
            type = "checkbox",
            name = "|c3A92FFAuto-Destroy Stolen Blues|r",
            tooltip = "Automatically delete stolen blue items on pick-up.",
            getFunc = function() return (MasterThief.savedVars.autoDestroyBlues == true) end,
            setFunc = function(value) MasterThief.savedVars.autoDestroyBlues = (value == true) end,
            default = MasterThief.defaultSettings.autoDestroyBlues,
        },
        {
            type = "checkbox",
            name = "|cA335EEAuto-Destroy Stolen Purples|r",
            tooltip = "Automatically delete stolen purple items on pick-up.",
            getFunc = function() return (MasterThief.savedVars.autoDestroyPurples == true) end,
            setFunc = function(value) MasterThief.savedVars.autoDestroyPurples = (value == true) end,
            default = MasterThief.defaultSettings.autoDestroyPurples,
        },
        {
            type = "checkbox",
            name = "|cFF6666Announce Actions in Chat|r",
            tooltip = "Prints notification logs in chat when auto-selling or auto-destroying items.",
            getFunc = function() return MasterThief.savedVars.announceInChat end,
            setFunc = function(value) MasterThief.savedVars.announceInChat = value end,
            default = MasterThief.defaultSettings.announceInChat,
        },
        {
            type = "checkbox",
            name = "|cA335EEPlay Audio on Valuable Loot|r",
            tooltip = "Plays a subtle sound cue when you steal a Green, Blue, or Purple quality item.",
            getFunc = function() return MasterThief.savedVars.playLootSound end,
            setFunc = function(value) MasterThief.savedVars.playLootSound = value end,
            default = MasterThief.defaultSettings.playLootSound,
        },
        {
            type = "checkbox",
            name = "|cFFD700Show Session Timer|r",
            tooltip = "Tracks how long your current crime spree has lasted.",
            getFunc = function() return MasterThief.savedVars.showTimer end,
            setFunc = function(value)
                MasterThief.savedVars.showTimer = value
                if not value then MasterThief.ResetSessionTimer() else MasterThief.UpdateHUDContent() end
            end,
            default = MasterThief.defaultSettings.showTimer,
        },
        {
            type = "header",
            name = "|c00BFFFHUD Customization|r",
        },
        {
            type = "colorpicker",
            name = "|cFFFFFFHUD Backdrop Color|r",
            tooltip = "Customize the background color and transparency of the HUD.",
            getFunc = function() 
                return MasterThief.savedVars.bgColorR, MasterThief.savedVars.bgColorG, MasterThief.savedVars.bgColorB, MasterThief.savedVars.bgColorA 
            end,
            setFunc = function(r, g, b, a)
                MasterThief.savedVars.bgColorR = r
                MasterThief.savedVars.bgColorG = g
                MasterThief.savedVars.bgColorB = b
                MasterThief.savedVars.bgColorA = a
                MasterThief.ApplyBackgroundColor()
            end,
            default = {
                r = MasterThief.defaultSettings.bgColorR,
                g = MasterThief.defaultSettings.bgColorG,
                b = MasterThief.defaultSettings.bgColorB,
                a = MasterThief.defaultSettings.bgColorA,
            },
        },
        {
            type = "slider",
            name = "|cFFFFFFFont Size|r",
            min = 9, max = 50, step = 1,
            getFunc = function() return MasterThief.savedVars.fontSize end,
            setFunc = function(value) MasterThief.savedVars.fontSize = value; MasterThief.UpdateHUDContent() end,
            default = MasterThief.defaultSettings.fontSize,
        },
        {
            type = "slider",
            name = "|cFFFFFFX Position|r",
            min = 0, max = 2000, step = 5,
            getFunc = function() return MasterThief.savedVars.posX end,
            setFunc = function(value) MasterThief.savedVars.posX = value; MasterThief.ApplyPosition() end,
            default = MasterThief.defaultSettings.posX,
        },
        {
            type = "slider",
            name = "|cFFFFFFY Position|r",
            min = 0, max = 1200, step = 5,
            getFunc = function() return MasterThief.savedVars.posY end,
            setFunc = function(value) MasterThief.savedVars.posY = value; MasterThief.ApplyPosition() end,
            default = MasterThief.defaultSettings.posY,
        },
    }

    LAM:RegisterOptionControls(panelName, optionsData)
end

-----------------------------------------------------------
-- INITIALIZATION
-----------------------------------------------------------
function MasterThief.Initialize()
    MasterThief.savedVars = ZO_SavedVars:NewAccountWide("MasterThief_SavedVars", 1, nil, MasterThief.defaultSettings)
    
    MasterThief.CheckDailyReset()
    MasterThief.CreateHUD()
    MasterThief.CreateSettingsPanel()

    MasterThief.ScanExistingInventory()

    EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, MasterThief.OnInventorySlotUpdate)
    EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_OPEN_FENCE, OnFenceOpen)
    EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_OPEN_LAUNDER, OnLaunderOpen)

    EVENT_MANAGER:RegisterForUpdate(MasterThief.name .. "_TimerLoop", 1000, function()
        if MasterThief.savedVars and MasterThief.savedVars.showHUD and MasterThief.savedVars.showTimer then
            MasterThief.UpdateHUDContent()
        end
    end)

    SLASH_COMMANDS["/thief"] = function()
        if MasterThief.hudFrame then
            local newState = not MasterThief.savedVars.showHUD
            MasterThief.savedVars.showHUD = newState
            MasterThief.hudFrame:SetHidden(not newState)
        end
    end

    SLASH_COMMANDS["/thiefreset"] = function()
        MasterThief.ResetSessionTimer()
    end
end

EVENT_MANAGER:RegisterForEvent(MasterThief.name, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= MasterThief.name then return end
    MasterThief.Initialize()
    EVENT_MANAGER:UnregisterForEvent(MasterThief.name, EVENT_ADD_ON_LOADED)
end)