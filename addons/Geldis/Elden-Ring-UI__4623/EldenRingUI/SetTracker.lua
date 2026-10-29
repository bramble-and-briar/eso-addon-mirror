local ADDON_NAME = "EldenRingUI"
local UI_Container = nil
local IconPool = {}
local TextPool = {}

local SLOT_OFFSETS = {
    [1] = {x = 187, y = -225}, -- Top
    [2] = {x = 187, y = -115}, -- Bottom
    [3] = {x = 281, y = -171}, -- Right
    [4] = {x = 92, y = -171},  -- Left
}

local function CreateUI()
    if UI_Container then return end
    local wm = GetWindowManager()
    UI_Container = wm:CreateTopLevelWindow("ERUI_SetTrackerControl")
    UI_Container:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, 0, 0)
    UI_Container:SetDimensions(70, 70)
    UI_Container:SetDrawLayer(DL_OVERLAY)

    local fragment = ZO_HUDFadeSceneFragment:New(UI_Container)
    if HUD_SCENE then HUD_SCENE:AddFragment(fragment) end
    if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(fragment) end
    if SIEGE_BAR_SCENE then SIEGE_BAR_SCENE:AddFragment(fragment) end
    if LOOT_SCENE then LOOT_SCENE:AddFragment(fragment) end
end

local function GetIconControl(index)
    local wm = GetWindowManager()
    if not IconPool[index] then
        local icon = wm:CreateControl("ERUI_SetTrackerIcon" .. index, UI_Container, CT_TEXTURE)
        icon:SetDimensions(70, 70)
        local offset = SLOT_OFFSETS[index]
        icon:SetAnchor(CENTER, UI_Container, BOTTOMLEFT, offset.x, offset.y)
        IconPool[index] = icon
    end
    return IconPool[index]
end

local function GetTextControl(index)
    if index ~= 1 and index ~= 2 then return nil end
    local wm = GetWindowManager()
    if not TextPool[index] then
        local icon = GetIconControl(index)
        local label = wm:CreateControl("ERUI_SetTrackerText" .. index, UI_Container, CT_LABEL)
        label:SetFont("EldenRingUI/Fonts/Vollkorn-Regular_0.slug|22|soft-shadow-thick")
        label:SetColor(0.9, 0.9, 0.9, 0.9)
        label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        if index == 1 then
            label:SetAnchor(BOTTOMLEFT, icon, TOPLEFT, -2, -18)
        else
            label:SetAnchor(TOPLEFT, icon, BOTTOMLEFT, -2, 18)
        end

        TextPool[index] = label
    end
    return TextPool[index]
end

local SetNameCache = {}
local CachedBodyCounts = {}

local function ScanBodyGear()
    CachedBodyCounts = {}
    if not EldenRingUI or not EldenRingUI.TRACKED_SETS then return end

    local bodySlots = {
        EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,
        EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
        EQUIP_SLOT_HAND, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2
    }

    for _, slotIndex in ipairs(bodySlots) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local hasSet, setName = GetItemLinkSetInfo(itemLink, false)
            
            if hasSet and setName then
                local matchedConfig = SetNameCache[setName]

                if matchedConfig == nil then
                    matchedConfig = false 
                    for configName, _ in pairs(EldenRingUI.TRACKED_SETS) do
                        if string.find(setName, configName, 1, true) then
                            matchedConfig = configName
                            break
                        end
                    end
                    SetNameCache[setName] = matchedConfig
                end

                if matchedConfig then
                    CachedBodyCounts[matchedConfig] = (CachedBodyCounts[matchedConfig] or 0) + 1
                end
            end
        end
    end
end

local function ScanGear()
    local setCounts = {}
    for configName, count in pairs(CachedBodyCounts) do
        setCounts[configName] = count
    end

    if not EldenRingUI or not EldenRingUI.TRACKED_SETS then return setCounts end

    local weaponSlots = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND, EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }
    for _, slotIndex in ipairs(weaponSlots) do
        local itemLink = GetItemLink(BAG_WORN, slotIndex)
        if itemLink and itemLink ~= "" then
            local hasSet, setName = GetItemLinkSetInfo(itemLink, false)
            
            if hasSet and setName then
                local matchedConfig = SetNameCache[setName]

                if matchedConfig == nil then
                    matchedConfig = false 
                    for configName, _ in pairs(EldenRingUI.TRACKED_SETS) do
                        if string.find(setName, configName, 1, true) then
                            matchedConfig = configName
                            break
                        end
                    end
                    SetNameCache[setName] = matchedConfig
                end

                if matchedConfig then
                    local count = 1
                    if slotIndex == EQUIP_SLOT_MAIN_HAND or slotIndex == EQUIP_SLOT_BACKUP_MAIN then
                        local weaponType = GetItemLinkWeaponType(itemLink)
                        if weaponType == WEAPONTYPE_TWO_HANDED_SWORD or weaponType == WEAPONTYPE_TWO_HANDED_AXE or 
                           weaponType == WEAPONTYPE_TWO_HANDED_HAMMER or weaponType == WEAPONTYPE_BOW or 
                           weaponType == WEAPONTYPE_FIRE_STAFF or weaponType == WEAPONTYPE_FROST_STAFF or 
                           weaponType == WEAPONTYPE_LIGHTNING_STAFF or weaponType == WEAPONTYPE_HEALING_STAFF then
                            count = 2
                        end
                    end
                    
                    setCounts[matchedConfig] = (setCounts[matchedConfig] or 0) + count
                end
            end
        end
    end
    return setCounts
end

local function UpdateUI()
    local counts = ScanGear()
    local displaySlots = {nil, nil, nil, nil}
    local displayNames = {nil, nil, nil, nil}
    local overflow = {}

    for configName, count in pairs(counts) do
        local data = EldenRingUI.TRACKED_SETS[configName]
        if data and data.icon and count >= (data.pieces or 5) then
            local pref = data.preferredSlot
            if pref and pref >= 1 and pref <= 4 and not displaySlots[pref] then
                displaySlots[pref] = data.icon
                displayNames[pref] = configName
            else
                table.insert(overflow, { icon = data.icon, name = configName })
            end
        end
    end

    for _, item in ipairs(overflow) do
        for i = 1, 4 do
            if not displaySlots[i] then
                displaySlots[i] = item.icon
                displayNames[i] = item.name
                break
            end
        end
    end

    for i = 1, 4 do
        local ctrl = GetIconControl(i)
        if displaySlots[i] then
            ctrl:SetTexture(displaySlots[i])
            ctrl:SetHidden(false)
        else
            ctrl:SetHidden(true)
        end

        if i == 1 or i == 2 then
            local textCtrl = GetTextControl(i)
            if textCtrl then
                if displaySlots[i] and displayNames[i] then
                    textCtrl:SetText(displayNames[i])
                    textCtrl:SetHidden(false)
                else
                    textCtrl:SetHidden(true)
                end
            end
        end
    end
end

local function OnInitialize(event, addonName)
    if event == EVENT_ADD_ON_LOADED and addonName ~= ADDON_NAME then return end
    
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_InitPlayer", EVENT_PLAYER_ACTIVATED)

    if UI_Container then return end

    ScanBodyGear()
    CreateUI()
    UpdateUI()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        ScanBodyGear()
        UpdateUI()
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
    
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, UpdateUI)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_InitAddon", EVENT_ADD_ON_LOADED, OnInitialize)
EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_InitPlayer", EVENT_PLAYER_ACTIVATED, OnInitialize)