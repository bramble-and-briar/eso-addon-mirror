-- GearTracker v2.67
local ADDON = { name = "GearTracker" }

local SV, resultsWindow, scrollChild
local searchResults = {} 
local scrollOffset = 0
local rosterOffset = 0 -- Tracks scrolling for the roster grid
local activeFilterType = "ALL" 
local searchText = "" 

local TABLE_INSERT = table.insert
local STR_LOWER = string.lower
local STR_FIND = string.find

-----------------------------------------------------------
-- 1. HELPERS
-----------------------------------------------------------
local function GetStickerStatus(link)
    if not link or link == "" then return "" end
    if not GetItemLinkSetCollectionId then return "" end
    local hasSet = GetItemLinkSetInfo(link, false)
    if not hasSet then return "" end

    local setId = GetItemLinkSetCollectionId(link)
    local slot = GetItemLinkSetCollectionSlot(link)
    if setId and setId > 0 and slot then
        if not IsItemSetCollectionSlotUnlocked(setId, slot) then
            return "|cFF00FF[NEW!]|r " 
        end
    end
    return ""
end

local function GetLiveWeightTag(item)
    if not item then return "" end
    if item.weight and item.weight ~= "" then 
        if item.weight == "Light" or item.weight == "Medium" or item.weight == "Heavy" or item.weight == "Shield" then
            return string.format("|cFF9900[%s]|r ", item.weight) 
        end
        return string.format("|c888888[%s]|r ", item.weight)
    end
    return ""
end

-----------------------------------------------------------
-- 2. UI LOGIC & OVERLAY RENDERING
-----------------------------------------------------------
local function MoveResultsWindow()
    if not resultsWindow or not SV then return end
    if resultsWindow.ClearAnchors then resultsWindow:ClearAnchors() end
    if resultsWindow.SetAnchor then resultsWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, SV.posX or 300, SV.posY or 200) end
end

local function RefreshLabelSetup()
    if not resultsWindow then return end
    scrollChild = { controls = {} }
    
    local poolSize = 16

    for i = 1, poolSize do
        local lblName = "GT_ItemLabel_" .. i
        local lbl = WINDOW_MANAGER:GetControlByName(lblName) or WINDOW_MANAGER:CreateControl(lblName, resultsWindow, CT_LABEL)
        lbl:SetWrapMode(TEXT_WRAP_MODE_NONE)
        scrollChild.controls[i] = lbl
    end
end

local function UpdateResultsUI()
    if not resultsWindow or not scrollChild or not SV then return end
    
    local fontSize = SV.fontSize or 24
    local lineHeight = fontSize + 8 
    local fontString = string.format("$(MEDIUM_FONT)|%d|soft-shadow-thin", fontSize)
    
    local totalFound = #searchResults
    local maxDisplayRows = SV.visibleCount or 8
    
    local maxOffset = math.max(0, totalFound - maxDisplayRows)
    if scrollOffset > maxOffset then scrollOffset = maxOffset end
    if scrollOffset < 0 then scrollOffset = 0 end

    local activeRows = math.min(totalFound - scrollOffset, maxDisplayRows)
    
    local calculatedHeight = (lineHeight * (activeRows + 1)) + 25
    resultsWindow:SetHeight(calculatedHeight)

    local maxTextWidth = 300

    for i = 1, #scrollChild.controls do
        local lbl = scrollChild.controls[i]
        lbl:SetFont(fontString)
        lbl:SetHeight(lineHeight)
        lbl:ClearAnchors()
        lbl:SetAnchor(TOPLEFT, resultsWindow, TOPLEFT, 20, 12 + ((i - 1) * lineHeight))
        
        if i == 1 then
            lbl:SetHidden(false)
            local header = string.format("|cFFD700GearTracker Search|r |c888888[Filter: %s]|r", activeFilterType)
            if searchText and searchText ~= "" then 
                header = header .. string.format(" |c00FFCC\"%s\"|r", searchText) 
            end
            
            local countText = string.format("— Found: %d", totalFound)
            if totalFound > maxDisplayRows then
                countText = string.format("— Found: %d (Showing %d-%d)", totalFound, scrollOffset + 1, math.min(totalFound, scrollOffset + maxDisplayRows))
            end
            
            lbl:SetText(string.format("%s  |cFFFFFF%s|r  |c777777(Sync: %s)|r", header, countText, SV.lastScan or "Never"))
            lbl.itemLink = nil
            
            local textWidth = lbl:GetTextWidth()
            if textWidth > maxTextWidth then maxTextWidth = textWidth end
        else
            local dataIndex = scrollOffset + (i - 1)
            local itemData = searchResults[dataIndex]
            
            if itemData and (i - 1) <= activeRows then
                lbl:SetHidden(false)
                lbl:SetText(itemData.text)
                lbl.itemLink = itemData.link 
                
                local textWidth = lbl:GetTextWidth()
                if textWidth > maxTextWidth then maxTextWidth = textWidth end
            else
                lbl:SetHidden(true)
                lbl:SetText("")
                lbl.itemLink = nil
            end
        end
    end

    resultsWindow:SetWidth(maxTextWidth + 40)
end

local function ApplyInventoryFilter()
    searchResults = {}
    scrollOffset = 0
    
    if not searchText or searchText == "" then
        UpdateResultsUI()
        return
    end
    
    if not SV or not SV.chars then return end
    local query = STR_LOWER(searchText)

    for char, data in pairs(SV.chars) do
        if type(data) == "table" then
            for _, loc in ipairs({"equipped", "bag"}) do
                local itemGroup = data[loc] or {}
                for _, item in ipairs(itemGroup) do
                    if activeFilterType == "ALL" or item.type == activeFilterType then
                        local nameMatch = STR_FIND(STR_LOWER(item.name or ""), query, 1, true) 
                                       or STR_FIND(STR_LOWER(item.trait or ""), query, 1, true) 
                                       or STR_FIND(STR_LOWER(char), query, 1, true)
                        if nameMatch then
                            local sticker = GetStickerStatus(item.link)
                            local weightTag = GetLiveWeightTag(item)
                            TABLE_INSERT(searchResults, {
                                link = item.link,
                                text = string.format("|cBBBBBB[%s]|r |c00CCFF%s|r: %s%s%s |c888888(%s)|r", char, loc:upper(), weightTag, sticker, item.link, item.trait)
                            })
                        end
                    end
                end
            end
        end
    end

    for _, item in ipairs(SV.bank or {}) do
        if activeFilterType == "ALL" or item.type == activeFilterType then
            local nameMatch = STR_FIND(STR_LOWER(item.name or ""), query, 1, true) 
                           or STR_FIND(STR_LOWER(item.trait or ""), query, 1, true)
            if nameMatch then
                local sticker = GetStickerStatus(item.link)
                local weightTag = GetLiveWeightTag(item)
                TABLE_INSERT(searchResults, {
                    link = item.link,
                    text = string.format("|cFFD700[BANK]|r %s%s%s |c888888(%s)|r", weightTag, sticker, item.link, item.trait)
                })
            end
        end
    end

    UpdateResultsUI()
end

local function DestroyAllExistingChildren(parent)
    if not parent or not parent.GetNumChildren then return end
    local num = parent:GetNumChildren()
    for i = num, 1, -1 do
        local child = parent:GetChild(i)
        if child then
            child:SetHidden(true)
            if child.SetText then child:SetText("") end
            if child.ClearAnchors then child:ClearAnchors() end
        end
    end
end

local function CreateResultsWindow()
    local win = WINDOW_MANAGER:GetControlByName("GearTracker_ResultsWindow")
    if not win then
        win = WINDOW_MANAGER:CreateTopLevelWindow("GearTracker_ResultsWindow")
    end
    
    DestroyAllExistingChildren(win)

    win:SetClampedToScreen(true)
    win:SetHidden(true) 
    
    local bg = WINDOW_MANAGER:CreateControl("GearTracker_BG", win, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.85)
    bg:SetEdgeColor(0.3, 0.3, 0.3, 1)
    bg:SetEdgeTexture("", 1, 1, 1)
    
    resultsWindow = win
    RefreshLabelSetup()
    MoveResultsWindow()
end

-----------------------------------------------------------
-- 3. SCANNING LOGIC
-----------------------------------------------------------
local function ScanBagContents(bagId, storageTarget)
    if not GetBagSize or not GetItemLink then return end
    
    -- Ensure the global game enums are safely referenced
    local ARMOR_LIGHT  = ARMOR_TYPE_LIGHT  or 1
    local ARMOR_MEDIUM = ARMOR_TYPE_MEDIUM or 2
    local ARMOR_HEAVY  = ARMOR_TYPE_HEAVY  or 3
    local ARMOR_NONE   = ARMOR_TYPE_NONE   or 0

    for slot = 0, GetBagSize(bagId) - 1 do
        local link = GetItemLink(bagId, slot)
        if link ~= "" then
            local itemType = GetItemLinkItemType(link)
            local equipType = GetItemLinkEquipType(link)
            local internalCategory = nil
            local weightType = ""

            if itemType == ITEMTYPE_WEAPON then 
                internalCategory = "WEAPON"
                weightType = "Weapon"
                
            elseif equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING or itemType == ITEMTYPE_JEWELRY then
                internalCategory = "JEWELRY"
                weightType = "Jewelry"
                
            elseif itemType == ITEMTYPE_ARMOR then 
                internalCategory = "ARMOR"
                
                if equipType == EQUIP_TYPE_OFF_HAND then
                    weightType = "Shield"
                else
                    -- Safely fetch and evaluate the armor weight constant
                    local armorType = GetItemLinkArmorType(link)
                    if armorType == ARMOR_LIGHT then
                        weightType = "Light"
                    elseif armorType == ARMOR_MEDIUM then
                        weightType = "Medium"
                    elseif armorType == ARMOR_HEAVY then
                        weightType = "Heavy"
                    elseif armorType == ARMOR_NONE then
                        weightType = "None" -- For non-combat clothes or costumes
                    else
                        weightType = "Unknown"
                    end
                end
            end

            if internalCategory then
                -- Safely handle items that have no trait
                local traitType = GetItemLinkTraitInfo(link)
                local traitString = ""
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    traitString = GetString("SI_ITEMTRAITTYPE", traitType)
                end

                table.insert(storageTarget, {
                    link = link, 
                    name = zo_strformat("<<1>>", GetItemLinkName(link)), 
                    trait = traitString,
                    type = internalCategory,
                    weight = weightType 
                })
            end
        end
    end
end



_G.AutoScanCharacter = function()
    if not SV or not GetUnitName then return end
    local char = zo_strformat("<<1>>", GetUnitName("player"))
    
    SV.chars[char] = { equipped = {}, bag = {} }
    SV.lastScan = GetTimeString()
    
    ScanBagContents(BAG_WORN, SV.chars[char].equipped)
    ScanBagContents(BAG_BACKPACK, SV.chars[char].bag)

    if IsBankOpen and IsBankOpen() then
        SV.bank = {}
        ScanBagContents(BAG_BANK, SV.bank)
        if IsESOPlusSubscriber and IsESOPlusSubscriber() then
            ScanBagContents(BAG_SUBSCRIBER_BANK, SV.bank)
        end
    end
end

-----------------------------------------------------------
-- 4. SETTINGS PANEL (LAM2)
-----------------------------------------------------------
local function CreateLAMPanel()
    if not LibAddonMenu2 then return end
    
    local panelData = { 
        type = "panel", 
        name = "GearTracker_Panel", 
        displayName = "|cFFD700Gear Tracker Settings|r", 
        author = "|c00FFCCthewiz|r", 
        version = "|c00FF002.67|r",
        registerForRefresh = true,
    }

    local optionsData = {

        {
            type = "submenu",
            name = "|c00CCFF✦ Search & Controls|r",
            controls = {
                {
                    type = "editbox",
                    name = "Search Query",
                    getFunc = function() return searchText end,
                    setFunc = function(text) 
                        searchText = text
                        ApplyInventoryFilter()
                        if resultsWindow then resultsWindow:SetHidden(false) end
                    end,
                    isMultiline = false,
                    width = "full",
                },
                {
                    type = "button",
                    name = "▲ Search Scroll Up",
                    func = function()
                        scrollOffset = math.max(0, scrollOffset - 1)
                        UpdateResultsUI()
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "▼ Search Scroll Down",
                    func = function()
                        local maxOffset = math.max(0, #searchResults - (SV.visibleCount or 8))
                        scrollOffset = math.min(maxOffset, scrollOffset + 1)
                        UpdateResultsUI()
                    end,
                    width = "half",
                },
                {
                    type = "dropdown",
                    name = "Filter Gear Type",
                    choices = {"ALL", "ARMOR", "WEAPON", "JEWELRY"},
                    getFunc = function() return activeFilterType end,
                    setFunc = function(value) 
                        activeFilterType = value
                        ApplyInventoryFilter()
                        if resultsWindow then resultsWindow:SetHidden(false) end
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = "|c00FFCCRun Inventory Scan|r",
                    func = function() 
                        _G.AutoScanCharacter()
                        ApplyInventoryFilter()
                        if resultsWindow then resultsWindow:SetHidden(false) end
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "|cFF6666Close Overlay|r",
                    func = function() if resultsWindow then resultsWindow:SetHidden(true) end end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = "|cFFCC00⚙ Overlay Settings|r",
            controls = {
                {
                    type = "slider",
                    name = "Font Size",
                    min = 16, max = 36, step = 1,
                    getFunc = function() return SV.fontSize or 24 end,
                    setFunc = function(v) 
                        SV.fontSize = v 
                        MoveResultsWindow()
                        UpdateResultsUI() 
                    end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Display Rows",
                    min = 1, max = 15, step = 1,
                    getFunc = function() return SV.visibleCount end,
                    setFunc = function(v) 
                        SV.visibleCount = v 
                        RefreshLabelSetup()
                        MoveResultsWindow()
                        UpdateResultsUI() 
                    end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Position X",
                    min = 0, max = 2500, step = 10,
                    getFunc = function() return SV.posX end,
                    setFunc = function(v) SV.posX = v; MoveResultsWindow() end,
                    width = "half",
                },
                {
                    type = "slider",
                    name = "Position Y",
                    min = 0, max = 1500, step = 10,
                    getFunc = function() return SV.posY end,
                    setFunc = function(v) SV.posY = v; MoveResultsWindow() end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = "|c00FF99🛡 Account Data Repository|r",
            controls = {
                -- Added dedicated Roster Scroll Controls for gamepad/keyboard users
                {
                    type = "button",
                    name = "▲ Roster Scroll Up",
                    func = function()
                        rosterOffset = math.max(0, rosterOffset - 2)
                        -- Forces the LAM settings panel control to refresh its description
                        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "GearTracker_Panel")
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "▼ Roster Scroll Down",
                    func = function()
                        rosterOffset = rosterOffset + 2
                        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", "GearTracker_Panel")
                    end,
                    width = "half",
                },
                {
                    type = "description",
                    text = function()
                        local names = {}
                        for n in pairs(SV.chars or {}) do TABLE_INSERT(names, n) end
                        table.sort(names)
                        
                        local totalChars = #names
                        -- Bound roster offset to valid range
                        local maxRosterOffset = math.max(0, totalChars - 10)
                        if rosterOffset > maxRosterOffset then rosterOffset = maxRosterOffset end
                        if rosterOffset < 0 then rosterOffset = 0 end

                        local grid = string.format("|cFFD700════════ ROSTER & INVENTORY (Showing %d-%d of %d) ════════|r\n\n", math.min(totalChars, rosterOffset + 1), math.min(totalChars, rosterOffset + 10), totalChars)
                        
                        local displayedCount = 0
                        for i = 1 + rosterOffset, #names, 2 do
                            if displayedCount >= 5 then break end -- Show up to 5 rows (10 characters at a time)
                            local n1 = names[i]
                            if n1 and type(SV.chars[n1]) == "table" then
                                local count1 = #(SV.chars[n1].bag or {}) + #(SV.chars[n1].equipped or {})
                                local line = string.format("|c00FF00•|r |cFFFFFF%-14s|r |c888888(%3d items)|r", n1, count1)
                                
                                if names[i+1] and type(SV.chars[names[i+1]]) == "table" then
                                    local n2 = names[i+1]
                                    local count2 = #(SV.chars[n2].bag or {}) + #(SV.chars[n2].equipped or {})
                                    line = line .. string.format("  |c00FF00•|r |cFFFFFF%-14s|r |c888888(%3d items)|r", n2, count2)
                                end
                                grid = grid .. line .. "\n"
                                displayedCount = displayedCount + 1
                            end
                        end

                        local bankCount = (SV.bank and #SV.bank) or 0
                        local bankStatus = bankCount > 0 and string.format("|c00CCFFActive|r |c888888(%d items)|r", bankCount) or "|cFF3333Not Scanned|r"
                        
                        local footer = string.format("\n|cFFD700════════ ACCOUNT TOTALS ════════|r\n|cBBBBBBTracked Characters:|r |c00FF00%d / 20|r\n|cBBBBBBMapped Bank Cache:|r %s\n|cBBBBBBLast Global Sync:|r |cFFFFFF%s|r", totalChars, bankStatus, SV.lastScan or "Never")
                        
                        return (totalChars > 0 and grid or "No character data found.\n") .. footer
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = "|cFF2222Purge Saved Inventory Data|r",
                    warning = "Deletes stored character and bank database information!",
                    func = function() 
                        SV.chars = {}
                        SV.bank = {}
                        rosterOffset = 0
                        _G.AutoScanCharacter()
                        ApplyInventoryFilter()
                    end,
                    width = "full",
                },
            },
        },
    }
    
    LibAddonMenu2:RegisterAddonPanel("GearTracker_Panel", panelData)
    LibAddonMenu2:RegisterOptionControls("GearTracker_Panel", optionsData)
    
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel and panel:GetName() == "GearTracker_Panel" then
            if resultsWindow then resultsWindow:SetHidden(true) end
        end
    end)
end

-----------------------------------------------------------
-- 5. INITIALIZATION & EVENT REGISTRATION
-----------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON.name then return end
    
    SV = ZO_SavedVars:NewAccountWide("GearTrackerSV", 1, nil, {
        chars = {}, bank = {}, fontSize = 24, posX = 300, posY = 200, visibleCount = 8, lastScan = "Never"
    })

    if not SV.chars or type(SV.chars) ~= "table" then
        SV.chars = {}
    else
        for k, v in pairs(SV.chars) do
            if type(v) ~= "table" then
                SV.chars[k] = nil
            end
        end
    end
    if not SV.bank or type(SV.bank) ~= "table" then SV.bank = {} end

    CreateResultsWindow()
    _G.AutoScanCharacter()
    ApplyInventoryFilter() 
    CreateLAMPanel()
    
    if SCENE_MANAGER then
        local hudScene = SCENE_MANAGER:GetScene("hud")
        if hudScene then
            hudScene:RegisterCallback("StateChange", function(oldState, newState)
                if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
                    if resultsWindow then resultsWindow:SetHidden(true) end
                end
            end)
        end
    end
end)

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_RETICLE_HIDDEN_STATE_CHANGED, function(_, hidden)
    if not hidden and resultsWindow then
        resultsWindow:SetHidden(true)
    end
end)

EVENT_MANAGER:RegisterForEvent(ADDON.name, EVENT_OPEN_BANK, function() 
    _G.AutoScanCharacter() 
end)