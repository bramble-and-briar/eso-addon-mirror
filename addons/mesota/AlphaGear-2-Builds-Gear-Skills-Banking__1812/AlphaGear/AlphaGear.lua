AG = {}

AG.name = 'AlphaGear'
AG.displayname = 'AlphaGear 2'
AG.version = 'v7.0.0'
AG.author = 'mesota, Kyzeragon'
AG.init = false
AG.pendingSet = -1
AG.previousSet = nil
AG.previousProfile = nil
AG.accountVariableVersion = 2
AG.characterVariableVersion = 1
AG.isDebug = false

-- Mutex for Bag Updates
AG.BagsLockCount = 0

AG.plugins = {}

AG.CHOICE_SHOW_ITEM_LEVEL_ALWAYS = 1
AG.CHOICE_SHOW_ITEM_LEVEL_LOW = 2
AG.CHOICE_SHOW_ITEM_LEVEL_NEVER = 3

AG.OUTFIT_NONE = 0
AG.OUTFIT_KEEP = -1

AG.MODE_GEAR = 'Gear'
AG.MODE_SKILL = 'Skill'

AG.MENU_TYPE_GEAR = 1
AG.MENU_TYPE_SKILLS = 2

AG.account = {}
AG.account_defaults = {
    option = {true, true, true, true, true, true, true,
     true, true, true, true, false, true, true, AG.CHOICE_SHOW_ITEM_LEVEL_NEVER
--> unused
        ,false
--< unused
        ,false
    },

    -- default positions of UIElements
    positions = {
        ["AG_UI_ButtonBg"] = {10, 10, TOPLEFT, TOPLEFT},
        ["AG_SetButtonBg"] = {-260, -100, LEFT, RIGHT},
        ["AG_SwapMessageBg"] = {-260, 0, LEFT, RIGHT},
        ["AG_Panel"] = {0, 0, CENTER, CENTER}
    },

    Integrations = {
        Inventory = {
            UseFCOIS = false,
        },

        Styling = {
            UseAlphaStyle = false,
        },

        Champion = {
            UseCPSlots = false,
            UseDynamicCP = false,
            DCPPrintNames = true,
            DCPPrintSlottables = false,
        },

        QuickSlot = {
            UseGMQSB = false,
        }
    }
}


AG.setdata = {}
AG.setdata_defaults = {
   setamount = 16,
   lastset = false,
}


-- Update Event Queue
AG.Jobs = {}                -- List of jobs to be executed in the OnUpdate event. Element of form {JOB_TYPE, BAG, SLOT}
AG.NextEventTime = 0        -- Time for the next event
AG.InBulkMode = false
AG.JOB_TYPE_UNEQUIP_GEAR = 1   
AG.JOB_TYPE_DEPOSIT_GEAR = 2   
AG.JOB_TYPE_WITHDRAW_GEAR = 3
AG.JOB_TYPE_UPDATE_UI = 4
AG.JOB_TYPE_LOAD_SKILL_BAR = 5
AG.JOB_TYPE_SHOW_SWAP_MSG = 6
AG.JOB_TYPE_EQUIP_GEAR = 7
AG.JOB_TYPE_START_BULK_MODE = 8
AG.JOB_TYPE_STOP_BULK_MODE = 9
AG.JOB_TYPE_MESSAGE = 10
AG.JOB_TYPE_PREPARE_TOON = 11

--> BAERTRAM - FCOIS
AG.markerInventories = {
    ZO_PlayerInventoryBackpack,
    ZO_PlayerBankBackpack,
    ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack,
    ZO_SmithingTopLevelImprovementPanelInventoryBackpack,
}
--< BAERTRAM - FCOIS

-- local IDLE, GEARQUEUE = 0, {}


local UIElements = {}

local L, ZOSF = AGLang.msg, zo_strformat
local MAXSLOT, SELECT, SELECTBAR, DRAGINFO, TTANI, SWAP = 16, false, false, {}, false, false
local MENU = { nr = nil, type = nil, copySourceSetId = nil, copySourceProfileId = nil }
local EM, WM, SM, ICON, MARK = EVENT_MANAGER, WINDOW_MANAGER, SCENE_MANAGER, {}, {}
local OFMGR = ZO_OUTFIT_MANAGER
local IMGR = PLAYER_INVENTORY
local MAX_PROFILES = 20 

local AVAIL_EQUIPMENT_CACHE = nil

--> BAERTRAM - FCOIS
AG.MAXSLOT = MAXSLOT
--< BAERTRAM - FCOIS

local SLOTS = {
    {EQUIP_SLOT_MAIN_HAND,'mainhand','MainHand'},
    {EQUIP_SLOT_OFF_HAND,'offhand','OffHand'},
    {EQUIP_SLOT_BACKUP_MAIN,'mainhand','BackupMain'},
    {EQUIP_SLOT_BACKUP_OFF,'offhand','BackupOff'},
    {EQUIP_SLOT_HEAD,'head','Head'},
    {EQUIP_SLOT_CHEST,'chest','Chest'},
    {EQUIP_SLOT_LEGS,'legs','Leg'},
    {EQUIP_SLOT_SHOULDERS,'shoulders','Shoulder'},
    {EQUIP_SLOT_FEET,'feet','Foot'},
    {EQUIP_SLOT_WAIST,'belt','Belt'},
    {EQUIP_SLOT_HAND,'hands','Glove'},
    {EQUIP_SLOT_NECK,'neck','Neck'},
    {EQUIP_SLOT_RING1,'ring','Ring1'},
    {EQUIP_SLOT_RING2,'ring','Ring2'},
    {EQUIP_SLOT_POISON,'poison','Poison'},
    {EQUIP_SLOT_BACKUP_POISON,'poison','BackupPoison'},
}


local DRAG_TARGET_SLOTS = {
    [EQUIP_TYPE_HEAD] = { 5 },
    [EQUIP_TYPE_CHEST] = { 6 },
    [EQUIP_TYPE_LEGS] = { 7 },
    [EQUIP_TYPE_SHOULDERS] = { 8 },
    [EQUIP_TYPE_FEET] = { 9 },
    [EQUIP_TYPE_WAIST] = { 10 },
    [EQUIP_TYPE_HAND] = { 11 },
    [EQUIP_TYPE_NECK] = { 12 },
    [EQUIP_TYPE_RING] = { 13, 14 },
    [EQUIP_TYPE_MAIN_HAND] = { 1, 3 },
    [EQUIP_TYPE_ONE_HAND] = { 1, 2, 3, 4 },
    [EQUIP_TYPE_TWO_HAND] = { 1, 3 },
    [EQUIP_TYPE_OFF_HAND] = { 2, 4 },
    [EQUIP_TYPE_POISON] = { 15, 16 }
}

local QUALITY_COLORS = {
    [ITEM_DISPLAY_QUALITY_TRASH] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_TRASH)},
    [ITEM_DISPLAY_QUALITY_NORMAL] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_NORMAL)},
    [ITEM_DISPLAY_QUALITY_MAGIC] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_MAGIC)},
    [ITEM_DISPLAY_QUALITY_ARCANE] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_ARCANE)},
    [ITEM_DISPLAY_QUALITY_ARTIFACT] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_ARTIFACT)},
    [ITEM_DISPLAY_QUALITY_LEGENDARY] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_LEGENDARY)},
    [ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE] = {GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE)}
}
-- ZO_ColorDef:New(GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, ITEM_DISPLAY_QUALITY_MAGIC)),

-- list of slots which can contain identical items
local DUPSLOTS = {1,2,3,4,13,14,15,16}
local TWINSLOTS = {
    [1] = 2,
    [2] = 1,
    [3] = 4,
    [4] = 3,
    [13] = 14,
    [14] = 13,
    [15] = 16,
    [16] = 15
}

--- Writes trace messages to the console
-- fmt with %d, %s,
local function trace(fmt, ...)
    if AG.isDebug then
        d(string.format(fmt, ...))
    end
end


--- Computes a color depending on the condition of an item.
-- @param val condition value
-- @param a alpha value
-- @return rgb and alpha
local function GetColor(val, a)
    local r,g
    
    if val > 100 then val = 100 end
    
    if val >= 50 then 
        r = 100-((val-50)*2)
        g = 100 
    else 
        r = 100
        g = val*2 
    end
    
    return r/100, g/100, 0, a
end

--- Computes a color depending on the quality of the item.
-- @param link link to item
-- @param a alpha value
-- @return rgb and alpha
local function Quality(link,a)
    local displayQuality = GetItemLinkDisplayQuality(link);
    local cols = QUALITY_COLORS[displayQuality]
    return cols[1], cols[2], cols[3], a
end

local function Zero(val) if val == 0 then return nil else return val end end

--- Hides a control
-- Used for charge and repair icons
-- @param c control to hide
local function Hide(c)
    c:SetHidden(true); 
    c:SetWidth(0) 
end

--- Shows a control
-- Used for charge and repair icons
-- @param c control to show
local function Show(c)
    c:SetHidden(false); 
    c:SetWidth(50) 
end

--- Shows or hides a control
-- Used for charge and repair icons
-- @param c control to show
-- @param visible show or hide
function AG.layoutControl(c, visible)
    c:SetHidden (not visible)
    if visible then
        c:SetWidth (50)
    else 
        c:SetWidth (0)
    end
end

--- called before a gear set with id setId is changed
function AG.handlePreChangeGearSetItems(setId)
    local AGplugFCOIS = AG.plugins.FCOIS

    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        local affectedBuildIds = {}

        -- find all builds in the current profile which use the gear set setId
        local agModel = AG.setdata

        for buildId = 1, MAXSLOT do
            local build = agModel[buildId].Set
            
            if build.gear == setId then
                table.insert (affectedBuildIds, buildId)
            end
        end

        if #affectedBuildIds > 0 then
            local usageMap = AG.ComputeItemUsageMap()

            AGplugFCOIS.onPreChangeGearSet(usageMap, affectedBuildIds)
        end
    end
end

--- called after the gear set with id setId has been changed
function AG.handlePostChangeGearSetItems(setId)
    local AGplugFCOIS = AG.plugins.FCOIS

    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        local affectedBuildIds = {}

        -- find all builds in the current profile which use the gear set setId
        local agModel = AG.setdata

        for buildId = 1, MAXSLOT do
            local build = agModel[buildId].Set
            
            if build.gear == setId then
                table.insert (affectedBuildIds, buildId)
            end
        end

        if #affectedBuildIds > 0 then
            local usageMap = AG.ComputeItemUsageMap()

            AGplugFCOIS.onPostChangeGearSet(usageMap, affectedBuildIds)
        end
    end
end

--- called when the FCOIS Icon of a build was changed
function AG.handleBuildIconChanged(setnr, newIconId)
    local AGplugFCOIS = AG.plugins.FCOIS

    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        local usageMap = AG.ComputeItemUsageMap()
        AGplugFCOIS.onChangeBuildIcon(usageMap, setnr, newIconId)
    end
end

--- called when a gear set is removed from a build
function AG.handleRemoveGearSetFromBuild(buildId)
    local AGplugFCOIS = AG.plugins.FCOIS

    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        local usageMap = AG.ComputeItemUsageMap()
        AGplugFCOIS.onRemoveGearSetFromBuild(usageMap, buildId)
    end
end

--- called when a new gear set is assigned to a build
function AG.handleAssignGearSetToBuild(buildId)
    local AGplugFCOIS = AG.plugins.FCOIS

    if AGplugFCOIS.isAddonReady() and AGplugFCOIS.isFCOISMarkerIconsEnabled() then
        local usageMap = AG.ComputeItemUsageMap()
        AGplugFCOIS.onAssignGearSetToBuild(usageMap, buildId)
    end
end


-- AG.DrawMenu reveals or hides the menu when invoked
-- line is an array of boolean, which enables or disables a menu item
function AG.DrawMenu(c, line)
    AG_PanelMenu:ToggleHidden()
    AG_PanelMenu:SetAnchor(3, c, 6, 0, 0)

    local h, c1 = 0, 0 

    for z,x in pairs(line) do
        c1 = AG_PanelMenu:GetChild(z)
        if x then
            h = h + 30
            c1:SetHeight(30)
            c1:SetHidden(false)
        else
            c1:SetHeight(0)
            c1:SetHidden(true)
        end
    end

    AG_PanelMenu:SetHeight(h + 20)

end

--- Creates item quality indicator controls to be shown in the inventory
function AG.DrawInventory()
    trace ('DrawInventory started')

    for _,c in pairs(SLOTS) do
        local p = WM:GetControlByName('ZO_CharacterEquipmentSlots'..c[3])
        
        -- Quality Control
        local s = WM:CreateControl('AG_InvBg'..c[1], p, CT_TEXTURE)
        s:SetHidden(true)
        s:SetDrawLevel(1)
        s:SetTexture('AlphaGear/asset/hole.dds')
        s:SetAnchorFill()
        
        -- Condition Control
        s = WM:CreateControl('AG_InvBg'..c[1]..'Condition', p, CT_LABEL)
        s:SetFont('ZoFontGameSmall')
        s:SetAnchor(TOPRIGHT,p,TOPRIGHT,7,-8)
        s:SetDimensions(50,10)
        s:SetHidden(true)
        s:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        
        -- Level Control
        s = WM:CreateControl('AG_InvBg'..c[1]..'Level', p, CT_TEXTURE)
        -- s:SetFont('ZoFontGameLarge')
        s:SetAnchor(TOPLEFT,p,TOPLEFT,0,-3)
        s:SetDimensions(10,10)
        s:SetHidden(true)
        s:SetDrawLayer(p:GetDrawLayer() + 1)
        -- s:SetAnchorFill()
        -- s:SetDrawLevel(1)

        -- s:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
end


function AG.GetIdTypeAndLink(bag, slot)
    local itemType = GetItemType (bag, slot)
    local link = GetItemLink(bag, slot)
    local id

    if itemType == ITEMTYPE_POISON then
        id = Id64ToString(GetItemInstanceId(bag, slot))
    else 
        id = Id64ToString(GetItemUniqueId(bag, slot))
    end

    return id, itemType, link
end


-- called when an item is dragged into a gear set or when SHIFT LMB is pressed on a gear set slot
function AG.InsertItemInGearSet(setId, slot, newId, newLink, newEquipType)

    local function Contains(tab, item) 
        for _, value in pairs(tab) do 
            if value == item then 
                return true 
            end 
        end 
        return false 
    end


    local function CheckItemConstraints(nr, target)
        local slotToClear = false
        local et1 = GetItemLinkEquipType(AG.setdata[nr].Gear[1].link)
        local et2 = GetItemLinkEquipType(AG.setdata[nr].Gear[3].link)
        
        if newEquipType == EQUIP_TYPE_TWO_HAND then
            if target == 1 then 
                slotToClear = 2 
            elseif target == 3 then 
                slotToClear = 4 
            end
        elseif newEquipType == EQUIP_TYPE_ONE_HAND or newEquipType == EQUIP_TYPE_OFF_HAND then
            if target == 2 and et1 == EQUIP_TYPE_TWO_HAND then 
                slotToClear = 1 
            elseif target == 4 and et2 == EQUIP_TYPE_TWO_HAND then 
                slotToClear = 3 
            end
        end

        trace("New equip Type: %d, STC: %d", newEquipType, slotToClear or 0)


        -- clear the second slot in case of a switch from two-handed to one-handed
        if slotToClear then
            AG.setdata[nr].Gear[slotToClear] = { id = 0, link = 0 }
            AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..nr..'_'..slotToClear))
        end
        
        -- revome the item from any slot in the same gear set, in case it was dragged form one slot to another
        for _,xslot in pairs(DUPSLOTS) do
            if AG.setdata[nr].Gear[xslot].id == newId then
                AG.setdata[nr].Gear[xslot] = { id = 0, link = 0 }
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..nr..'_'..xslot))
            end
        end
    end


    -- insert single item into gear set
    AG.handlePreChangeGearSetItems(setId)

    -- remove items in case of a switch from two one-handers to one two-hander
    if Contains(DUPSLOTS, slot) then 
        CheckItemConstraints(setId, slot) 
    end
    
    AG.setdata[setId].Gear[slot] = { id = newId, link = newLink }

    AG.handlePostChangeGearSetItems(setId)
end

--- creates buttons for gear and skill
-- @param p Parent
-- @param name One of "Button" == button in gear- or skill-set, "edit" == button in edit-panel
-- @param btn One of 'Gear', 'Skill'
-- @param nr number of the set in "button"-mode, One of "1", "2" in "edit"-mode, "1" is mainhand, "2" is offhand
-- @param x number of slot in set
function AG.DrawButton(p, name, btn, nr, x, xpos, ypos, show)

    -- creates buttons with names like
    -- AG_Edit_Gear_1
    local c = WM:CreateControl('AG_'..name..'_'..btn..'_'..nr..'_'..x, p, CT_BUTTON)
    if show then c:SetAnchor(3,p,3,xpos,ypos) else c:SetAnchor(2,p,2,xpos,ypos) end
    c:SetDrawTier(1)
    c:SetDimensions(40,40)
    c:SetMouseOverTexture('AlphaGear/asset/light.dds')
    c:SetHandler('OnMouseEnter',function(self) AG.Tooltip(self,true,show) end)
    c:SetHandler('OnMouseExit',function(self) AG.Tooltip(self,false,show) end)

    local b = WM:CreateControl('AG_'..name..'_'..btn..'_'..nr..'_'..x..'Bg', c, CT_BACKDROP)
    b:SetAnchor(128,c,128,0,0)
    b:SetDimensions(44,44)
    b:SetCenterColor(0,0,0,0.2)

    if name == 'Button' and btn == AG.MODE_GEAR then
        b:SetEdgeColor(AG.GetItemBorderColor(nr, x))
    else
        -- no border
        b:SetEdgeColor(0, 0, 0, 0)
    end 

    b:SetEdgeTexture('',1,1,2)
    b:SetInsets(2,2,-2,-2)
    
    if not show then
        c:SetClickSound('Click')
        c:EnableMouseButton(2,true)
        c:SetHandler('OnReceiveDrag',function(self) AG.OnDragReceive(self) end)

        if btn == AG.MODE_GEAR then 
            c:SetHandler('OnMouseDown',
                function(self, button, ctrl, alt, shift)
                    if button == 2 then 
                        -- cleer slected gear set item
                        if AG.setdata[nr].Gear[x] ~= 0 then
                            AG.handlePreChangeGearSetItems(nr)
                            AG.setdata[nr].Gear[x] = { id = 0, link = 0 }
                            AG.handlePostChangeGearSetItems(nr)
                            AG.ShowButton(self)
                        end
                    elseif shift then 
                        if button == 1 then
                            -- insert single item into gear set
                            local id = 0
                            local link = 0
                            local equipType = 0

                            if GetItemInstanceId(BAG_WORN, SLOTS[x][1]) then
                                id, equipType, link = AG.GetIdTypeAndLink(BAG_WORN, SLOTS[x][1])
                            end 

                            AG.InsertItemInGearSet(nr, x, id, link, equipType)
                            AG.ShowButton(self)
                        end
                    elseif button == 1 then 
                        -- equip single item
                        AG.LoadItem(nr, x) 
                    end
                end
            ) 
        end

        if btn == AG.MODE_SKILL then 
            c:SetHandler('OnMouseDown',
                function(self,button,ctrl,alt,shift)
                    if button == 2 then 
                        -- clear skill
                        AG.setdata[nr].Skill[x] = 0
                        AG.ShowButton(self)
                    elseif shift then
                        if button == 1 then
                            local abilityId = GetSlotBoundId(x+2)
                            local baseAbilityId = 0
                    
                            -- Updated for scribing
                            if abilityId ~= 0 then
                                if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(abilityId)) then
                                    -- Crafted skill, the abilityId returned is the "CraftedAbilityID" which is like the base ID
                                    baseAbilityId = abilityId
                                else
                                    -- Normal skill, 
                                    baseAbilityId = AG.GetBaseAbilityId(abilityId)
                                end
                            end
                    
                            AG.setdata[nr].Skill[x] = baseAbilityId
                            AG.ShowButton(self) 
                        end
                    elseif button == 1 then 
                        AG.LoadSkill(nr,x) 
                    end 
                end
            ) 
        end
        AG.ShowButton(c)
    end
end


function AG.CreateButtonBarPanel(nr, modestr, parent, width)
    local name = 'AG_Selector_'..modestr..'_'..nr
    
    local p = WM:CreateControl(name, parent, CT_BUTTON) 
    p:SetAnchor(3, nil, 3, 0, 45*(nr-1))
    p:SetDimensions(width, 44)
    p:SetClickSound('Click')
    p:EnableMouseButton(2, true)
    p:SetNormalTexture('AlphaGear/asset/grey.dds')
    p:SetMouseOverTexture('AlphaGear/asset/light.dds')
    p.data = { header = '|cFFAA33'..L.Head[modestr]..nr..'|r', info = L.Selector[modestr] }
    p:SetHandler('OnMouseEnter',function(self) AG.Tooltip(self,true) end)
    p:SetHandler('OnMouseExit',function(self) AG.Tooltip(self,false) end)

    return p
end

function AG.CreateButtonBarLabel(nr, modestr, parent)
    local name = 'AG_Selector_'..modestr..'_'..nr..'_Label'

    local c = WM:CreateControl(name, parent, CT_LABEL)
    c:SetAnchor(3, parent, 3, 0, 0)
    c:SetDrawTier(1)
    c:SetDimensions(44,44)
    c:SetHorizontalAlignment(1)
    c:SetVerticalAlignment(1)
    c:SetFont('AGFontBold')
    c:SetColor(1,1,1,0.8)
    c:SetText(nr)
end


function AG.DrawSkillBarButtons(nr)
    local p = AG.CreateButtonBarPanel(nr, AG.MODE_SKILL, AG_PanelSkillPanelScrollChild, 299)

    p:SetHandler('OnMouseDown',
        function(self,button,ctrl,alt,shift)
            if button == 2 then
                AG.DrawMenu(self, {true, (MENU.copySourceSetId and MENU.type == AG.MENU_TYPE_SKILLS), 
                        true, true, false, false})
                MENU.nr = nr
                MENU.type = AG.MENU_TYPE_SKILLS
            elseif shift then 
                if button == 1 then 
                    AG.GetSkillFromBar(nr)
                    AG.UpdateEditPanel(nr) 
                end
            elseif button == 1 then 
                if SELECTBAR then 
                    AG.setdata[SELECT].Set.skill[SELECTBAR] = nr
                    AG.SetConnect(AG.MODE_SKILL, 2)
                    SELECTBAR = false
                    AG.UpdateEditPanel(SELECT) 
                else 
                    AG.LoadBar(nr) 
                end 
            end
        end
    ) 

    AG.CreateButtonBarLabel(nr, AG.MODE_SKILL, p)

    -- Draw buttons for skills
    for x = 1, 6 do AG.DrawButton(p,'Button', AG.MODE_SKILL, nr, x, 46+42*(x-1), 0) end
end

function AG.DrawGearBarButtons(nr)
    local p = AG.CreateButtonBarPanel(nr, AG.MODE_GEAR, AG_PanelGearPanelScrollChild, 751)

    p:SetHandler('OnMouseDown',
        function(self,button,ctrl,alt,shift)
            if button == 2 then 
                -- open context menu
                local isBanking = IMGR:IsBanking()

                AG.DrawMenu(self, {true, (MENU.copySourceSetId and MENU.type == AG.MENU_TYPE_GEAR), true, true, isBanking, isBanking, isBanking, isBanking})
                MENU.nr = nr
                MENU.type = AG.MENU_TYPE_GEAR
            elseif shift then 
                if button == 1 then 
                    -- inser currently equipped
                    MENU.type = AG.MENU_TYPE_GEAR
                    MENU.nr = nr
                    AG.MenuAction(3)
                    AG.UpdateEditPanel(SELECT) 
                end
            elseif button == 1 then 
                if SELECTBAR then
                    -- use selected gear set in build

                    -- remove icon from old set
                    local removedGearId = AG.setdata[SELECT].Set.gear
                    if removedGearId ~= 0 then
                        AG.handleRemoveGearSetFromBuild(SELECT)
                    end

                    -- change gear set
                    AG.setdata[SELECT].Set.gear = nr

                    -- set icon for new set
                    AG.handleAssignGearSetToBuild(SELECT)

                    AG.SetConnect(AG.MODE_GEAR, 2)
                    SELECTBAR = false
                    AG.UpdateEditPanel(SELECT) 
                else 
                    -- equipp gear
                    AG.LoadGear(nr) 
                end 
            end
        end
    ) 

    AG.CreateButtonBarLabel(nr, AG.MODE_GEAR, p)

    -- Draw buttons for gear
    -- positions do not match order in SLOTS-Array
    local positions = {1,2,4,5,7,8,9,10,11,12,13,14,15,16,3,6}
    for x = 1, #SLOTS do 
        AG.DrawButton(p,'Button', AG.MODE_GEAR, nr, x, 46+44*(positions[x]-1), 0) 
    end
end




function AG.SetupMainPanel()

    -- Create Key Binding Labels
    ZO_CreateStringId('SI_BINDING_NAME_SHOW_AG_WINDOW', L.ShowMainBinding)
    ZO_CreateStringId('SI_BINDING_NAME_AG_UNDRESS', L.UneqipAllBinding)
    ZO_CreateStringId('SI_BINDING_NAME_AG_NEXT_SET', L.BindLoadNextSet)
    ZO_CreateStringId('SI_BINDING_NAME_AG_PREVIOUS_SET', L.BindLoadPreviousSet)
    ZO_CreateStringId('SI_BINDING_NAME_AG_TOGGLE_SET', L.BindToggleSet)

    ZO_CreateStringId('SI_BINDING_NAME_AG_NEXT_PROFILE', L.BindLoadNextProfile)
    ZO_CreateStringId('SI_BINDING_NAME_AG_PREVIOUS_PROFILE', L.BindLoadPreviousProfile)
    ZO_CreateStringId('SI_BINDING_NAME_AG_TOGGLE_PROFILE', L.BindToggleProfile)

    
    for pindex = 1, MAX_PROFILES do
        -- Create Key Binding Label
        ZO_CreateStringId('SI_BINDING_NAME_AG_PROFILE_'..pindex, L.BindLoadProfile..pindex)
    end

    
    -- create MAXSLOT skill-sets, gear-sets and sets
    for x = 1, MAXSLOT do
        -- Create Key Binding Label
        ZO_CreateStringId('SI_BINDING_NAME_AG_SET_'..x, L.LoadSetBinding..x)
        -- builds
        AG.DrawBuild(x)

        -- gear-sets
        AG.DrawGearBarButtons(x)

        -- skill-sets
        AG.DrawSkillBarButtons(x)
    end

    -- create skill buttons (Main and Backup) in edit panel
    for x = 1,6 do
        AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar1PanelSkill11Box,'Edit', AG.MODE_SKILL, 1,x,42*(x-1),0,true)
        AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar2PanelSkill21Box,'Edit', AG.MODE_SKILL, 2,x,42*(x-1),0,true)
    end

    -- create weapon buttons (Main and Backup) in skill edit panel
    for x = 1,2 do
        AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar1PanelWeap1Box,'Edit', AG.MODE_GEAR, 1, x, 42*(x-1), 0, true)
        AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar2PanelWeap2Box,'Edit', AG.MODE_GEAR, 1, x+2, 42*(x-1), 0, true)
    end

    -- create poison buttons (Main and Backup) in skill edit panel
    AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar1PanelWeap1Box,'Edit', AG.MODE_GEAR, 1, 15, 84, 0, true)
    AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetBar2PanelWeap2Box,'Edit', AG.MODE_GEAR, 1, 16, 84, 0, true)

    -- create gear buttons, row 1 in edit panel
    for x = 5,11 do AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetGearPanelGear1Box,'Edit', AG.MODE_GEAR, 1,x,42*(x-5),0,true) end

    -- create gear buttons, row 2 in edit panel
    for x = 12,14 do AG.DrawButton(AG_PanelSetPanelScrollChildEditPanelSetGearPanelGear2Box,'Edit', AG.MODE_GEAR, 1,x,42*(x-12),0,true) end


    -- ZO_PreHook('ZO_Skills_AbilitySlot_OnDragStart', AG.OnSkillDragStart)
    
    -- ZO_PreHook('ZO_InventorySlot_OnDragStart', AG.OnItemDragStart)

    ZO_PreHookHandler(AG_PanelMenu,'OnShow', 
        function()
            zo_callLater(
                function() 
                    EM:RegisterForEvent('AG4',EVENT_GLOBAL_MOUSE_UP,
                        function()
                            AG_PanelMenu:SetHidden(true)
                            EM:UnregisterForEvent('AG4',EVENT_GLOBAL_MOUSE_UP)
                        end
                    ) 
                end
            , 250)
        end
    )

    ZO_PreHookHandler(ZO_Skills,'OnShow', AG.OnShowSkills)
    ZO_PreHookHandler(ZO_Skills,'OnHide', AG.OnHideSkills)
    ZO_PreHookHandler(ZO_PlayerInventory,'OnShow', AG.OnShowInventory)
    ZO_PreHookHandler(ZO_PlayerInventory,'OnHide', AG.OnHideInventory)
    ZO_PreHookHandler(ZO_ChampionPerks,'OnShow', function() SM:HideTopLevel(AG_Panel) end)
    ZO_PreHookHandler(AG_Panel,'OnHide', 
        function() 
            AG_PanelIcons:SetHidden(true)
        end
    )

    AG_PanelIcons.useFadeGradient = false
    AG_PanelSetPanel.useFadeGradient = false
    AG_PanelGearPanel.useFadeGradient = false
    AG_PanelSkillPanel.useFadeGradient = false

    AG_UI_Button.data = { tip = AG.name }
    AG_PanelUndressArmor.data = { info = L.Unequip }
    AG_PanelUndressAll.data = { info = L.UnequipAll }
    AG_PanelProfilePanelEditProfileButton.data = { info = "Edit profile properties" }
    AG_PanelProfilePanelImportProfileButton.data = { info = "Import another profile" }
    AG_PanelSetPanelScrollChildEditPanelSetGearPanelGearLock.data = { info = L.Lock }
    
    AG.SetupProfileCombo()
end



function AG.HideEditPanel()
    local ctrlEP = AG_PanelSetPanelScrollChildEditPanel
    
    local anchor = {ctrlEP:GetAnchor()}

    -- close editpanel
    if not ctrlEP:IsHidden() and anchor[3] then
        anchor[3]:SetHeight(76)
        ctrlEP:SetHidden(true)
        anchor[3]:GetNamedChild('Box'):SetHidden(false)
        anchor[3]:GetNamedChild('Edit'):SetHidden(true)
        anchor[3]:GetNamedChild('BoxBg'):SetHidden(true)
        anchor[3]:GetNamedChild('AdvBtn'):SetHidden(true)
    end
end


function AG.DrawBuild(nr)
    trace ("DrawBuild")

    local panelWidth = 427

    local p,l,s = WM:GetControlByName('AG_SetSelector_'..(nr-1)) or false
    local function Slide(sc,fc,sa)
        local ani = ANIMATION_MANAGER:CreateTimeline()
        local slide = ani:InsertAnimation(ANIMATION_SIZE,sc)
        local fade = ani:InsertAnimation(ANIMATION_ALPHA,fc,145)
        fc:SetHidden(not fc:IsHidden())
        fc:SetAlpha(0)
        fade:SetAlphaValues(0,1)
        fade:SetDuration(100)
        --> BAERTRAM - FCOIS
        --  Changed the y "height" value from 431 to 461
        slide:SetStartAndEndHeight(76,461)
        --< BAERTRAM - FCOIS
        slide:SetStartAndEndWidth(panelWidth,panelWidth)
        slide:SetDuration(150)
        if sa then ani:PlayFromStart() else ani:PlayFromEnd() end
    end

    s = WM:CreateControl('AG_SetSelector_'..nr, AG_PanelSetPanelScrollChild, CT_BUTTON)
    
    if p then s:SetAnchor(1,p,4,0,5) else s:SetAnchor(3,nil,3,0,0) end
    
    s:SetDimensions(panelWidth, 76)
    s:SetClickSound('Click')
    s:EnableMouseButton(2,true)
    s:SetNormalTexture('AlphaGear/asset/grey.dds')
    s:SetMouseOverTexture('AlphaGear/asset/light.dds')
    s.setnr = nr
    s:SetHandler('OnMouseEnter',function(self) AG.Tooltip(self,true) end)
    s:SetHandler('OnMouseExit',function(self) AG.Tooltip(self,false) end)
    s:SetHandler('OnMouseDown',
        function(self,button)
            if button == 2 then
                local k = AG_PanelSetPanelScrollChildEditPanel
                local anchor = {k:GetAnchor()}

                -- close editpanel if open on other build
                if anchor[3] and anchor[3] ~= self then
                    anchor[3]:SetHeight(76)
                    k:SetHidden(true)
                    anchor[3]:GetNamedChild('Box'):SetHidden(false)
                    anchor[3]:GetNamedChild('Edit'):SetHidden(true)
                    anchor[3]:GetNamedChild('BoxBg'):SetHidden(true)
                    anchor[3]:GetNamedChild('AdvBtn'):SetHidden(true)
                end
                
                -- open editpanel on this build
                k:ClearAnchors()
                k:SetAnchor(6,self,6,2,-2)
                Slide(self,k,k:IsHidden())
                WM:GetControlByName('AG_SetSelector_'..nr..'Box'):ToggleHidden()
                WM:GetControlByName('AG_SetSelector_'..nr..'Edit'):ToggleHidden()
                WM:GetControlByName('AG_SetSelector_'..nr..'BoxBg'):ToggleHidden()
                WM:GetControlByName('AG_SetSelector_'..nr..'AdvBtn'):ToggleHidden()
                AG.UpdateEditPanel(self.setnr)
                AG_PanelIcons:SetHidden(true)
                SELECT = nr
            elseif button == 1 then 
                AG.LoadSet(nr) 
            end
        end
    )

    -- creates label for set number
    l = WM:CreateControl('AG_SetSelector_'..nr..'Label', s, CT_LABEL)
    l:SetAnchor(3,s,3,0,0)
    l:SetDrawTier(1)
    l:SetDimensions(44,44)
    l:SetHorizontalAlignment(1)
    l:SetVerticalAlignment(1)
    l:SetFont('AGFontBold')
    l:SetColor(1,1,1,0.8)
    l:SetText(nr)

    -- creates label for key binding
    l = WM:CreateControl('AG_SetSelector_'..nr..'KeyBind', s, CT_LABEL)
    l:SetAnchor(9,s,9,-15,0)
    l:SetDrawTier(1)
    l:SetDimensions(235,44)
    l:SetHorizontalAlignment(2)
    l:SetVerticalAlignment(1)
    l:SetFont('AGFont')
    l:SetColor(1,1,1,0.5)

    -- creates label for set name if in diplay mode
    l = WM:CreateControl('AG_SetSelector_'..nr..'Box', s, CT_LABEL)
    l:SetAnchor(TOPLEFT,s,TOPLEFT,2,44)
    l:SetDrawTier(1)
    l:SetDimensions(panelWidth-6, 30)
    l:SetHorizontalAlignment(0)
    l:SetVerticalAlignment(1)
    l:SetFont('AGFont')
    l:SetColor(1,1,1,1)

    -- text edit for set name in edit mode
    p = WM:CreateControlFromVirtual('AG_SetSelector_'..nr..'Edit', s, 'ZO_DefaultEditForBackdrop')
    p:ClearAnchors()
    p:SetAnchor(LEFT,l,LEFT,8,4)
    p:SetDimensions(panelWidth-94, 30)
    p:SetFont('AGFont')
    p:SetColor(1,1,1,1)
    p:SetMaxInputChars(100)
    p:SetHidden(true)
    p:SetHandler('OnFocusLost',function(self)
        AG.setdata[nr].Set.text[1] = self:GetText()
        self:LoseFocus()
        AG.UpdateUI(nr,nr)
    end)
    p:SetHandler('OnEscape',function(self) self:LoseFocus() end)
    p:SetHandler('OnEnter',function(self) self:LoseFocus() end)

   
    -- dark background for set-name
    p = WM:CreateControl('AG_SetSelector_'..nr..'BoxBg', s, CT_BACKDROP)
    p:SetDrawTier(1)
    p:SetAnchor(LEFT,l,LEFT,0,0)
    p:SetDimensions(panelWidth-80, 30)
    p:SetCenterColor(0,0,0,0.2)
    p:SetEdgeColor(0,0,0,0)
    p:SetEdgeTexture('',1,1,2)
    p:SetHidden(true)

    -- crate advanced options button
    local btnAO = WM:CreateControl('AG_SetSelector_'..nr..'AdvBtn', s, CT_BUTTON)
    btnAO:SetAnchor(LEFT, p, RIGHT, 4, 0)
    btnAO:SetDimensions(35, 35)
    btnAO:SetNormalTexture('esoui/art/buttons/edit_up.dds')
    btnAO:SetMouseOverTexture('esoui/art/buttons/edit_over.dds')
    btnAO:SetPressedTexture('esoui/art/buttons/edit_down.dds')
    btnAO:SetHidden(true)
    btnAO:SetClickSound('Click')
    btnAO.data = { header = '|cFFAA33Advanced Options|r', info = 'Opens the advanced options dialog.' }
    btnAO:SetHandler('OnMouseEnter',function(self) AG.Tooltip(self,true) end)
    btnAO:SetHandler('OnMouseExit',function(self) AG.Tooltip(self,false) end)
    btnAO:SetHandler('OnClicked',function(self) AG.ShowAdvancedOptionsDialog() end)
    
end



--- Draws the set selection panel
-- Number of visible buttons is determined by "setamount"
function AG.DrawSetButtonsUI()
    trace ("DrawSetButtonsUI")

    local xpos, ypos, c = 0, 27, nil
    for x = 1, MAXSLOT do
        c = WM:GetControlByName('AG_UI_SetButton_'..x)
        if not c then
            c = WM:CreateControl('AG_UI_SetButton_'..x, AG_SetButtonFrame, CT_BUTTON)
            c:SetDimensions(24,24)
            c:SetHorizontalAlignment(1)
            c:SetVerticalAlignment(1)
            c:SetClickSound('Click')
            c:SetFont('AGFontSmall')
            c:SetNormalFontColor(1,1,1,1)
            c:SetMouseOverFontColor(1,0.66,0.2,1)
            c:SetText(x)
            c:SetNormalTexture('AlphaGear/asset/grey.dds')
            c:SetMouseOverTexture('AlphaGear/asset/light.dds')
            c:SetHandler('OnMouseEnter',function(self) AG.TooltipSet(x,true) end)
            c:SetHandler('OnMouseExit',function(self) AG.TooltipSet(x,false) end)
            c:SetHandler('OnClicked',function(self) AG.LoadSet(x) end)
        end
        c:ClearAnchors()
        c:SetAnchor(3,AG_SetButtonFrame,3,xpos,ypos)
        if x > AG.setdata.setamount then c:SetHidden(true) else c:SetHidden(false) end
        if x == math.ceil(AG.setdata.setamount/2) then ypos = ypos + 29; xpos = 0
        else xpos = xpos + 29 end
    end
end




function AG.GetButton(c)
    local res, name = {}, {string.match(c:GetName(),'AG_(%a+)_(%a+)_(%d+)_(%d+)')}
    table.insert(res, name[2])
    table.insert(res, tonumber(name[3]))
    table.insert(res, tonumber(name[4]))
    return unpack(res)
end

function AG.GetSoulgem()
    trace ('GetSoulGem started')
    
    local result, tier = false, 0
    local bag = SHARED_INVENTORY:GenerateFullSlotData(nil,BAG_BACKPACK)
    
    for _,data in pairs(bag) do
        if IsItemSoulGem(SOUL_GEM_TYPE_FILLED,BAG_BACKPACK,data.slotIndex) then
            local geminfo = GetSoulGemItemInfo(BAG_BACKPACK,data.slotIndex)
            if geminfo > tier then
                tier = geminfo;
                result = data.slotIndex 
            end
        end
    end
    
    return result
end


function AG.GetSetIcon(nr,bar)
    trace ('GetSetIcon started')

    local endicon,gear,icon = nil, AG.setdata[nr].Gear, {
        [WEAPONTYPE_NONE] = 'nothing',
        [WEAPONTYPE_DAGGER] = 'onehand',
        [WEAPONTYPE_HAMMER] = 'onehand',
        [WEAPONTYPE_AXE] = 'onehand',
        [WEAPONTYPE_SWORD] = 'onehand',
        [WEAPONTYPE_TWO_HANDED_HAMMER] = 'twohand',
        [WEAPONTYPE_TWO_HANDED_AXE] = 'twohand',
        [WEAPONTYPE_TWO_HANDED_SWORD] = 'twohand',
        [WEAPONTYPE_FIRE_STAFF] = 'fire',
        [WEAPONTYPE_FROST_STAFF] = 'frost',
        [WEAPONTYPE_LIGHTNING_STAFF] = 'shock',
        [WEAPONTYPE_HEALING_STAFF] = 'heal',
        [WEAPONTYPE_BOW] = 'bow',
        [WEAPONTYPE_SHIELD] = 'shield'
    }
    if bar == 1 then
        if gear[2].link ~= 0 then endicon = icon[GetItemLinkWeaponType(gear[2].link)]
        else endicon = icon[GetItemLinkWeaponType(gear[1].link)] end
    else
        if gear[4].link ~= 0 then endicon = icon[GetItemLinkWeaponType(gear[4].link)]
        else endicon = icon[GetItemLinkWeaponType(gear[3].link)] end
    end
    if endicon then return 'AlphaGear/asset/'..endicon..'.dds' else return nil end
end

function AG.GetSkillFromBar(nr)
    trace('GetSkillFromBar')
    for x = 1,6 do

        local abilityId = GetSlotBoundId(x+2)
        local baseAbilityId = 0

        -- Updated for scribing
        if abilityId ~= 0 then
            if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(abilityId)) then
                -- Crafted skill, the abilityId returned is the "CraftedAbilityID" which is like the base ID
                baseAbilityId = abilityId
            else
                -- Normal skill, 
                baseAbilityId = AG.GetBaseAbilityId(abilityId)
            end
        end

        AG.setdata[nr].Skill[x] = baseAbilityId

        AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..nr..'_'..x))
    end
end


function AG.OnDragReceive(c)
    local function Contains(tab,item) 
        for _, value in pairs(tab) do 
            if value == item then 
                return true 
            end 
        end 
        return false 
    end
    

    local function CheckSkills(nr)
        for x = 1,5 do
            if AG.setdata[nr].Skill[x] == DRAGINFO.id then
                AG.setdata[nr].Skill[x] = 0
                AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..nr..'_'..x))
                return
            end
        end
    end

    local function DropItem(btn)
        local _, nr, slot = AG.GetButton(btn)
        if DRAGINFO.uid and Contains(DRAGINFO.slot, slot) then
            -- drop item into gear set
            AG.InsertItemInGearSet(nr, slot, DRAGINFO.uid, DRAGINFO.link, DRAGINFO.type)
            AG.ShowButton(btn)
            ClearCursor()
            PlaySound('Tablet_PageTurn')
        end
    end

    local function DropSkill(btn)
        local _, nr, slot = AG.GetButton(btn)
        if DRAGINFO.id then
            if (not DRAGINFO.ultimate and slot < 6) or (DRAGINFO.ultimate and slot == 6) then
                if slot < 6 then CheckSkills(nr) end
                AG.setdata[nr].Skill[slot] = DRAGINFO.id
                AG.ShowButton(btn)
                ClearCursor()
                PlaySound('Tablet_PageTurn')
            end
        end
    end
    
    local cursor = GetCursorContentType()
    if cursor == MOUSE_CONTENT_INVENTORY_ITEM or cursor == MOUSE_CONTENT_EQUIPPED_ITEM then 
        DropItem(c)
    elseif cursor == MOUSE_CONTENT_ACTION then 
        DropSkill(c) 
    end
end

function AG.HandleInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    -- local link = GetItemLink(bagId, slotIndex)
    trace ('-- Slot Changed Bag/Slot/Count: %d/%d/%d', bagId, slotIndex, stackCountChange)
    AG.ClearAvailableEquipmentCache()

    -- two events for one move:
    -- first event is substract from source bag (stackCountChange < 0)
    -- second event is add to target bag (stackCountChange > 0)
    AG.UnlockBags()
end


function AG.ClearAvailableEquipmentCachePlain()
    trace ('ClearAvailableEquipmentCachePlain')
    AVAIL_EQUIPMENT_CACHE = nil
end


function AG.ClearAvailableEquipmentCache()
    trace ('ClearAvailableEquipmentCache')
    AVAIL_EQUIPMENT_CACHE = nil
    if not AG.InBulkMode and not AG_Panel:IsHidden() then
        table.insert (AG.Jobs, {AG.JOB_TYPE_UPDATE_UI, 0, 0})
    end
end

--- defines a filter for items in bags which are searched
local function GetItemDataFilterComparator()
    return function(itemData)
        if itemData.itemType == ITEMTYPE_ARMOR or itemData.itemType == ITEMTYPE_WEAPON or itemData.itemType == ITEMTYPE_POISON then
            -- precalculate the IDString for later use

            if itemData.itemType == ITEMTYPE_POISON then
                itemData.IdStringAG = Id64ToString(itemData.itemInstanceId) 
            else
                itemData.IdStringAG = Id64ToString(itemData.uniqueId)
            end

            if AG.isDebug then
                if itemData.itemType == ITEMTYPE_POISON then
                    trace('Poison UID: %s', itemData.IdStringAG)
                end
            end

            return true
        end
    end
end

--- builds a cache of items which are armor or weapons out of items in BAG_WORN or BAG_BACKPACK
function AG.GetAvailableEquipmentCache()
    trace ('GetAvailableEquipmentCache')

    if not AVAIL_EQUIPMENT_CACHE then

        local comparator = GetItemDataFilterComparator()

        if IMGR:IsBanking() then
            local bankingBag = GetBankingBag()

            if bankingBag == BAG_BANK then
                -- we're using a normal banker
                AVAIL_EQUIPMENT_CACHE = SHARED_INVENTORY:GenerateFullSlotData(comparator, BAG_BACKPACK, BAG_WORN, BAG_BANK, BAG_SUBSCRIBER_BANK)
            else 
                -- we're using a house bank
                AVAIL_EQUIPMENT_CACHE = SHARED_INVENTORY:GenerateFullSlotData(comparator, BAG_BACKPACK, BAG_WORN, bankingBag)
            end
        else
            AVAIL_EQUIPMENT_CACHE = SHARED_INVENTORY:GenerateFullSlotData(comparator, BAG_BACKPACK, BAG_WORN)
        end
    end

    return AVAIL_EQUIPMENT_CACHE
end

function AG.SwapItemInCache (oldSlot, newBag, newSlot)
    local aveq = AG.GetAvailableEquipmentCache()
   
    for _, itemData in pairs(aveq) do 
        if oldSlot == itemData.slotIndex and BAG_WORN == itemData.bagId then 
            trace("Moved: "..itemData.name.." from Bag/Slot: "..itemData.bagId.."/"..itemData.slotIndex.." to Bag/Slot: "..newBag.."/"..newSlot)
            itemData.slotIndex = newSlot
            itemData.bagId = newBag
            return
        end 
    end
end


function AG.GetItemFromBag(id)
    if not id then return false end

    local aveq = AG.GetAvailableEquipmentCache()
    
    for _, itemData in pairs(aveq) do 
        if id == itemData.IdStringAG then 
            trace("Found in cache: %s Bag %d, Slot %s, UID %s", itemData.name, itemData.bagId, itemData.slotIndex, itemData.IdStringAG)
            return itemData.bagId, itemData.slotIndex 
        end 
    end

    trace("Not found in cache: %s", id)

    return false
end

--- Loads an item of a gear-set
-- @param nr Number of gear-set
-- @param slotIndex Number of slot
function AG.LoadItem(nr, slotIndex, set)
    if not nr or not slotIndex then return end

    local targetSlot = SLOTS[slotIndex][1]

    if AG.setdata[nr].Gear[slotIndex].id ~= 0 then
        table.insert(AG.Jobs, {AG.JOB_TYPE_EQUIP_GEAR, AG.setdata[nr].Gear[slotIndex], targetSlot}) 
    elseif set and AG.setdata[set].Set.lock == 1 then
        -- this will corrupt the cache, if the unequipped item is used in a later slot. Not a real use-case...
        table.insert(AG.Jobs, {AG.JOB_TYPE_UNEQUIP_GEAR, targetSlot}) 
    end
end

--- Returns true if item is mythtic by itemlink
function AG.IsItemLinkMythic(link) 
    return ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE == GetItemLinkDisplayQuality(link)
end

--- Returns true if item is mythtic by bag/slot
function AG.IsItemMythic(bag, slot) 
    local _, _, _, _, _, _, _, _, displayQuality = GetItemInfo(bag, slot)
    return ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE == displayQuality
end

--- loads a gear-set
-- @param nr Number of build
-- @param set Number of set
function AG.LoadGear(nr, set)
    if not nr then return end
    AG.ClearAvailableEquipmentCachePlain()

    local TBSSetId = 161

    table.insert(AG.Jobs, {AG.JOB_TYPE_PREPARE_TOON, 0, 0})

    table.insert(AG.Jobs, {AG.JOB_TYPE_START_BULK_MODE, 0, 0})

    -- find a slot order, so that items of Twice-Born-Star are swapped first (to keep the 5-items-bonus)
    local slotOrder = {}

    local newGear = AG.setdata[nr].Gear
    
    local newGearHasMystic = false
    local newMythicSlot = nil

    for slotIndex = 1, #SLOTS do
        -- slotName = SLOTS[slotIndex][3]
        local newLink = newGear[slotIndex].link
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(newLink)

        if not newGearHasMystic and AG.IsItemLinkMythic(newLink) then
            newGearHasMystic = true 
            newMythicSlot = SLOTS[slotIndex][1]
        end
        
        if hasSet and setId == TBSSetId then
            -- trace("Adding set item at front of equip list: slot "..slotName.." set "..setName.." id "..setId)
            table.insert( slotOrder, 1, slotIndex )
        else
            -- trace ("Adding "..slotName.." at end of equip list")
            table.insert(slotOrder,slotIndex)
        end
    end

    -- unequipp mythic item prior equipping another 
    if newGearHasMystic then
        for slotIndex = 1, #SLOTS do
            local targetSlot = SLOTS[slotIndex][1]
            if AG.IsItemMythic(BAG_WORN, targetSlot) then
                -- only unequipp if slot has changed, otherwise its unequipped automatically
                if targetSlot ~= newMythicSlot then
                    trace("Must unequipp mythic item. New slot: "..newMythicSlot.." old slot: "..targetSlot)
                    table.insert(AG.Jobs, {AG.JOB_TYPE_UNEQUIP_GEAR, targetSlot}) 
                end
                -- never more than one 
                break
            end
        end
    end

    for j = 1, #SLOTS do
        local slotIndex = slotOrder[j]
        AG.LoadItem(nr, slotIndex, set) 
    end

    table.insert(AG.Jobs, {AG.JOB_TYPE_STOP_BULK_MODE, 0, 0})

    -- update ui afterwards
    table.insert (AG.Jobs, {AG.JOB_TYPE_UPDATE_UI, 0, 0})
end

-- find skillType, skillLine and abilityIndex by abilityId
function AG.GetSkill(abilityId)
    local hasProgression, progressionIndex = GetAbilityProgressionXPInfoFromAbilityId(abilityId)

    if not hasProgression then
        trace('Ability with ID %d has no progression.', abilityId)
        return false
    end
  
    local skillType1, skillLine1, abilityIndex1 = GetSkillAbilityIndicesFromProgressionIndex(progressionIndex)
    if skillType1 > 0 then 
        return skillType1, skillLine1, abilityIndex1 
    end
  

    for skillType = 1, GetNumSkillTypes() do
        for skillLine = 1, GetNumSkillLines(skillType) do
            for abilityIndex = 1, GetNumSkillAbilities(skillType, skillLine) do
                
                local progId = select(7, GetSkillAbilityInfo(skillType, skillLine, abilityIndex))
                
                if progId == progressionIndex then 
                    trace ('Found Skill Type %d, Line %d, Index %d', skillType, skillLine, abilityIndex)
                    return skillType, skillLine, abilityIndex 
                end
                        
                -- Returns: number abilityId
                -- if GetSkillAbilityId(skillType, skillLine, abilityIndex, false) == abilityId then
                   --  trace ('Found Skill Type %d, Line %d, Index %d', skillType, skillLine, abilityIndex)
                    -- return skillType, skillLine, abilityIndex
                -- end
            end
        end
    end
    return false
end


function AG.GetBaseAbilityId(abilityId)
    -- Returns: boolean hasProgression, number progressionIndex, number lastRankXp, number nextRankXP, number currentXP, boolean atMorph
    local hasProgression, progressionIndex = GetAbilityProgressionXPInfoFromAbilityId(abilityId)

    trace ('Progression Index: %s,  %d', tostring(hasProgression), progressionIndex)
    
    if not hasProgression then
        trace('Ability with ID %d has no progression.', abilityId)
        return 0 
    end


    local name, morph, rank = GetAbilityProgressionInfo(progressionIndex)
    trace('PI %d, Name %s, Morph %d, rank %d.', progressionIndex, name, morph, rank)
    
    local baseAbilityId = GetAbilityProgressionAbilityId(progressionIndex, morph, rank)
    trace('BaseAbilityId: %d.',  baseAbilityId)

    return baseAbilityId
end


--- returns the abilityIndex for a given abilityId
function AG.GetAbility(abilityId)
    trace ('Searching Ability with ID %d', abilityId)


    -- local exists = DoesAbilityExist(abilityId)
    -- trace ('Ability exists: %s', tostring(exists))
    
    -- local  texName = GetAbilityIcon(abilityId)
    -- trace ('Ability texture: %s', texName)
    
    -- local st, si, ai, mc, ri = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
    -- trace ('Specific keys: %d, %d, %d, %d', si, ai, mc, ri)
    
    -- Returns: boolean hasProgression, number progressionIndex, number lastRankXp, number nextRankXP, number currentXP, boolean atMorph
    local hasProgression, progressionIndex = GetAbilityProgressionXPInfoFromAbilityId(abilityId)

    trace ('Progression Index: %s,  %d', tostring(hasProgression), progressionIndex)
    
    if not hasProgression then
        trace('Ability with ID %d has no progression.', abilityId)
        return 0 
    end


    -- Returns: string name, number morph, number rank
    local _, morph, rank = GetAbilityProgressionInfo(progressionIndex)

    -- Returns: string name, string texture, number abilityIndex
    local name, _, abilityIndex = GetAbilityProgressionAbilityInfo(progressionIndex, morph, rank)
    if abilityIndex then 
        trace('Found ability %s with Index %d for ID %d.', name, abilityIndex, abilityId)
        return abilityIndex 
    else 
        trace('Did not find ability with ID %d.', abilityId)
        return 0 
    end
end

-- Updated to avoid the need to swap bars
function AG.LoadSkill(nr, slot, pair)
    if not nr or not slot or nr <= 0 or slot <= 0 then return end
    if pair == nil then pair = GetActiveWeaponPairInfo() end -- slot on active hotbar if not specified
    if pair ~= 1 and pair ~= 2 then return end -- invalid pair number

    local skillID = AG.setdata[nr].Skill[slot]
    local currentSkillID = GetSlotBoundId(slot + 2, pair - 1)
    if skillID == 0 or skillID == currentSkillID then return end    
    trace('SkillId in slot %d changed. Current: %d new: %d', slot, currentSkillID, skillID)
        
    -- Updated for scribing
    if(IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(skillID))) then
        -- Crafted skill, incoming ability ID is the base ID
        skillID = GetAbilityIdForCraftedAbilityId(skillID)
        trace('Crafted skill to slot: %d', skillID)
    else
        -- Normal skill
        local newAbilityIndex = AG.GetAbility(skillID)
        local currentAbilityIndex = AG.GetAbility(currentSkillID)
        if newAbilityIndex == 0 or newAbilityIndex == currentAbilityIndex then return end
        trace('AbilityIndex has changed, replacing. Current AI: %d, New AI: %d', currentAbilityIndex, newAbilityIndex)    
    end

    local res = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(pair - 1):AssignSkillToSlotByAbilityId(slot + 2, skillID)
    if not res then
       d("|cFF0000Failed to set new skill.|r You are probably in combat, kill a mob and try again!")
    end
end

-- Added to support not needing to swap bars
function AG.LoadSetBars(nr)
    if not nr then return end
    for pair = 1, 2 do
        local skillLineNr = AG.setdata[nr].Set.skill[pair]
        if skillLineNr and skillLineNr > 0 then
            for slot = 1, 6 do AG.LoadSkill(skillLineNr, slot, pair) end
        end
    end
    if AG.isShowWeaponIcon() then AG.ForceUpdateWeaponStats() end
end

function AG.LoadBar(nr)
    -- Updated to skip the delayed call after loading set, both bars are already set
    if SWAP then return end 
    if not nr then return end
    for slot = 1, 6 do AG.LoadSkill(nr,slot) end
end


--[[
function AG.ShowOutfits()
    local n = OFMGR:GetNumOutfits()

    for i = 1, n do
        local ofman = OFMGR:GetOutfitManipulator(i)
        local name = ofman:GetOutfitName()
        d("Available Outfit "..i..":"..name)
    end


    local ofid = OFMGR:GetEquippedOutfitIndex()

    if ofid == nil then
        d("Nothing equipped")
    else
        d("Equipped: "..ofid)
    end
end
--]]

--[[

function AG.SetupOutfitCombo(dropdown, setnr)

    local currentOutfitIndex = AG.setdata[setnr].Set.outfit


    dropdown:ClearItems()

    local function OnKeepOutfitSelected()
        AG.setdata[setnr].Set.outfit = AG.OUTFIT_KEEP
    end

    local function OnNoOutfitSelected()
        AG.setdata[setnr].Set.outfit = AG.OUTFIT_NONE
    end

    local function OnOutfitEntrySelected(_, _, entry)
        AG.setdata[setnr].Set.outfit = entry.outfitIndex
    end

    -- Add Keep-Outfit Item
    local keepOutfitEntry = ZO_ComboBox:CreateItemEntry(L.KeepOutfitItemLabel, OnKeepOutfitSelected)
    dropdown:AddItem(keepOutfitEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    -- Add No-Outfit Item
    local unequippedOutfitEntry = ZO_ComboBox:CreateItemEntry(GetString(SI_NO_OUTFIT_EQUIP_ENTRY), OnNoOutfitSelected)
    dropdown:AddItem(unequippedOutfitEntry, ZO_COMBOBOX_SUPRESS_UPDATE)

    local defaultEntry = unequippedOutfitEntry
    if currentOutfitIndex == AG.OUTFIT_KEEP  then
        defaultEntry = keepOutfitEntry
    end

    -- Add available Outfit Items
    local numOutfits = OFMGR:GetNumOutfits()
    for outfitIndex = 1, numOutfits do
        local outfitManipulator = OFMGR:GetOutfitManipulator(outfitIndex)
        local entry = ZO_ComboBox:CreateItemEntry(outfitManipulator:GetOutfitName(), OnOutfitEntrySelected)
        entry.outfitIndex = outfitIndex
        dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if currentOutfitIndex == outfitIndex then
            defaultEntry = entry
        end
    end

    dropdown:UpdateItems()
    dropdown:SelectItem(defaultEntry)
end

--]]

-- computes a map item-Id -> {pid = profileid, bid = buildid} assigend builds for all items used in builds
function AG.ComputeItemUsageMap()

    local usageMap = {}
    
    for profileId = 1, MAX_PROFILES do
        
        local agModel
        
        if profileId == AG.setdata.currentProfileId then
            agModel = AG.setdata
        else
            agModel = AG.setdata.profiles[profileId].setdata
        end

        if agModel then
            for buildId = 1, MAXSLOT do
                local build = agModel[buildId].Set
                local gearSetId = build.gear
                
                if gearSetId > 0 then
                    local gearSet = agModel[gearSetId].Gear
                    
                    for slot = 1, 16 do
                        local item = gearSet[slot]
                        
                        if item.id ~= 0 then
                        
                            local buildIds = usageMap[item.id]
                            if buildIds == nil then
                                buildIds = {}
                                usageMap[item.id] = buildIds 
                            end
                        
                            table.insert(buildIds, {pid = profileId, bid = buildId})
                        end
                    end
                end
            end
        end
    end
    
    return usageMap
end


function AG.SetupProfileCombo()

    trace ("Current Profile ID: %d, Name: %s", AG.setdata.currentProfileId, AG.setdata.profiles[AG.setdata.currentProfileId].name)

    local dropdown = ZO_ComboBox_ObjectFromContainer(AG_PanelProfilePanel:GetNamedChild("ProfileSelect"))

    dropdown:ClearItems()
    dropdown:SetSortsItems(false)
    
    

    local function OnProfileSelected(_, _, entry)
        AG.LoadProfile(entry.profileId)
    end

    --- sorts the profiles according to their sortKey
    -- a profile w/o sortKey will be sorted to the end of the list
    local function ProfileSortHelper(item1, item2)
        local sortKey1 = item1.sortKey
        if not sortKey1 or sortKey1 == "" then
            sortKey1 = 'zzzzzzzzzzzzzzzzzzzzzzzz'..item1.name
        end
        
        local sortKey2 = item2.sortKey
        if not sortKey2 or sortKey2 == "" then
            sortKey2 = 'zzzzzzzzzzzzzzzzzzzzzzzz'..item2.name
        end

        return (sortKey1 < sortKey2)
    end

    
    -- store the current profile
    local currentProfile = AG.setdata.profiles[AG.setdata.currentProfileId]
    
    -- Sort the entries according to profile sort index
    -- will invalidate currentProfileId
    table.sort(AG.setdata.profiles, function(item1, item2) return ProfileSortHelper(item1, item2) end)  
    
    -- reset cached IDs
    AG.previousSet = nil
    -- AG.previousProfile = nil
    
    local defaultEntry

    -- Add available Profiles
    for profileId = 1, MAX_PROFILES do
        local profile = AG.setdata.profiles[profileId]
        local entry = ZO_ComboBox:CreateItemEntry(profile.name, OnProfileSelected)
        entry.profileId = profileId
        dropdown:AddItem(entry, ZO_COMBOBOX_SUPRESS_UPDATE)
        if currentProfile == profile then
            defaultEntry = entry
            AG.setdata.currentProfileId = profileId
        end
    end

    dropdown:UpdateItems()
    dropdown:SelectItem(defaultEntry)
end


function AG.LoadOutfit(outfitid)
    if not outfitid then return end

    if outfitid == AG.OUTFIT_NONE then
        OFMGR:UnequipOutfit(GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    elseif outfitid == AG.OUTFIT_KEEP then
        -- Just do nothing
    else
        OFMGR:EquipOutfit(GAMEPLAY_ACTOR_CATEGORY_PLAYER, outfitid)
    end
end

function AG.LoadOutfitOrStyle(buildID)
    local AGplugAS = AG.plugins.AlphaStyle
    if AGplugAS.useAddon() then
        AGplugAS.LoadStyle(AG.setdata[buildID].Set.AlphaStyleId)
    else
        AG.LoadOutfit (AG.setdata[buildID].Set.outfit)
    end

end

function AG.LoadChampionPoints(buildID)
    local AGplugCPS = AG.plugins.CPSlots
    if AGplugCPS.useAddon() then
        AGplugCPS.LoadCPSProfile(AG.setdata[buildID].Set.CPSHostName, AG.setdata[buildID].Set.CPSProfileName)
    end

    local AGplugDCP = AG.plugins.DynamicCP
    if (AGplugDCP.useAddon()) then
        AGplugDCP.LoadSlottableSets({
            Green = AG.setdata[buildID].Set.DCPSlotSetGreen,
            Blue = AG.setdata[buildID].Set.DCPSlotSetBlue,
            Red = AG.setdata[buildID].Set.DCPSlotSetRed,
        })
    end
end

function AG.ToggleSet()
    if AG.setdata.lastset and AG.previousSet then
        AG.LoadSet (AG.previousSet)
    else
        d(L.MsgNoPreviousSet)
    end
end

function AG.LoadNextSet()
    -- init after reload
    if not AG.setdata.lastset or AG.setdata.lastset == 0 then
        AG.setdata.lastset = 1
    end

    local nextSet = AG.setdata.lastset
    local oldSet = AG.setdata.lastset

    repeat
        if nextSet < MAXSLOT then
            nextSet = nextSet + 1
        else
            nextSet = 1
        end
        trace ("loop through builds: old "..oldSet.." new "..nextSet)
    until (nextSet == oldSet) or (not AG.IsBuildEmpty(AG.setdata, nextSet))

    AG.LoadSet (nextSet)
end

function AG.LoadPreviousSet()
    -- init after reload
    if not AG.setdata.lastset or AG.setdata.lastset == 0 then
        AG.setdata.lastset = 1
    end

    local nextSet = AG.setdata.lastset
    local oldSet = AG.setdata.lastset

    repeat
        if nextSet > 1 then
            nextSet = nextSet - 1
        else
            nextSet = MAXSLOT
        end
        trace ("loop through builds: old "..oldSet.." new "..nextSet)
    until (nextSet == oldSet) or (not AG.IsBuildEmpty(AG.setdata, nextSet))

    AG.LoadSet (nextSet)
end


--- equips gear, activates skills and deals with outfits as configured in a set
-- @param nr Number of set to load
function AG.LoadSet(nr)
    if not nr then return end

    if IsUnitInCombat("player") then 
        AG.pendingSet = nr
        d(ZOSF(L.SetChangeQueuedMsg, nr, AG.setdata[nr].Set.text[1]))
    else
        AG.LoadSetInternal(nr)
    end

end


--- does the work of equipping. No checks
function AG.LoadSetInternal(nr)
    trace("LoadSetInternal: %d", nr)

    if ZO_ActionBar_AreActionBarsLocked() then
        d("Action bars are locked. Can't load set. You might have to reload the UI!")
        return
    end
    
    -- seems to be unnecessary

    --[[
    -- sheathe weapons
    if not ArePlayerWeaponsSheathed() then
        TogglePlayerWield()
        trace("Weapons sheathed")
    end
    --]]

    if nr ~= AG.setdata.lastset then
        AG.previousSet = AG.setdata.lastset
    end
    AG.setdata.lastset = nr
    AG.pendingSet = -1

    local pair = GetActiveWeaponPairInfo()

    -- set outfit or Style
    AG.LoadOutfitOrStyle(nr)

    -- load gear
    if AG.setdata[nr].Set.gear ~= 0 then AG.LoadGear(AG.setdata[nr].Set.gear, nr) end

    -- load skills
    -- Updated to avoid waiting until gear is loaded
    table.insert(AG.Jobs, {AG.JOB_TYPE_LOAD_SKILL_BAR, nr, nil})
    --if AG.setdata[nr].Set.skill[pair] ~= 0 then
    --    table.insert(AG.Jobs, {AG.JOB_TYPE_LOAD_SKILL_BAR, AG.setdata[nr].Set.skill[pair], nil})
    --    --- AG.LoadBar(AG.setdata[nr].Set.skill[pair])
    --end

    -- Load Champion Points
    AG.LoadChampionPoints(nr)

    -- queue in swap message
    SWAP = true
    table.insert(AG.Jobs, {AG.JOB_TYPE_SHOW_SWAP_MSG, nil, nil})

    d("Loading Set " .. tostring(AG.setdata[nr].Set.text[1]))
end

function AG.Undress(mode)

    table.insert(AG.Jobs, {AG.JOB_TYPE_PREPARE_TOON, 0, 0})

    table.insert(AG.Jobs, {AG.JOB_TYPE_START_BULK_MODE, 0, 0})

    if mode == 1 then 
        -- only armor
        for x = 5, 11 do 
            table.insert(AG.Jobs, {AG.JOB_TYPE_UNEQUIP_GEAR, SLOTS[x][1]}) 
        end
    else 
        -- armor and weapons
        for _,x in pairs(SLOTS) do 
            table.insert(AG.Jobs, {AG.JOB_TYPE_UNEQUIP_GEAR, x[1]}) 
        end 
    end

    table.insert(AG.Jobs, {AG.JOB_TYPE_STOP_BULK_MODE, 0, 0})

    -- update ui afterwards
    table.insert (AG.Jobs, {AG.JOB_TYPE_UPDATE_UI, 0, 0})
end

--- moves an item from one bag to another
-- returns true is successful
function AG.DoTransfer(sourceBagId, sourceBagSlot, targetBagId)
    local emptySlotIndex = FindFirstEmptySlotInBag(targetBagId)
    local result = CallSecureProtected("RequestMoveItem", sourceBagId, sourceBagSlot, targetBagId, emptySlotIndex, 200)
    if not result then
        local link = GetItemLink(sourceBagId, sourceBagSlot)
        d(ZOSF(L.FailedToMoveItem, link))         
    end
    return result
end


--- withdraws an item from the bank 
-- returns true if successfull
function AG.WithdrawItem(itemId)

    local sourceBagId, sourceBagSlot = AG.GetItemFromBag(itemId)

    -- not found
    if sourceBagSlot == nil then 
        return false 
    end

    -- only items not worn and not in backpack can be withdrawn
    if sourceBagId == BAG_BACKPACK or sourceBagId == BAG_WORN then 
        return false 
    end

    if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
        local link = GetItemLink(sourceBagId, sourceBagSlot)
        d(ZOSF(L.NotEnoughSpaceInBackPack, link))
        return false 
    end

    local result = AG.DoTransfer(sourceBagId, sourceBagSlot, BAG_BACKPACK)
    return result
end

--- deposits an item in the bank 
-- returns true if successfull
function AG.DepositItem(itemId)

    local sourceBagId, sourceBagSlot = AG.GetItemFromBag(itemId)

    -- not found
    if sourceBagSlot == nil then 
        return false 
    end

    -- only items worn or in backpack can be deposited
    if sourceBagId ~= BAG_BACKPACK and sourceBagId ~= BAG_WORN then 
        return false 
    end

    if IsItemStolen(sourceBagId, sourceBagSlot) then
        local link = GetItemLink(sourceBagId, sourceBagSlot)
        d(ZOSF(L.ItemIsStolen, link)) 
        return false 
    end

    -- GetBankingBag() returns BAG_BANK for BAG_BANK and BAG_SUBSCRIBER_BANK, and BAG_HOUSE_BANK_nnn for house banking
    local bankingBag = GetBankingBag()
    local trySubscriberBank = bankingBag == BAG_BANK

    if GetNumBagFreeSlots(bankingBag) > 0 then
        local result = AG.DoTransfer(sourceBagId, sourceBagSlot, bankingBag)
        return result
    elseif trySubscriberBank and GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK) > 0 then
        local result = AG.DoTransfer(sourceBagId, sourceBagSlot, BAG_SUBSCRIBER_BANK)
        return result
    end

    local link = GetItemLink(sourceBagId, sourceBagSlot)
    d(ZOSF(L.NotEnoughSpaceInBank, link)) 
    return false 
end

--- moves an item from bag_worn to bag_bacpack 
-- returns true if successfull
function AG.UnequipItem(slot)

    if not GetItemInstanceId(BAG_WORN, slot) then
        trace("Nothing to unequip in slot %d", slot)
        return false
    end

    if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
        local link = GetItemLink(BAG_WORN, slot)
        d(ZOSF(L.NotEnoughSpaceInBackPack, link))         
        return false
    end

    -- try to unequipp 
    trace("Unequipping slot %d", slot)
    local result = AG.DoTransfer(BAG_WORN, slot, BAG_BACKPACK)
    return result
end

function AG.EquipItem(gear, targetSlot)

    -- return true, if we must wait
    local result = false
    
    -- anything to change?
    local itemId = AG.GetIdTypeAndLink(BAG_WORN, targetSlot)
    if itemId ~= gear.id then

        -- find item in one of the bags
        local sourceBag, sourceBagSlot = AG.GetItemFromBag(gear.id)

        if sourceBagSlot then 
            -- equip the found item
            EquipItem(sourceBag, sourceBagSlot, targetSlot)

            -- the equipped item has changed place with the item, that was in the targetSlot. Update cache accordingly
            AG.SwapItemInCache (targetSlot, sourceBag, sourceBagSlot)
            
            result = true
        else
            d(ZOSF(L.NotFound, gear.link)) 
        end 
    end
    
    return result
end


--- moves all gear sets of the current profile to or from BAG_BACKPACK
-- @param deposit: if true then deposit the set to the current open bank, else withdraw
function AG.MoveGearSetAll(deposit)

    table.insert(AG.Jobs, {AG.JOB_TYPE_PREPARE_TOON, 0, 0})

    table.insert(AG.Jobs, {AG.JOB_TYPE_START_BULK_MODE, 0, 0})

    for setIndex = 1, MAXSLOT do 
        AG.MoveGearSet(deposit, setIndex, false)        
    end

    table.insert(AG.Jobs, {AG.JOB_TYPE_STOP_BULK_MODE, 0, 0})

    -- update ui afterwards
    table.insert (AG.Jobs, {AG.JOB_TYPE_UPDATE_UI, 0, 0})
end

--- moves a gear set to or from BAG_BACKPACK
-- @param deposit: if true then deposit the set to the current open bank, else withdraw
-- @param nr: number of set
function AG.MoveGearSet(deposit, nr, update)
    if not nr then return end
    AG.ClearAvailableEquipmentCachePlain()

    if update then
        table.insert(AG.Jobs, {AG.JOB_TYPE_PREPARE_TOON, 0, 0})

        table.insert(AG.Jobs, {AG.JOB_TYPE_START_BULK_MODE, 0, 0})
    end

    table.insert(AG.Jobs, {AG.JOB_TYPE_MESSAGE, ZOSF(L.MovingSet, nr)})


    for slotIndex = 1, #SLOTS do 
        local id = AG.setdata[nr].Gear[slotIndex].id
        if id and id ~= 0 then
            if deposit then
                table.insert(AG.Jobs, {AG.JOB_TYPE_DEPOSIT_GEAR, id}) 
            else
                table.insert(AG.Jobs, {AG.JOB_TYPE_WITHDRAW_GEAR, id}) 
            end
        end
    end

    table.insert(AG.Jobs, {AG.JOB_TYPE_MESSAGE, "Done"})

    if update then
        table.insert(AG.Jobs, {AG.JOB_TYPE_STOP_BULK_MODE, 0, 0})
        table.insert (AG.Jobs, {AG.JOB_TYPE_UPDATE_UI, 0, 0})
    end
end

function AG.PrepareToon()
    local mustWait = false

    -- seems to be unnecessary

    --[[
    if not ArePlayerWeaponsSheathed() then
        TogglePlayerWield()
        mustWait = true
    end    
    --]]

    return mustWait
end

function AG.LockBags()
    -- one transfer requires two locks
    AG.BagsLockCount = 2
end

function AG.UnlockBags()
    AG.BagsLockCount = AG.BagsLockCount - 1
end

function AG.IsBagsLocked()
    return AG.BagsLockCount > 0
end


function AG.HandleOnUpdate()
    -- Updated with shorter delays for faster loading
    local ITEM_MOVE_DELAY = 1
    local SKILL_CHANGE_DELAY = 1
    local PREPRARE_TOON_DELAY = 100

    if AG.init and #AG.Jobs > 0 then
        local CurrentTime = GetGameTimeMilliseconds()

        if (CurrentTime >= AG.NextEventTime or AG.NextEventTime == 0) and (not AG.IsBagsLocked()) then
            -- get next job
            local job =  AG.Jobs[1]
            local jobType, param1, param2, param3 = job[1], job[2], job[3], job[4]
            local delay = 0

            if (jobType == AG.JOB_TYPE_UNEQUIP_GEAR) then
                if AG.UnequipItem(param1) then
                    AG.LockBags()
                end
            elseif (jobType == AG.JOB_TYPE_PREPARE_TOON) then
                if AG.PrepareToon() then
                    delay = PREPRARE_TOON_DELAY
                end
            elseif (jobType == AG.JOB_TYPE_EQUIP_GEAR) then
                if AG.EquipItem(param1, param2) then
                    delay = ITEM_MOVE_DELAY
                end
            elseif (jobType == AG.JOB_TYPE_WITHDRAW_GEAR) then
                if AG.WithdrawItem(param1) then
                    AG.LockBags()
                end
            elseif (jobType == AG.JOB_TYPE_DEPOSIT_GEAR) then
                if AG.DepositItem(param1) then
                    AG.LockBags()
                end
            elseif (jobType == AG.JOB_TYPE_UPDATE_UI) then
                trace("EVT: update UI")
                if not AG.InBulkMode then
                    AG.UpdateUI() 
                end
            elseif (jobType == AG.JOB_TYPE_LOAD_SKILL_BAR) then
                -- Updated to load both bars without swapping
                AG.LoadSetBars(param1)
                delay = SKILL_CHANGE_DELAY
            elseif (jobType == AG.JOB_TYPE_START_BULK_MODE) then
                AG.InBulkMode = true
                -- d("bulk mode START")
                -- AG.bulkStartTime = GetGameTimeMilliseconds()
                trace("EVT: bulkmode on")
            elseif (jobType == AG.JOB_TYPE_STOP_BULK_MODE) then
                AG.InBulkMode = false
                -- d("bulk mode STOP")
                -- d(string.format("bulk transfer took %d ms", GetGameTimeMilliseconds() - AG.bulkStartTime))
                trace("EVT: bulkmode off")
                -- Kyzer 11/25/21: apply the sort after bulk mode finishes
                PLAYER_INVENTORY:UpdateList(AG.recentInventoryType)
            elseif (jobType == AG.JOB_TYPE_SHOW_SWAP_MSG) then
                AG_SwapMessage:SetHidden(true)
                AG_SwapMessageBg:SetHidden(true)
                AG.SwapMessage()
            elseif (jobType == AG.JOB_TYPE_MESSAGE) then
                d(param1)
            end

            table.remove(AG.Jobs, 1) 
            
            -- next event in <delay> ms from now
            AG.NextEventTime = GetGameTimeMilliseconds() + delay
        end
    end
end


function AG.Animate(fadeIn,slideIn,fadeOut)
    trace('Animate')
    local a = ANIMATION_MANAGER:CreateTimeline()
    local c = AG_SwapMessage
    if fadeIn then
        local fi = a:InsertAnimation(ANIMATION_ALPHA,c)
        c:SetAlpha(0)
        c:SetHidden(false)
        -- c:SetAnchor(2,AG_SwapMessageBg,8,0,0)
        fi:SetAlphaValues(0,1)
        fi:SetDuration(400)
    end
    if fadeOut then
        local fo = a:InsertAnimation(ANIMATION_ALPHA,c,fadeOut)
        fo:SetAlphaValues(1,0)
        fo:SetDuration(150)
    end
    if slideIn then
        local si = a:InsertAnimation(ANIMATION_TRANSLATE,c)
        si:SetStartOffsetX(800)
        si:SetEndOffsetX(15)
        si:SetStartOffsetY(-22)
        si:SetEndOffsetY(-22)
        si:SetDuration(500)
        si:SetEasingFunction(ZO_GenerateCubicBezierEase(.25,.5,.4,1.2))
    end
    a:PlayFromStart()
end

function AG.UpdateRepair(_,bag)
    trace('UpdateRepair')

    if bag ~= BAG_WORN then return end
    local condition, count, allcost, con, minval = 0, 0, 0, 0, 100
    for _,c in pairs(SLOTS) do
        if DoesItemHaveDurability(BAG_WORN,c[1]) then
            con = GetItemCondition(BAG_WORN,c[1])
            if con <= minval then minval = con end
            condition = condition + con
            allcost = allcost + GetItemRepairCost(BAG_WORN,c[1])
            count = count + 1
        end
    end
    
    if count == 0 then
        minval = ''
        condition = 0
    else
        if minval < 100 then minval = ' ('..minval..'%)' else minval = '' end
        condition = math.floor(condition/count) or 0
    end
    
    AG_RepairTex:SetColor(GetColor(condition,1))
    AG_RepairValue:SetText(condition..'%'..minval)
    AG_RepairValue:SetColor(GetColor(condition,1))
    AG_RepairCost:SetText(allcost..' |t12:12:esoui/art/currency/currency_gold.dds|t')
end



function AG.showItemLevel(lblLevel, itemLink, silChoice)

    local requiredLevel = GetItemLinkRequiredLevel(itemLink)
    local requiredChampionPoints = GetItemLinkRequiredChampionPoints(itemLink)
    local dRelLevel

    local playerCP = GetPlayerChampionPointsEarned()

    -- current max for CP is 160
    if playerCP > 160 then playerCP = 160 end

    
    if requiredChampionPoints > 0 then
        -- the Item has CP, thus the player has at least as many CP
        dRelLevel = math.floor(requiredChampionPoints^2 / playerCP^2 * 100)
        
        -- local pointsString = failed and ZO_ERROR_COLOR:Colorize(requiredChampionPoints) or ZO_DEFAULT_ENABLED_COLOR:Colorize(requiredChampionPoints)
        -- self:AddSubLabel(zo_iconFormat(GetChampionPointsIcon(), "40", "40"))
        -- self:AddSubLabel(pointsString)
        -- strLabel = zo_iconFormat(GetChampionPointsIcon(), "10", "10")..requiredChampionPoints
    elseif requiredLevel > 0 then
        -- item doesn't have CP, but maybe the player

        local playerLevel = GetUnitLevel("player")
        local virtLevel = playerLevel + playerCP / 10

        dRelLevel = math.floor(requiredLevel^2 / virtLevel^2 * 100)
        
        -- local levelString = failed and ZO_ERROR_COLOR:Colorize(requiredLevel) or ZO_DEFAULT_ENABLED_COLOR:Colorize(requiredLevel)
        -- self:AddSubLabel(GetString(SI_ITEM_FORMAT_STR_LEVEL))
        -- self:AddSubLabel(levelString)
        -- strLabel = requiredLevel
    else
        -- item has level 0
        dRelLevel = 0.0
    end
    
    if dRelLevel == 100 and silChoice == AG.CHOICE_SHOW_ITEM_LEVEL_LOW then
        lblLevel:SetHidden(true)
    else
        if dRelLevel == 100 then
            lblLevel:SetTexture('AlphaGear/asset/lvlcirc.dds')
        else
            lblLevel:SetTexture('AlphaGear/asset/lvldown.dds')
        end
        -- self:AddSubLabel(GetItemLinkFlavorText(itemLink))
        -- lblLevel:SetText(strLabel)
        lblLevel:SetHidden(false)
        lblLevel:SetColor(GetColor(dRelLevel, 0.9))
    end

end


--- Updates the condition indicator controls.
-- Sets the color depending on the condition of the item
-- Only for items currently equipped.
function AG.UpdateCondition(_,bag,slot)
    if bag ~= BAG_WORN or slot == EQUIP_SLOT_COSTUME then
        return
    end
    
    local t = WM:GetControlByName('AG_InvBg'..slot)
    local l = WM:GetControlByName('AG_InvBg'..slot..'Condition')
    local lblLevel = WM:GetControlByName('AG_InvBg'..slot..'Level')
    
    local p = t:GetParent()
    local s

    p:SetMouseOverTexture(not ZO_Character_IsReadOnly() and 'AlphaGear/asset/mo.dds' or nil)
    p:SetPressedMouseOverTexture(not ZO_Character_IsReadOnly() and 'AlphaGear/asset/mo.dds' or nil)
    
    s = p:GetNamedChild('DropCallout')
    s:ClearAnchors()
    s:SetAnchor(1,p,1,0,2)
    s:SetDimensions(52,52)
    s:SetTexture('AlphaGear/asset/spot.dds')
    s:SetDrawLayer(0)
    
    s = p:GetNamedChild('Highlight')
    if s then
        s:ClearAnchors()
        s:SetAnchor(1,p,1,0,2)
        s:SetDimensions(52,52)
        s:SetTexture('AlphaGear/asset/spot.dds')
    end
    
    if GetItemInstanceId(BAG_WORN, slot) then
        local itemLink = GetItemLink(BAG_WORN,slot)
        
        if AG.isShowItemCondition() then
            t:SetHidden(false)
            t:SetColor(Quality(itemLink, 1))
        else 
            t:SetHidden(true) 
        end
        
        if AG.isShowItemCondition() and DoesItemHaveDurability(BAG_WORN,slot) then
            local con = GetItemLinkCondition(itemLink)
            l:SetText(con..'%')
            l:SetColor(GetColor(con,0.9))
            l:SetHidden(false)
        else 
            l:SetHidden(true) 
        end
        
        local silChoice = AG.getShowItemLevel()
        if silChoice ~= AG.CHOICE_SHOW_ITEM_LEVEL_NEVER then
            AG.showItemLevel(lblLevel, itemLink, silChoice)
        else
            lblLevel:SetHidden(true)
        end
    else
        t:SetHidden(true)
        l:SetHidden(true)
        lblLevel:SetHidden(true)
    end
end


--- returns the label of the key bound to the control with name keyStr
function AG.GetKey(keyStr)
    -- trace('GetKey')
    local modifier = ''
    local l,c,a = GetActionIndicesFromName(keyStr)
    local key,m1,m2,m3,m4 = GetActionBindingInfo(l,c,a,1)
    if key ~= KEY_INVALID then
        local shift = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_SHIFT,m1,m2,m3,m4)
        local ctrl = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_CTRL,m1,m2,m3,m4)
        local alt = ZO_Keybindings_DoesKeyMatchAnyModifiers(KEY_ALT,m1,m2,m3,m4)
        if alt then modifier = modifier..string.format('%s-',string.upper(string.sub(GetString(SI_KEYCODEALT),1,8)))
        elseif ctrl then modifier = modifier..string.format('%s-',string.upper(string.sub(GetString(SI_KEYCODECTRL),1,8)))
        elseif shift then modifier = modifier..string.format('%s-',string.upper(string.sub(GetString(SI_KEYCODESHIFT),1,8))) end
        return modifier..GetKeyName(key)
    else return '' end
end


function AG.UpdateGearBorder(set)

    for slotIndex = 1, #SLOTS do 
        local b = WM:GetControlByName('AG_Button_Gear_'..set..'_'..slotIndex..'Bg')

        b:SetEdgeColor(AG.GetItemBorderColor(set, slotIndex))
    end
end

function AG.UpdateSetButtons()
    -- update profile name in set buttons widget
    local profileLabel
    if AG.setdata.currentProfileId then
        profileLabel = AG.setdata.profiles[AG.setdata.currentProfileId].name
    else 
        profileLabel = "Unknown"
    end
    AG_SetButtonFrameProfileName:SetText(profileLabel)
end

function AG.UpdateItemLinks()
    trace("UpdateItemLinks")
    for setId = 1, MAXSLOT do

        local set = AG.setdata[setId].Set
        if set.gear > 0 then
            local gear = AG.setdata[set.gear].Gear
            -- update itemlinks
            for slot = 1, #SLOTS do
                if gear[slot].id ~= 0 then
                    local sourceBagId, sourceBagSlot = AG.GetItemFromBag(gear[slot].id)

                    -- found
                    if sourceBagSlot ~= nil then 
                        local newLink = GetItemLink(sourceBagId, sourceBagSlot)                    
                        gear[slot].link = newLink
                    end
                end
            end
        end
    end
end


function AG.UpdateUI(from,to)
    trace('UpdateUI')
    if AG_Panel:IsHidden() then
        return
    end

    if not from then from = 1 end
    if not to then to = MAXSLOT end
    local text = 'text'
    for x = from, to do
        if AG.setdata[x].Set.text[1] == 0 then text = 'Build '..x else text = AG.setdata[x].Set.text[1] end
        local header, c = '|cFFAA33'..text..'|r', ''
        WM:GetControlByName('AG_SetSelector_'..x).data = { header = header, info = L.Set }
        WM:GetControlByName('AG_SetSelector_'..x..'KeyBind'):SetText(AG.GetKey('AG_SET_'..x))
        c = WM:GetControlByName('AG_SetSelector_'..x..'Box')
        c:SetText('  '..text)
        AG.UpdateGearBorder(x)
    end
    
    AG.SetupProfileCombo()  
end

function AG.UpdateEditPanel(nr)
    if not nr then return end
    local val, set, c, _ = nil, AG.setdata[nr].Set

    -- Draws two rows of skill buttons in selected set
    for x = 1,2 do
        for slot = 1,6 do
            if set.skill[x] ~= 0 and AG.setdata[set.skill[x]].Skill[slot] ~= 0 then
            
                -- Updated for scribing
                if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(AG.setdata[set.skill[x]].Skill[slot])) then
                    -- Crafted skill, get the specific version slotted
                    local slottedId = GetAbilityIdForCraftedAbilityId(AG.setdata[set.skill[x]].Skill[slot])
                    val = GetAbilityIcon(slottedId)
                else
                    -- Normal skill
                    local abilityIndex = AG.GetAbility(AG.setdata[set.skill[x]].Skill[slot])
                    _, val = GetAbilityInfoByIndex(abilityIndex)
                end
                
            else 
                val = nil 
            end
            WM:GetControlByName('AG_Edit_Skill_'..x..'_'..slot):SetNormalTexture(val)
        end
    end

    -- Draws the gear buttons
    for slot = 1, #SLOTS do
        c = WM:GetControlByName('AG_Edit_Gear_1_'..slot)
        if set.gear > 0 and AG.setdata[set.gear].Gear[slot].id ~= 0 then
            c:SetNormalTexture(GetItemLinkInfo(AG.setdata[set.gear].Gear[slot].link))
            c:GetNamedChild('Bg'):SetCenterColor(Quality(AG.setdata[set.gear].Gear[slot].link,0.5))
        else
            c:SetNormalTexture('esoui/art/characterwindow/gearslot_'..SLOTS[slot][2]..'.dds')
            c:GetNamedChild('Bg'):SetCenterColor(0,0,0,0.2)
        end
    end

    -- draws skill bar 1
    if set.gear ~= 0 and AG.setdata[set.gear].Gear[1].id ~= 0 then val = Zero(set.icon[1]) or AG.GetSetIcon(set.gear,1)
    else val = Zero(set.icon[1]) or 'x.dds' end
    AG_PanelSetPanelScrollChildEditPanelSetBar1PanelBar1IconTex:SetTexture(val)
    

    -- draws skill bar 2
    if set.gear ~= 0 and AG.setdata[set.gear].Gear[3].id ~= 0 then val = Zero(set.icon[2]) or AG.GetSetIcon(set.gear,2)
    else val = Zero(set.icon[2]) or 'x.dds' end
    AG_PanelSetPanelScrollChildEditPanelSetBar2PanelBar2IconTex:SetTexture(val)

    -- builds set label for tooltip
    if AG.setdata[nr].Set.text[1] == 0 then val = '|cFFAA33Set '..nr..'|r' else val = '|cFFAA33'..AG.setdata[nr].Set.text[1]..'|r' end
    
    -- draws gear connector
    c = AG_PanelSetPanelScrollChildEditPanelSetGearPanelGearConnector
    c:SetText(Zero(set.gear) or '')
    c.data = { header = val, info = L.SetConnector[1] }

    -- draws bar 1 connector
    c = AG_PanelSetPanelScrollChildEditPanelSetBar1PanelBar1Connector
    c:SetText(Zero(set.skill[1]) or '')
    c.data = { header = val, info = L.SetConnector[2] }

    -- configure skill bar 1 icon tooltip
    c = AG_PanelSetPanelScrollChildEditPanelSetBar1PanelBar1Icon
    c.data = { header = val, info = L.ToolTipSkillIcon }

    -- draws bar 2 connector
    c = AG_PanelSetPanelScrollChildEditPanelSetBar2PanelBar2Connector
    c:SetText(Zero(set.skill[2]) or '')
    c.data = { header = val, info = L.SetConnector[3] }

    -- configure skill bar 2 icon tooltip
    c = AG_PanelSetPanelScrollChildEditPanelSetBar2PanelBar2Icon
    c.data = { header = val, info = L.ToolTipSkillIcon }
    
    
    -- draws set lock
    c = AG_PanelSetPanelScrollChildEditPanelSetGearPanelGearLockTex
    if set.lock == 0 then c:SetTexture('AlphaGear/asset/unlocked.dds') else c:SetTexture('AlphaGear/asset/locked.dds') end

    -- fills text edit for Bars
    AG_PanelSetPanelScrollChildEditPanelSetBar1PanelBar1NameEdit:SetText(Zero(set.text[2]) or L.ActionBar1Text)
    AG_PanelSetPanelScrollChildEditPanelSetBar2PanelBar2NameEdit:SetText(Zero(set.text[3]) or L.ActionBar2Text)
    
    -- fills text edit for Set Label
    WM:GetControlByName('AG_SetSelector_'..nr..'Edit'):SetText(Zero(set.text[1]) or 'Build '..nr)

    --[[
    -- updates the outfitCombo
    c = ZO_ComboBox_ObjectFromContainer(AG_PanelSetPanelScrollChildEditPanelSetSettings:GetNamedChild("Dropdown"))
    AG.SetupOutfitCombo(c, nr)
    --]]
end



function AG:CommitEditProfileDialog(control)
    local ctrlContent = GetControl(control, "Content")
    local editProfileName = GetControl(ctrlContent, "ProfileName")
    local editProfileSortKey = GetControl(ctrlContent, "ProfileSortKey")

    local oldName = AG.setdata.profiles[AG.setdata.currentProfileId].name
    
    AG.setdata.profiles[AG.setdata.currentProfileId].name = editProfileName:GetText()
    AG.setdata.profiles[AG.setdata.currentProfileId].sortKey = editProfileSortKey:GetText()
    
    if oldName ~= AG.setdata.profiles[AG.setdata.currentProfileId].name then
        d("Profile '"..oldName.."' renamed to '"..AG.setdata.profiles[AG.setdata.currentProfileId].name.."'")
    end
    
    AG.UpdateSwapMessage()
    AG.SetupProfileCombo()
    
    
end

function AG:InitializeEditProfileDialog(control)
    local ctrlContent = GetControl(control, "Content")
    local editProfileName = GetControl(ctrlContent, "ProfileName")
    local editProfileSortKey = GetControl(ctrlContent, "ProfileSortKey")

    
    editProfileName:SetText(AG.setdata.profiles[AG.setdata.currentProfileId].name)
    editProfileSortKey:SetText(AG.setdata.profiles[AG.setdata.currentProfileId].sortKey or '')
end


-- Initialize EditProfileDialog
function AG.InitEditProfileDialog()
    local control = AGEditProfileDialog

    ZO_Dialogs_RegisterCustomDialog("AG_EDIT_PROFILE_DIALOG", {
        customControl = control,
        title = { text = "Profile Properties" },
        setup = function(self) AG:InitializeEditProfileDialog(control) end,
        buttons =
        {
            {
                control =   GetControl(control, "Accept"),
                text =      SI_DIALOG_ACCEPT,
                keybind =   "DIALOG_PRIMARY",
                callback =  function(dialog)
                                AG:CommitEditProfileDialog(control)
                            end,
            },  
            {
                control =   GetControl(control, "Cancel"),
                text =      SI_DIALOG_CANCEL,
                keybind =   "DIALOG_NEGATIVE",
                callback =  function(dialog)
                            end,
            },
        
        },
    })
end
 
function AG.ShowEditProfileDialog()
    ZO_Dialogs_ShowDialog("AG_EDIT_PROFILE_DIALOG", {})
end

function AG.ShowAdvancedOptionsDialog()
    ZO_Dialogs_ShowDialog("AG_ADVANCED_BUILD_DIALOG", {buildNr = SELECT, buildName = Zero(AG.setdata[SELECT].Set.text[1]) or 'Build '..SELECT})
end

function AG.ShowImportDialog()
    ZO_Dialogs_ShowDialog("AG_IMPORT_DIALOG", {})
end


--- initializes the callback for drawing AG or FCOIS marks on gear items
function AG.SetupInventoryCallback()
    --> BAERTRAM - FCOIS
    local inv = AG.markerInventories
    --< BAERTRAM - FCOIS
    
    -- hide AG marker if present
    local function HideAGMarker(c)
        if not c then return end
        local name = c:GetName()
        
        if MARK[name] then
            -- hide marker
            MARK[name]:SetHidden(true)
        end
    end
    
    -- set AG marker for item
    local function ShowAGMarker(c)
        if not c then return end
        
        local name = c:GetName()
            
        if not MARK[name] then
            MARK[name] = WM:CreateControl(name..'AG_ItemMark',c,CT_TEXTURE) 
        end
            
        MARK[name]:SetDrawLayer(3)
        MARK[name]:SetDimensions(12,12)
        MARK[name]:ClearAnchors()
        MARK[name]:SetAnchor(6,c:GetNamedChild('Bg'),6,2,0)
        MARK[name]:SetTexture('AlphaGear/asset/mark.dds')
        MARK[name]:SetHidden(false)
    end

    
    -- called for each visible item in bag
    -- called from callback function as defined below
    local function UpdateItemMarker(c, slot)
        local markGearWithAG = AG.isMarkSetItemsInBag()
        
        -- always hide AG marker 
        HideAGMarker(c)

        -- set new AG marker, uppdate FCOIS marker
        if markGearWithAG then

            local slotInfo = c.dataEntry.data or nil
            if not slotInfo then return end

            local uid = AG.GetIdTypeAndLink(slotInfo.bagId, slotInfo.slotIndex)
            if not uid then return end

            -- find all the builds, that use this item
           
            local setData
            for profileId = 1, MAX_PROFILES do

                if profileId == AG.setdata.currentProfileId then
                    setData = AG.setdata
                else
                    setData = AG.setdata.profiles[profileId].setdata
                end

                if setData then
                    for setId = 1, MAXSLOT do
                        for slotId = 1,16 do
                            if setData[setId].Gear[slotId].id == uid then
                                -- item is part of at least one gear-set
                                ShowAGMarker(c)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    
    
    
    -- register callback to all bags in AG.markerInventories
    for x = 1, #inv do
        local prevCallback = inv[x].dataTypes[1].setupCallback
        
        inv[x].dataTypes[1].setupCallback = function(c, slot)
            prevCallback(c, slot)
            UpdateItemMarker(c, slot)
        end
    end
end


--- Tests, whether an item is available in BAG or WORN or not
-- @param nr Number of set
-- @slotIndex index of the slot
-- returns -2: No Item; -1: Item not found in available bags; > 0: BAG-ID
function AG.GetItemLocation(nr, slotIndex) 
    if not nr or not slotIndex then return -2 end

    local id = AG.setdata[nr].Gear[slotIndex].id
    if not id or id == 0 then return -2 end

    local function isWornInSlot (index)
        if not index then 
            return false
        end

        local wornSlot = SLOTS[index][1]

        local wornId = AG.GetIdTypeAndLink(BAG_WORN, wornSlot)

        if wornId == id then
            return true
        end
    end

    -- currently worn?
    if isWornInSlot(slotIndex) then
        trace ("found in same slot: %s", id)
        return BAG_WORN
    end

    -- not found? try twin slot
    if isWornInSlot(TWINSLOTS[slotIndex]) then
        trace ("found in twin slot: %s", id)
        return BAG_WORN
    end

    -- still not found. look in bags
    local sourceBag, sourceBagSlot = AG.GetItemFromBag(id)
    if sourceBagSlot == nil then
        return -1
    else
        return sourceBag
    end
end

function AG.GetItemBorderColor(nr, slotIndex)
    local loc = AG.GetItemLocation(nr, slotIndex)

    if loc == -1 then
        -- missing: red border
        return 1, 0, 0, 1
    elseif loc == -2 then
        -- No item: no border
        return 0, 0, 0, 0
    elseif loc == BAG_BANK or loc == BAG_SUBSCRIBER_BANK or IsHouseBankBag(loc) then
        -- in bank: yellow border
        return 1, 1, 0, 1
    elseif loc == BAG_WORN then
        -- currently worn: cyan border
        return 0, 1, 1, 1
    end

    -- in backpack: no border
    return 0, 0, 0, 0
end



--- Draws a green border at slots which might be a drag target
-- mode is one of 0 or 1. 0 disables the border
function AG.SetCallout(mode)
    for a = 1, MAXSLOT do
        for _,b in pairs(DRAGINFO.slot) do 
            -- defaults to no border
            local red, green, blue, alpha = 0, 0, 0, 0

            if mode == 1 then
                -- set green border
                green, alpha = 1, 1
            else 
                if DRAGINFO.panel == AG.MODE_GEAR then
                    red, green, blue, alpha = AG.GetItemBorderColor(a, b)
                end
            end

            -- set border color
            WM:GetControlByName('AG_Button_'..DRAGINFO.panel..'_'..a..'_'..b..'Bg'):SetEdgeColor(red, green, blue, alpha)
        end
    end
    
    if mode == 0 then
        DRAGINFO = {}
    end
end

-- mode: one of skill or gear
-- colorId: 1 = green, 2 = gray
function AG.SetConnect(mode, colorId)
    local color = {'green','grey'}
    local connectorcolor = {'green','grey1'}
    
    for nr = 1, MAXSLOT do
        WM:GetControlByName('AG_Selector_'..mode..'_'..nr):SetNormalTexture('AlphaGear/asset/'..color[colorId]..'.dds')
    end

    local c
    if mode == AG.MODE_SKILL then
        if SELECTBAR == 1 then
            c = AG_PanelSetPanelScrollChildEditPanelSetBar1PanelBar1Connector
        else 
            c = AG_PanelSetPanelScrollChildEditPanelSetBar2PanelBar2Connector
        end
    else 
        c = AG_PanelSetPanelScrollChildEditPanelSetGearPanelGearConnector
    end
    
    -- grey1.dds
    
    c:SetNormalTexture('AlphaGear/asset/'..connectorcolor[colorId]..'.dds')
end


function AG.SetGearConnection(c, button)
    if SELECTBAR == 1 or SELECTBAR == 2 then
        -- stop skill selection
        AG.SetConnect(AG.MODE_SKILL, 2)
        SELECTBAR = false
    end

    if button == 1 then
        -- toggle connection mode
        if SELECTBAR then
            -- stop gear selection
            AG.SetConnect(AG.MODE_GEAR, 2)
            SELECTBAR = false
        else 
            -- start gear selection
            SELECTBAR = 3
            AG.SetConnect(AG.MODE_GEAR, 1)
        end
    elseif button == 2 then
        if SELECTBAR then 
            -- clear ger set
            local removedGearId = AG.setdata[SELECT].Set.gear

            if removedGearId ~= 0 then
                AG.handleRemoveGearSetFromBuild(SELECT)
                AG.setdata[SELECT].Set.gear = 0
            end
        end
    end
    
    AG.UpdateEditPanel(SELECT)
end


-- Called from UI, barId is one of 1,2 for skill bars
function AG.SetSkillConnection(c, button, barId)
    if SELECTBAR == 3 then
        -- stop gear selection
        AG.SetConnect(AG.MODE_GEAR, 2)
        SELECTBAR = false
    end

    if SELECTBAR and SELECTBAR ~= barId then
        -- stop other skill bar selection
        AG.SetConnect(AG.MODE_SKILL, 2)
        SELECTBAR = false
    end
    
    if button == 1 then
        -- toggle connection mode
        if SELECTBAR then
            AG.SetConnect(AG.MODE_SKILL, 2)
            SELECTBAR = false
        else 
            SELECTBAR = barId
            AG.SetConnect(AG.MODE_SKILL, 1)
        end
    elseif button == 2 then
        if SELECTBAR then 
            -- clear skill set
            AG.setdata[SELECT].Set.skill[SELECTBAR] = 0
        end
    end
    
    AG.UpdateEditPanel(SELECT)
end

function AG.SetSetLock()
    if SELECT then
        local set,c = AG.setdata[SELECT].Set
        c = AG_PanelSetPanelScrollChildEditPanelSetGearPanelGearLockTex
        if set.lock == 0 then
            set.lock = 1
            c:SetTexture('AlphaGear/asset/locked.dds')
        else
            set.lock = 0
            c:SetTexture('AlphaGear/asset/unlocked.dds')
        end
    end
end

function AG.SetSetName(mode,text)
    if not mode or not text then return end
    if SELECT then AG.setdata[SELECT].Set.text[mode] = text end
end



function AG.RepairItemInStore(bagId, slotId)
    local cost = GetItemRepairCost(bagId, slotId)
    if cost > GetCurrentMoney() then
        -- d("Not enough money to repair gear!")
        d(L.NotEnoughMoneyForRepairMsg)
        return -1
    else
        RepairItem(bagId, slotId)
        return cost
    end
end


function AG.RepairInStore()
    if not CanStoreRepair() then return end
    
    local totalCost = 0
    local repairedItems = 0
    local unrepairedItems = 0
    
    local bagId = BAG_WORN
    for slotId = 0, GetBagSize(bagId) do
        if DoesItemHaveDurability(bagId, slotId) then
            local itemName = GetItemName(bagId, slotId)
            if itemName ~= "" then
                local cost = AG.RepairItemInStore(bagId, slotId)
                if cost == -1 then 
                    unrepairedItems = unrepairedItems + 1
                else
                    repairedItems = repairedItems + 1
                    totalCost = totalCost + cost
                end
            end
        end
    end

    if totalCost ~= 0 then
        --d(repairedItems.." Items repaired. Total repair cost: "..totalCost.."g")
        d(ZOSF(L.ItemsRepairedMsg, repairedItems, totalCost))
    end
    
    if unrepairedItems ~= 0 then
        -- d("Not enough gold for "..unrepairedItems.." Items")
        d(ZOSF(L.ItemsNotRepairedMsg, unrepairedItems))
    end
end


function AG.UpdateAndChargeItem (slot, agControl, texControl, valControl)
    trace('AG.UpdateAndChargeItem')
    
    if not IsItemChargeable(BAG_WORN, slot) then
        trace('Slot is not chargeable: %d', slot)
        Hide(agControl) 
        return
    end

    trace('Slot is chargeable: %d', slot)
        
    local chargeInfo = {GetChargeInfoForItem(BAG_WORN, slot)}
    local itemInfo = GetItemInfo(BAG_WORN, slot)
        
    if itemInfo then
    
        trace ('Slot is equipped; current charges: %d, max charges: %d', chargeInfo[1], chargeInfo[2])
        
        -- recharge if necessary
        -- test for charges < 5 to have some savety margin. 
        if chargeInfo[1] < 5 and AG.isAutoChargeWeapons() then
            trace('Slot is about to charge...')
            local gem = AG.GetSoulgem()
            if gem then
                trace('Slot: got soul gem, charging...')
            
                ChargeItemWithSoulGem(BAG_WORN, slot, BAG_BACKPACK, gem)
                d(ZOSF(L.SoulgemUsed, GetItemLink(BAG_WORN, slot)))

                if AG.isShowWeaponIcon() then
                    -- get current chargeinfo for display
                    chargeInfo = {GetChargeInfoForItem(BAG_WORN, slot)}
                end
            else
                trace('Slot: did not find a soul gem!')
            end
        end

        if AG.isShowWeaponIcon() then
            -- update control
            Show(agControl)
            local charge = math.ceil(chargeInfo[1]/chargeInfo[2]*100)
            texControl:SetTexture(itemInfo)
            valControl:SetText(charge.."%")
            valControl:SetColor(GetColor(charge,1))
            agControl:SetHidden(false)
        end
    else 
        trace ('Slot is not equipped')
        Hide(agControl) 
    end     
end


function AG.UpdatePoisonedWeapons(isBackPair)
    trace('AG.UpdatePoisonedWeapons called')

    -- hide icons for charged weapons
    Hide(AG_Charge2) 

    local weaponSlot = EQUIP_SLOT_MAIN_HAND
    local poisonSlot = EQUIP_SLOT_POISON

    if isBackPair then
        weaponSlot = EQUIP_SLOT_BACKUP_MAIN
        poisonSlot = EQUIP_SLOT_BACKUP_POISON
    end

    local hasPoison, poisonCount, poisonHeader, poisonItemLink = GetItemPairedPoisonInfo(weaponSlot)
    if hasPoison then
        trace('Weapons with poison equiped. Stack: %d', poisonCount)
    else 
        trace('Weapons without poison')
    end
    
    local itemInfo = GetItemInfo(BAG_WORN, poisonSlot)
        
    if itemInfo and AG.isShowWeaponIcon() then
        -- update control
        Show(AG_Charge1)
        AG_Charge1Tex:SetTexture(itemInfo)
        AG_Charge1Value:SetText(poisonCount)
        AG_Charge1Value:SetColor(GetColor(poisonCount,1))
        AG_Charge1:SetHidden(false)
    else 
        Hide(AG_Charge1) 
    end

end



function AG.UpdateChargedWeapons(isBackPair)
    trace('AG.UpdateChargedWeapons()')
    
    if isBackPair then
        trace('Back weapons equiped')
        AG.UpdateAndChargeItem (EQUIP_SLOT_BACKUP_MAIN, AG_Charge1, AG_Charge1Tex, AG_Charge1Value)
        AG.UpdateAndChargeItem (EQUIP_SLOT_BACKUP_OFF, AG_Charge2, AG_Charge2Tex, AG_Charge2Value)
    else
        trace('Front weapons equiped')
        AG.UpdateAndChargeItem (EQUIP_SLOT_MAIN_HAND, AG_Charge1, AG_Charge1Tex, AG_Charge1Value)
        AG.UpdateAndChargeItem (EQUIP_SLOT_OFF_HAND, AG_Charge2, AG_Charge2Tex, AG_Charge2Value)
    end
end



--- Handler for EVENT_INVENTORY_SINGLE_SLOT_UPDATE
function AG.UpdateWeaponStats(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackSizeChange)
    trace('AG.UpdateWeaponStats()')
    
    -- safety net, shouldn't happen 
    if bagId ~= BAG_WORN then
        trace('Wrong bag for weapon stats. Exiting...')
        return 
    end

    -- ignore non-weapon/poison slots
    if slotId ~= EQUIP_SLOT_POISON and slotId ~= EQUIP_SLOT_BACKUP_POISON and slotId ~= EQUIP_SLOT_MAIN_HAND and 
        slotId ~= EQUIP_SLOT_OFF_HAND and slotId ~= EQUIP_SLOT_BACKUP_MAIN and slotId ~= EQUIP_SLOT_BACKUP_OFF then
        return
    end

    AG.ForceUpdateWeaponStats()
end

--- forces an update of the poison or charge icons
function AG.ForceUpdateWeaponStats()
    trace('AG.ForceUpdateWeaponStats()')

    -- decide what to do
    local activeWeaponPair = GetActiveWeaponPairInfo()
    local isPoisonEquipped = false
    local isBackPair = false

    if (activeWeaponPair == ACTIVE_WEAPON_PAIR_MAIN) then
        isPoisonEquipped = HasItemInSlot(BAG_WORN, EQUIP_SLOT_POISON)
    elseif (activeWeaponPair == ACTIVE_WEAPON_PAIR_BACKUP) then
        isPoisonEquipped = HasItemInSlot(BAG_WORN, EQUIP_SLOT_BACKUP_POISON)
        isBackPair = true
    end

    if isPoisonEquipped then
        -- show poison stats
        trace('Poison is equiped')
        AG.UpdatePoisonedWeapons(isBackPair)
    else
        -- show weapon stats
        trace('Poison is not equipped')
        AG.UpdateChargedWeapons(isBackPair)
    end
end


-- Setup UI by settings
function AG.setupMainButton()
    local showMainButton = AG.isShowMainButton()
    
    AG_UI_Button:SetHidden(not showMainButton)
    AG_UI_ButtonBg:SetHidden(not showMainButton)
end


function AG.setupSetButtons()
    local showSetButtons = AG.isShowSetButtons()

    AG_SetButtonFrame:SetHidden(not showSetButtons)
    AG_SetButtonBg:SetHidden(not showSetButtons)
    AG.UpdateSetButtons()
end

function AG.setupGearIcon()
    local showIcon = AG.isShowGearIcon()

    AG.layoutControl(AG_Repair, showIcon)
    AG_RepairValue:SetHidden(not showIcon)
    AG_RepairMainBg:SetHidden(not showIcon)
    AG_RepairCost:SetHidden(not AG.isShowRepairCost())

    if showIcon then
        EM:RegisterForEvent('AG_Event_Repair', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AG.UpdateRepair)
        EM:RegisterForEvent('AG_Event_Repair_Armory',  EVENT_ARMORY_BUILD_RESTORE_RESPONSE, AG.UpdateRepair)
        -- only worn items need to be repaired
        EM:AddFilterForEvent('AG_Event_Repair', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN) 
        AG.UpdateRepair(nil, BAG_WORN)
    else
        EM:UnregisterForEvent('AG_Event_Repair_Armory', EVENT_ARMORY_BUILD_RESTORE_RESPONSE)
        EM:UnregisterForEvent('AG_Event_Repair', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end
end

function AG.setupWeaponIconsAndCharge()
    local showIcon = AG.isShowWeaponIcon()
    local autoChargeEnabled = AG.isAutoChargeWeapons()

    AG_Charge1:SetHidden(not showIcon)
    AG_Charge2:SetHidden(not showIcon)
    AG_ChargeMainBg:SetHidden(not showIcon)
    
    if autoChargeEnabled or showIcon then
        EM:RegisterForEvent('AG_Event_Update_Weapon_Stats', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AG.UpdateWeaponStats)
        -- only worn items need to be recharged
        EM:AddFilterForEvent('AG_Event_Update_Weapon_Stats', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN) 
        AG.ForceUpdateWeaponStats()
    else
        EM:UnregisterForEvent('AG_Event_Update_Weapon_Stats', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end
end

function AG.setupMarkSetItems()
    -- TODO: handle
    local markItems = AG.isMarkSetItemsInBag()
end

function AG.setupItemCondition()
    local enabled = AG.isShowItemCondition()
    
    if enabled then
        EM:RegisterForEvent('AG_Event_Update_Condition', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AG.UpdateCondition)
        -- only worn items need to be repaired
        EM:AddFilterForEvent('AG_Event_Update_Condition', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN) 
    else
        EM:UnregisterForEvent('AG_Event_Update_Condition', EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end

    for _,c in pairs(SLOTS) do AG.UpdateCondition(_, BAG_WORN, c[1]) end
end

function AG.setupItemQuality()
    for _,c in pairs(SLOTS) do AG.UpdateCondition(_, BAG_WORN, c[1]) end
end

function AG.setupAutoClose()
    local enabled = AG.isCloseWindowOnMove()
    
    if enabled then
        EM:RegisterForEvent('AG_Event_Movement', EVENT_NEW_MOVEMENT_IN_UI_MODE, function() SM:HideTopLevel(AG_Panel) end)
    else
        EM:UnregisterForEvent('AG_Event_Movement', EVENT_NEW_MOVEMENT_IN_UI_MODE) 
    end
end

function AG.setupLockUI()
    local locked = AG.isLockUI()

    for i = 1, table.getn(UIElements) do
        if UIElements[i]:GetName() ~= "AG_Panel" then
            UIElements[i]:SetMouseEnabled(not locked)
            UIElements[i]:SetMovable(not locked)
        end
    end

end


function AG.setupActiveSet()
    trace('setupActiveSet')

    local visible = AG.isShowActiveSet() and AG.setdata.lastset

    if visible then
        AG.UpdateSwapMessage()
    end

    AG_SwapMessage:SetHidden(not visible)
    AG_SwapMessageBg:SetHidden(not visible)
end

function AG.setupAutoRepairAtStores()
    local enabled = AG.isAutoRepairAtStores()
    
    if enabled then
        EM:RegisterForEvent('AG_Event_OpenStore', EVENT_OPEN_STORE, AG.RepairInStore)
    else
        EM:UnregisterForEvent('AG_Event_OpenStore', EVENT_OPEN_STORE) 
    end
end

function AG.setupShowItemLevel()
    for _,c in pairs(SLOTS) do AG.UpdateCondition(_, BAG_WORN, c[1]) end
end



function AG:SetOptions()
    AG.setupMainButton()
    AG.setupSetButtons()
    AG.setupGearIcon()
    AG.setupWeaponIconsAndCharge()
    AG.setupMarkSetItems()
    AG.setupItemCondition()
    AG.setupAutoClose()
    AG.setupLockUI()
    AG.setupActiveSet()
    AG.setupAutoRepairAtStores()
    
    AG.InitPositions()

    -- repaint of SetButtons
    AG.DrawSetButtonsUI()
end

--- Aligns Main Panel to the parent (skills or inventory), so that drag'n'drop is possible
function AG.AlignMainPanel(parent, xOffset)
    trace('AlignMainPanel')
    AG_Panel:ClearAnchors()
    AG_Panel:SetAnchor(RIGHT, parent, LEFT, xOffset, 0)
end

--- Resets the position of the main panel to it's previous state 
function AG.UnalignMainPanel()
    trace('UnalignMainPanel')
    AG.SetElementAnchor(AG_Panel)
end

function AG.HideSwapMessage()
    AG_SwapMessage:SetHidden(true)
    AG_SwapMessageBg:SetHidden(true)
end

function AG.OnShowSkills()
    AG.HideSwapMessage()
    AG.AlignMainPanel(ZO_Skills, -25)
end

function AG.OnHideSkills()
    AG.UnalignMainPanel()
    AG.setupActiveSet()    
end

function AG.OnShowInventory()
    AG.HideSwapMessage()
    AG.AlignMainPanel(ZO_PlayerInventory, -25)
end

function AG.OnHideInventory()
    AG.UnalignMainPanel()
    AG.setupActiveSet()
end




function AG.SetElementAnchor(element)
    local elementName = element:GetName()
    local pos = AG.account.positions[elementName]
        
    if pos then
        local xOffset = pos[1]
        local yOffset = pos[2]
        local relX = pos[3]
        local relY = pos[4]
        local relPos = pos[5]
        local rootPos = CENTER

        if relX and relY and relPos then
            xOffset = relX * GuiRoot:GetWidth()
            yOffset = relY * GuiRoot:GetHeight()
            trace("restore rel %f/%f", relX, relY)
        else
            -- no relative position available
            relPos = TOPLEFT
            rootPos = TOPLEFT
        end

        element:ClearAnchors()
        element:SetAnchor(rootPos, GuiRoot, relPos, xOffset, yOffset)

        if rootPos == TOPLEFT then
            -- must store relative positions
            AG.StorePosition(element)
        end
    end
end


function AG.InitPositions()
    trace ("init positions")
    for i = 1, table.getn(UIElements) do
        AG.SetElementAnchor(UIElements[i])
    end
end

function AG.StorePosition(control)
    local name = control:GetName()
    
    -- added storing relative positions, so that scaling doesn't affect pos
    local centerX, centerY = control:GetCenter()
    local rootCenterX, rootCenterY = GuiRoot:GetCenter()
    local rootWidth, rootHeight = GuiRoot:GetDimensions()
    local relPoint 
    local relX
    local relY


    if centerX > rootCenterX then
        relX = (centerX-rootWidth)/rootWidth
        if centerY > rootCenterY then
            relY = (centerY-rootHeight)/rootHeight
            relPoint = BOTTOMRIGHT
        else
            relY = centerY/rootHeight
            relPoint = TOPRIGHT
        end
    else
        relX = centerX/rootWidth
        if centerY > rootCenterY then
            relY = (centerY-rootHeight)/rootHeight
            relPoint = BOTTOMLEFT
        else
            relY = centerY/rootHeight
            relPoint = TOPLEFT
        end
    end

    trace("stored rel %f/%f", relX, relY)

    AG.account.positions[name] = {control:GetLeft(), control:GetTop(), relX, relY, relPoint}
end



function AG.ResetPositions()
    for i = 1, table.getn(UIElements) do
        local name = UIElements[i]:GetName()

        UIElements[i]:ClearAnchors()
        
        if name == "AG_RepairMainBg" then
            -- special treatment for repair button
            UIElements[i]:SetAnchor(TOPLEFT, ActionButton8, TOPRIGHT, -5, -10)
        elseif name == "AG_ChargeMainBg" then
            -- special treatment for weapon button
            UIElements[i]:SetAnchor(TOPLEFT, ActionButton8, TOPRIGHT, 50, -10)
        else
            local pos = AG.account_defaults.positions[name]
            UIElements[i]:SetAnchor(pos[3], GuiRoot, pos[4], pos[1], pos[2])
        end
        
        AG.StorePosition(UIElements[i])
    end
end


--- Opens a menu for manually choosing a skill bar icon
function AG.ShowIconMenu(cp, button, bar)
    SELECTBAR = bar

    if button == MOUSE_BUTTON_INDEX_LEFT then
        -- show icon menu
        AG_PanelIcons:SetAnchor(6, cp, 12, 0, 0)
        AG_PanelIcons:ToggleHidden()

        if not AG_PanelIcons:IsHidden() then
            for x = 1,AG_PanelIconsScrollChild:GetNumChildren() do AG_PanelIconsScrollChild:GetChild(x):SetHidden(true) end
            local xpos, ypos, name, c = 10, 10, nil, nil
            for x,icon in pairs(ICON) do
                name = 'AG_SetIcon_'..x
                c = WM:GetControlByName(name)
                if not c then
                    c = WM:CreateControl(name,AG_PanelIconsScrollChild,CT_BUTTON)
                    c:SetAnchor(3,AG_PanelIconsScrollChild,3,xpos,ypos)
                    c:SetDimensions(64,64)
                    c:SetClickSound('Click')
                    c:SetMouseOverTexture('AlphaGear/asset/light.dds')
                    c:SetHandler('OnClicked',function(self)
                        AG.setdata[SELECT].Set.icon[SELECTBAR] = icon
                        AG_PanelIcons:SetHidden(true)
                        AG.UpdateEditPanel(SELECT)
                    end)
                    if x%3 == 0 then xpos = 10; ypos = ypos + 69
                    else xpos = xpos + 69 end
                end
                c:SetNormalTexture(icon)
                c:SetHidden(false)
            end
            AG_PanelIconsScrollChild:SetHeight(math.ceil(#ICON/3)*69+10)
        end
    elseif button == MOUSE_BUTTON_INDEX_RIGHT then
        -- clear icon
        AG.setdata[SELECT].Set.icon[SELECTBAR] = 0
        AG.UpdateEditPanel(SELECT)
    end
end


--- Sets the texture of a skill or gear button
function AG.ShowButton(c)
    if not c then return false end
    local type, nr, slot = AG.GetButton(c)
    local skill, gear = AG.setdata[nr].Skill, AG.setdata[nr].Gear
    if type == AG.MODE_SKILL then
        if skill[slot] ~= 0 then
            
            -- Updated for scribing
            if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(skill[slot])) then
                -- Crafted skill, get the specific version slotted
                local slottedId = GetAbilityIdForCraftedAbilityId(skill[slot])
                if slottedId ~= 0 then
                    local icon = GetAbilityIcon(slottedId)
                    c:SetNormalTexture(icon)
                    c.data = { hint = L.Button[type] }
                end
            else
                -- Normal skill
                local abilityIndex = AG.GetAbility(skill[slot])
                if abilityIndex ~= 0 then
                    local _, icon = GetAbilityInfoByIndex(abilityIndex)
                    c:SetNormalTexture(icon)
                    c.data = { hint = L.Button[type] }
                end
            end
            
        else
            c:SetNormalTexture()
            c.data = nil
        end
    else
        if gear[slot].link ~= 0 then
            c:SetNormalTexture(GetItemLinkInfo(gear[slot].link))
            c:GetNamedChild('Bg'):SetCenterColor(Quality(gear[slot].link,0.5))
            c.data = { hint = L.Button[type] }
        else
            c:SetNormalTexture('esoui/art/characterwindow/gearslot_'..SLOTS[slot][2]..'.dds')
            local b = c:GetNamedChild('Bg')
            b:SetCenterColor(0,0,0,0.2)
            b:SetEdgeColor(0, 0, 0, 0)
            c.data = nil
        end
    end
    if SELECT and not AG_PanelSetPanelScrollChildEditPanel:IsHidden() then
        if (nr == AG.setdata[SELECT].Set.gear or nr == AG.setdata[SELECT].Set.skill[1] or nr == AG.setdata[SELECT].Set.skill[2]) then 
            AG.UpdateEditPanel(SELECT) 
        end
    end
end


function AG.HandleCursorDropped()
    trace('HandleCursorDropped')

    if DRAGINFO.panel ~= nil then
        AG.SetCallout(0)
    end
end


function AG.HandleCursorPickup(eventCode, cursorType, param1, param2, param3, param4, param5, param6, itemSoundCategory)
    trace('HandleCursorPickup. CT: %d, P1: %d', cursorType, param1)

    if cursorType == MOUSE_CONTENT_INVENTORY_ITEM or cursorType == MOUSE_CONTENT_EQUIPPED_ITEM then
        local bag, slot
        
        if cursorType == MOUSE_CONTENT_INVENTORY_ITEM then
            bag=param1
            slot=param2
        else
            bag=BAG_WORN
            slot=param1
        end
        
        local uid, itemType, link = AG.GetIdTypeAndLink(bag, slot)

        if itemType == ITEMTYPE_ARMOR or itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_POISON then

            local _,_,_,_,_,equipType = GetItemInfo(bag, slot)

            DRAGINFO.uid = uid
            DRAGINFO.link = link
            DRAGINFO.type = equipType
            DRAGINFO.slot = DRAG_TARGET_SLOTS[equipType]
            DRAGINFO.panel = AG.MODE_GEAR

            if AG.isDebug then
                local itemName = GetItemName(bag, slot)
                local itemUniqueId = Id64ToString(GetItemUniqueId(bag, slot))
                local itemInstanceId =  Id64ToString(GetItemInstanceId(bag, slot))
                local itemId = GetItemId(bag, slot)
                trace ('InsertItem: Name/Type/UniqueId/InstanceId/ID %s/%d/%s/%s/%d', itemName, itemType, itemUniqueId, itemInstanceId, itemId)
            end

            AG.SetCallout(1)
        end
    elseif cursorType == MOUSE_CONTENT_ACTION then
        local sourceSlot = param2
        local abilityIndex = param3
        
        -- Updated for scribing
        local baseAbilityId
        if abilityIndex ~= 0 then
            if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(abilityIndex)) then
                -- Crafted skill, the abilityIndex here is the "CraftedAbilityID" which is like the base ID
                baseAbilityId = abilityIndex
                
                trace ('Slot %d, Crafted base: %d', sourceSlot, baseAbilityId)
                
                local craftedSkillType, craftedSkillLineIndex, craftedSkillIndex = GetSkillAbilityIndicesFromCraftedAbilityId(baseAbilityId)
                trace ('CraftedSkillType %d, CraftedSkillLineIndex: %d, CraftedSkillIndex: %d', craftedSkillType, craftedSkillLineIndex, craftedSkillIndex)
                
                if craftedSkillType and craftedSkillLineIndex and craftedSkillIndex then
                    local isUnlocked = IsCraftedAbilityUnlocked(baseAbilityId)
                    local isScribed = IsCraftedAbilityScribed(baseAbilityId)
                    trace ('Unlocked: %s, Scribed: %s', tostring(isUnlocked), tostring(isScribed))
                    
                    if isUnlocked and isScribed then
                        DRAGINFO.id = baseAbilityId
                        DRAGINFO.ultimate = false
                        DRAGINFO.panel = AG.MODE_SKILL
                        DRAGINFO.slot = {1,2,3,4,5}
                        AG.SetCallout(1)
                    end
                end
                
            else
                -- Normal skill
                local abilityId = GetAbilityIdByIndex(abilityIndex)
                baseAbilityId = AG.GetBaseAbilityId(abilityId)
                
                trace ('Slot %d, AbilityIndex: %d, AbilityId: %d, BaseAbilityId: %d', sourceSlot, abilityIndex, abilityId, baseAbilityId)
                
                local baseSkillType, baseSkillindex, baseAbilityIndex, morphChoice = GetSpecificSkillAbilityKeysByAbilityId(baseAbilityId)
                trace ('BaseSkilltype %d, BaseSkillIndex: %d, BaseAbilityIndex: %d', baseSkillType, baseSkillindex, baseAbilityIndex)
                
                if baseSkillType and baseSkillindex and baseAbilityIndex then
                    local _,_,_,_, ultimate, purchased = GetSkillAbilityInfo(baseSkillType, baseSkillindex, baseAbilityIndex)
                    trace ('Ultimate %s, purchased: %s', tostring(ultimate), tostring(purchased))
                
                    if purchased then
                        DRAGINFO.id = baseAbilityId
                        DRAGINFO.ultimate = ultimate
                        DRAGINFO.panel = AG.MODE_SKILL
                        if ultimate then 
                            DRAGINFO.slot = {6} 
                        else
                            DRAGINFO.slot = {1,2,3,4,5}
                        end
                
                        AG.SetCallout(1)
                    end
                end
                
            end
        end
    end
end


function AG.ShowMain()
    trace('ShowMain')
    SM:ToggleTopLevel(AG_Panel)
    if AG_Panel:IsHidden() then
        trace('Unregister DD-Events')
        EM:UnregisterForEvent('AG_Event_Cursor_Pickup', EVENT_CURSOR_PICKUP)
        EM:UnregisterForEvent('AG_Event_Cursor_Drop', EVENT_CURSOR_DROPPED)
    else
        AG.UpdateItemLinks()

        for setIndex = 1, MAXSLOT do
            for slotId = 1, #SLOTS do
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..setIndex..'_'..slotId))
            end
        end
    
        AG.UpdateUI()
        trace('Register DD-Events')
        EM:RegisterForEvent('AG_Event_Cursor_Pickup', EVENT_CURSOR_PICKUP, AG.HandleCursorPickup)
        EM:RegisterForEvent('AG_Event_Cursor_Drop', EVENT_CURSOR_DROPPED, AG.HandleCursorDropped)
    end
end

function AG.HideMain()
    trace('HideMain')
    trace('Unregister DD-Events')
    SM:HideTopLevel(AG_Panel)
    EM:UnregisterForEvent('AG_Event_Cursor_Pickup', EVENT_CURSOR_PICKUP)
    EM:UnregisterForEvent('AG_Event_Cursor_Drop', EVENT_CURSOR_DROPPED)
end


function AG.UpdateSwapMessage()
    if AG.setdata.lastset then
        local pair = GetActiveWeaponPairInfo()
        local tex
        local barLabel
        local set = AG.setdata[AG.setdata.lastset].Set
        
        if pair == ACTIVE_WEAPON_PAIR_NONE then
            tex = 'AlphaGear/asset/nothing.dds'
            barLabel = 'None'
        else
            local pslot = {1,3}
        
            if set.gear ~= 0 and AG.setdata[set.gear].Gear[pslot[pair]].id ~= 0 then 
                tex = Zero(set.icon[pair]) or AG.GetSetIcon(set.gear,pair)
            else 
                tex = Zero(set.icon[pair]) or 'AlphaGear/asset/nothing.dds'
            end
            barLabel = Zero(set.text[pair + 1]) or ZOSF(L.ActionBarNText, pair)
        end
        
        local profileLabel = AG.setdata.profiles[AG.setdata.currentProfileId].name
        
        AG_SwapMessageIcon:SetTexture(tex)
        AG_SwapMessageNumber:SetText(AG.setdata.lastset)
        AG_SwapMessageName:SetText(profileLabel..'\n'..(Zero(set.text[1]) or 'Build '..AG.setdata.lastset)..'\n|cFFFFFF'..barLabel)
    end
end

function AG.SwapMessage()
    trace('SwapMessage')
    local flashCount = 0

    local function FlashSwapButton()
        flashCount = flashCount + 1
        ZO_ActionBar1WeaponSwap:SetShowingHighlight(flashCount % 2 == 1)

        -- flash 10 times at max
        if SWAP and flashCount < 20 then
            zo_callLater(function() FlashSwapButton() end, 500)
        else
            ZO_ActionBar1WeaponSwap:SetShowingHighlight(false)
        end
    end

    AG.UpdateSwapMessage()

    if SWAP then
        FlashSwapButton()
    end

    if AG.isShowChangeNotification() and AG.setdata.lastset then
        PlaySound('Market_PurchaseSelected')
        if not AG.isShowActiveSet() then 
            AG.Animate(true,false,2500) 
            AG_SwapMessageBg:SetHidden(true)
        else 
            AG.Animate(true,false,false) 
            AG_SwapMessageBg:SetHidden(false)
        end
    end
end

function AG.Swap(_,isSwap)
    trace('Swap')



    if isSwap and not IsBlockActive() then


        if AG.setdata.lastset and SWAP then
            local pair = GetActiveWeaponPairInfo()
            if AG.setdata[AG.setdata.lastset].Set.skill[pair] ~= 0 then AG.LoadBar(AG.setdata[AG.setdata.lastset].Set.skill[pair]) end
            SWAP = false
        end
        if AG.isShowWeaponIcon() then AG.ForceUpdateWeaponStats() end
        AG.SwapMessage()
    end
end



-- Executes a menu action
-- nr: number of action to execute
-- 1: copy, 2: paste, 3: insert equipped, 4: clear, 5: deposit, 6: withdraw, 7: deposit profile, 8: withdraw profile
function AG.MenuAction(nr)
    trace('MenuAction')

    if nr == 1 then
        -- Store copy source
        MENU.copySourceSetId = MENU.nr
        MENU.copySourceProfileId = AG.setdata.currentProfileId
    elseif nr == 2 and MENU.copySourceSetId then
        -- Paste 
        local sourceSet 
        if MENU.copySourceProfileId == AG.setdata.currentProfileId then
            sourceSet = AG.setdata[MENU.copySourceSetId]
        else
            sourceSet = AG.setdata.profiles[MENU.copySourceProfileId].setdata[MENU.copySourceSetId]
        end
        
        if MENU.type == AG.MENU_TYPE_GEAR then
            AG.handlePreChangeGearSetItems(MENU.nr)
            for z = 1, #SLOTS do
                AG.setdata[MENU.nr].Gear[z] = sourceSet.Gear[z]
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..MENU.nr..'_'..z))
            end 
            AG.handlePostChangeGearSetItems(MENU.nr)

        else 
            for z = 1,6 do
                AG.setdata[MENU.nr].Skill[z] = sourceSet.Skill[z]
                AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..MENU.nr..'_'..z))
            end 
        end
    elseif nr == 3 then
        -- Insert 
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.handlePreChangeGearSetItems(MENU.nr)
            for x = 1, #SLOTS do
                if GetItemInstanceId(BAG_WORN, SLOTS[x][1]) then
                    local uid, _, itemLink = AG.GetIdTypeAndLink(BAG_WORN, SLOTS[x][1])
                    AG.setdata[MENU.nr].Gear[x] = { id = uid, link = itemLink }
                else 
                    AG.setdata[MENU.nr].Gear[x] = { id = 0, link = 0 } 
                end
                
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..MENU.nr..'_'..x))
            end 
            AG.handlePostChangeGearSetItems(MENU.nr)
        elseif MENU.type == AG.MENU_TYPE_SKILLS then 
            AG.GetSkillFromBar(MENU.nr) 
        end
    elseif nr == 4 then
        -- Clear
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.handlePreChangeGearSetItems(MENU.nr)
            for z = 1, #SLOTS do
                AG.setdata[MENU.nr].Gear[z] = { id = 0, link = 0 }
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..MENU.nr..'_'..z))
            end 
            AG.handlePostChangeGearSetItems(MENU.nr)
        elseif MENU.type == AG.MENU_TYPE_SKILLS then 
            for z = 1,6 do
                AG.setdata[MENU.nr].Skill[z] = 0
                AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..MENU.nr..'_'..z))
            end 
        else
            AG.setdata[MENU.nr].Set = { text = {0,0,0}, gear = 0, skill = {0,0}, icon = {0,0}, lock = 0 }
            AG.UpdateUI(MENU.nr,MENU.nr)
        end
    elseif nr == 5 then
        -- deposit
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.MoveGearSet(true, MENU.nr, true)
        end
    elseif nr == 6 then
        -- withdraw
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.MoveGearSet(false, MENU.nr, true)
        end
    elseif nr == 7 then
        -- deposit profile
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.MoveGearSetAll(true)
        end
    elseif nr == 8 then
        -- withdraw profile
        if MENU.type == AG.MENU_TYPE_GEAR then 
            AG.MoveGearSetAll(false)
        end
    end
end

-----------------------------
-- start Kyzer's additions
-- this file is too damn long
-----------------------------
function AG.ClearProfile(argString)
    if (argString ~= "all" and argString ~= "gear" and argString ~= "skills" and argString ~= "sets") then
        d("Really clear this entire profile? Type /agclear all||gear||skills||sets")
        return
    end

    for index = 1, MAXSLOT do
        -- Gear
        if (argString == "all" or argString == "gear") then
            AG.handlePreChangeGearSetItems(index)
            for z = 1, #SLOTS do
                AG.setdata[index].Gear[z] = { id = 0, link = 0 }
                AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..index..'_'..z))
            end
            AG.handlePostChangeGearSetItems(index)
        end

        -- Skills
        if (argString == "all" or argString == "skills") then
            for z = 1,6 do
                AG.setdata[index].Skill[z] = 0
                AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..index..'_'..z))
            end
        end

        -- Sets
        if (argString == "all" or argString == "sets") then
            AG.setdata[index].Set = { text = {0,0,0}, gear = 0, skill = {0,0}, icon = {0,0}, lock = 0, outfit = -1 }
            AG.UpdateUI(index, index)
            AG.UpdateSetButtons()
            AG.HideEditPanel()
        end
    end
end

local function GetCharNames()
    local charNames = {}
    for index = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id, _ = GetCharacterInfo(index)
        charNames[zo_strformat("<<1>>", name)] = true
    end
    return charNames
end

local otherCharVars = {}
function AG.ImportProfile(accountName, charName, profileNum)
    -- Clear profile first
    AG.ClearProfile("all")

    -- Import profile
    local otherProfile = AGX2_Character.Default[accountName][charName].profiles[profileNum]
    if (not otherProfile.setdata) then
        d(zo_strformat("Profile <<1>> (<<2>>) from character <<3>> is empty!", otherProfile.name, profileNum, charName))
        return
    end

    d(zo_strformat("Importing gear from profile <<1>> (<<2>>) from character <<3>>...", otherProfile.name, profileNum, charName))
    for index = 1, MAXSLOT do
        AG.handlePreChangeGearSetItems(index)
        for z = 1, #SLOTS do
            AG.setdata[index].Gear[z] = { id = otherProfile.setdata[index].Gear[z].id, link = otherProfile.setdata[index].Gear[z].link }
            AG.ShowButton(WM:GetControlByName('AG_Button_Gear_' .. index .. '_' .. z))
        end
        AG.handlePostChangeGearSetItems(index)
    end

    d(zo_strformat("Importing skills from profile <<1>> (<<2>>) from character <<3>>...", otherProfile.name, profileNum, charName))
    for index = 1, MAXSLOT do
        for z = 1,6 do
            AG.setdata[index].Skill[z] = otherProfile.setdata[index].Skill[z]
            AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..index..'_'..z))
        end
    end

    d(zo_strformat("Importing sets from profile <<1>> (<<2>>) from character <<3>>...", otherProfile.name, profileNum, charName))
    for index = 1, MAXSLOT do
        local otherSet = otherProfile.setdata[index].Set
        AG.setdata[index].Set = {
            text = {otherSet.text[1], otherSet.text[2], otherSet.text[3]},
            gear = otherSet.gear,
            skill = {otherSet.skill[1], otherSet.skill[2]},
            icon = {otherSet.icon[1], otherSet.icon[2]},
            lock = otherSet.lock,
            outfit = otherSet.outfit
        }
        AG.UpdateUI(index, index)
    end
    d("Done")
end

local function ImportProfileCommand(argString)
    if (argString == "") then
        d("Usage: /agimport <character name> [profile id]\nNote: this does not import extensions / advanced settings")
        local names = {}
        for name, _ in pairs(GetCharNames()) do
            table.insert(names, name)
        end
        d("Available Characters: " .. table.concat(names, ", "))
        return
    end

    local lastSpaceIndex = string.find(argString, " [^ ]*$")
    if (not lastSpaceIndex) then lastSpaceIndex = 0 end
    local lastWord = string.sub(argString, lastSpaceIndex + 1)
    local lastNum = tonumber(lastWord)
    local charName = ""
    if (lastNum == nil or lastSpaceIndex == 0) then
        charName = argString
    else
        charName = string.sub(argString, 1, lastSpaceIndex - 1)
    end

    if (not GetCharNames()[charName]) then
        d("No such character \"" .. charName .. "\"")
        return
    end
    local otherData = otherCharVars[charName]
    if (not otherData) then
        d("Loading saved vars for \"" .. charName .. "\"")
        otherData = ZO_SavedVars:New('AGX2_Character', AG.characterVariableVersion, nil, init_data, nil, nil, charName)
        otherCharVars[charName] = otherData
    end

    -- List the available profiles
    if (not lastNum) then
        d("Available Profiles:")
        for profileId = 1, MAX_PROFILES do
            local profileName = otherData.profiles[profileId].name
            d(zo_strformat("<<1>> - <<2>>", profileId, profileName))
        end
        d("To import a profile, type again: /agimport " .. charName .. " number")
        return
    end

    AG.ImportProfile(GetUnitDisplayName("player"), charName, lastNum)
end

------------------------
-- end Kyzer's additions
------------------------

function AG.Tooltip(c, visible, edit)
    -- trace('Tooltip')
    local function FadeIn(control)
        TTANI = ANIMATION_MANAGER:CreateTimeline()
        local fadeIn = TTANI:InsertAnimation(ANIMATION_ALPHA,control,400)
        fadeIn:SetAlphaValues(0,1)
        fadeIn:SetDuration(150)
        TTANI:PlayFromStart()
    end

    if not c then return end
    
    if visible then
        local type, nr, slot = AG.GetButton(c)

        if type == AG.MODE_GEAR then
            if edit then nr = AG.setdata[SELECT].Set.gear end
            if nr > 0 then
                if AG.setdata[nr].Gear[slot].link == 0 then return end

                c.text = ItemTooltip
                InitializeTooltip(c.text,AG_Panel,3,0,0,9)
                c.text:SetLink(AG.setdata[nr].Gear[slot].link)
                ZO_ItemTooltip_ClearCondition(c.text)
                ZO_ItemTooltip_ClearCharges(c.text)
            else return end
        elseif type == AG.MODE_SKILL then
            if edit then nr = AG.setdata[SELECT].Set.skill[nr] end
            if nr > 0 then

                if AG.setdata[nr].Skill[slot] == 0 then return end

                    -- Updated for scribing
                    if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(AG.setdata[nr].Skill[slot])) then
                        -- Crafted skill
                        local abilityId = GetAbilityIdForCraftedAbilityId(AG.setdata[nr].Skill[slot])
                        trace('Crafted skill: %d - %d', AG.setdata[nr].Skill[slot], abilityId)
                        c.text = SkillTooltip
                        InitializeTooltip(c.text,AG_Panel,3,0,0,9)
                        c.text:SetAbilityId(abilityId)
                    else
                        -- Normal skill
                        local s1,s2,s3 = AG.GetSkill(AG.setdata[nr].Skill[slot])
                        if s1 and s2 and s3 then
                            c.text = SkillTooltip
                            InitializeTooltip(c.text,AG_Panel,3,0,0,9)
                            c.text:SetSkillAbility(s1,s2,s3)
                        else
                            c.text = InformationTooltip
                            InitializeTooltip(c.text,AG_Panel,3,0,0,9)
                            c.text:AddLine(L.ReassignHint)
                        end
                    end
                
            else return end
        elseif c.data and c.data.tip then
            c.text = InformationTooltip
            InitializeTooltip(c.text,c,2,5,0,8)
            SetTooltipText(c.text,c.data.tip)
            c.text:SetHidden(false)
            return
        else
            if c.data == nil then return end
            c.text = InformationTooltip
            InitializeTooltip(c.text,AG_Panel,3,0,0,9)
            if c.data.header then c.text:AddLine(c.data.header,'ZoFontWinH4') end
            SetTooltipText(c.text,c.data.info)
        end
        if c.data and c.data.hint then c.text:AddLine(c.data.hint,'ZoFontGame') end
        c.text:SetAlpha(0)
        c.text:SetHidden(false)
        FadeIn(c.text)
    else
        if c.text == nil then return end
        ClearTooltip(c.text)
        if TTANI then TTANI:Stop() end
        c.text:SetHidden(true)
        c.text = nil
    end
end

function AG.TooltipSet(nr,visible)
    if not nr then return end
    if visible then
        local set, val, _ = AG.setdata[nr].Set
        for z = 1,2 do
            local ico = ''
            for x = 1,6 do
                if set.skill[z] > 0 and AG.setdata[set.skill[z]].Skill[x] ~= 0 then
                
                    -- Updated for scribing
                    if IsCraftedAbilitySkill(GetSkillAbilityIndicesFromCraftedAbilityId(AG.setdata[set.skill[z]].Skill[x])) then
                        -- Crafted skill, get the specific slotted version
                        local slottedId = GetAbilityIdForCraftedAbilityId(AG.setdata[set.skill[z]].Skill[x])
                        val = GetAbilityIcon(slottedId)
                    else
                        -- Normal skill
                        local abilityIndex = AG.GetAbility(AG.setdata[set.skill[z]].Skill[x])
                        _, val = GetAbilityInfoByIndex(abilityIndex)
                    end
                    
                else 
                    val = 'AlphaGear/asset/grey1.dds'
                end
                ico = ico..'|t36:36:'..val..'|t '
            end
            WM:GetControlByName('AG_SetTipBar'..z..'Skills'):SetText(ico)
            if set.gear ~= 0 then
                val = Zero(set.icon[z]) or AG.GetSetIcon(set.gear,z)
            else 
                val = 'AlphaGear/asset/nothing.dds'
            end
            WM:GetControlByName('AG_SetTipSkill'..z..'Icon'):SetTexture(val)
        end
        AG_SetTipName:SetText(Zero(set.text[1]) or 'Build '..nr)
        AG_SetTipBar1Name:SetText(Zero(set.text[2]) or 'Action-Bar 1')
        AG_SetTipBar2Name:SetText(Zero(set.text[3]) or 'Action-Bar 2')
        AG_SetTip:ClearAnchors()
        AG_SetTip:SetAnchor(BOTTOMLEFT, AG_SetButtonFrame, TOPLEFT, 0, -2)
        AG_SetTip:SetHidden(false)
    else AG_SetTip:SetHidden(true) end
end


--- loads the set which was selected whil in combat
function AG.LoadPendingSet()
    if AG.pendingSet ~= -1 then
        AG.LoadSetInternal (AG.pendingSet)
    end
end


--- Handler for the PLayerCombatState, used to prevent in-combat-set-changes
function AG.OnPlayerCombatState(event, inCombat)
    if not inCombat then
        AG.LoadPendingSet()
    end
end


function KEYBINDING_MANAGER:IsChordingAlwaysEnabled()
    return true
end

function AlphaGear_RegisterIcon(icon)
    table.insert(ICON,icon or 'AlphaGear/asset/nothing.dds')
end

function AG.CheckSkillId (nr, skillnr) 

    local oldSkillId = AG.setdata[nr].Skill[skillnr]
    if not DoesAbilityExist(oldSkillId) then
        trace ('Ability doesn\'t exist: %d', oldSkillId)
        local baseId = AGSkills17[oldSkillId]

        if baseId and baseId ~= 0 then
            if DoesAbilityExist(baseId) then
                trace ('Found Base Ability %s with ID %d',  GetAbilityName(baseId), baseId)
                AG.setdata[nr].Skill[skillnr] = baseId
            else 
                trace ('Invalid BaseId: %d', baseId)
            end
        else
            trace ('Old Ability not found')
        end
    else
        trace ('Found Old Ability: %s',  GetAbilityName(oldSkillId))
    end
end


--- initialise set list
function AG.initSetData(setdata)
    for x = 1, MAXSLOT do
        setdata[x] = {
            Gear = {}, 
            Skill = {},
            Set = { text = {0,0,0}, gear = 0, skill = {0,0}, icon = {0,0}, lock = 0, outfit = AG.OUTFIT_KEEP }
        }
        for z = 1, #SLOTS do setdata[x].Gear[z] = { id = 0, link = 0 } end
        for z = 1, 6 do setdata[x].Skill[z] = 0 end
    end 

end


--- stores the current set-list as profile with Id profileId
function AG.storeProfile(profileId)
    -- always clear
    AG.setdata.profiles[profileId].setdata = {}
    
    -- copy slots
    for i = 1, MAXSLOT do
        AG.setdata.profiles[profileId].setdata[i] = AG.setdata[i]       
    end
    
    -- copy current slotId
    AG.setdata.profiles[profileId].setdata.lastset = AG.setdata.lastset
end


--- loads profile with Id profileId as current set-list. 
-- stores the current set-list under its profileId
function AG.LoadProfile(profileId)

    trace("AG.LoadProfile %d", profileId)
    if profileId == AG.setdata.currentProfileId then 
        -- nothing to do
        return
    end

    -- store current profile Id
    AG.previousProfile = AG.setdata.currentProfileId
    
    -- store current set-list
    AG.storeProfile(AG.setdata.currentProfileId)
    
    -- lazy create new profile
    if not AG.setdata.profiles[profileId].setdata then
        AG.setdata.profiles[profileId].setdata = {}
        AG.setdata.profiles[profileId].setdata.lastset = false
        AG.initSetData(AG.setdata.profiles[profileId].setdata)
    end
    
    -- load new profile
    for i = 1, MAXSLOT do
        AG.setdata[i] = AG.setdata.profiles[profileId].setdata[i]
    end


    AG.setdata.currentProfileId = profileId
    
    -- update UI and equip set
    -- skills & gear
    
    AG.UpdateItemLinks()

    for setIndex = 1, MAXSLOT do
        for slotId = 1, 6 do
            AG.ShowButton(WM:GetControlByName('AG_Button_Skill_'..setIndex..'_'..slotId))
        end

        for slotId = 1, #SLOTS do
            AG.ShowButton(WM:GetControlByName('AG_Button_Gear_'..setIndex..'_'..slotId))
        end
    end

    d("Loaded profile '"..AG.setdata.profiles[profileId].name.."'")
    
    AG.HideEditPanel()
    
    AG.UpdateUI()
    AG.previousSet = nil
    
    if AG.isLoadLastBuildOfProfile() then
        AG.setdata.lastset = AG.setdata.profiles[profileId].setdata.lastset
        AG.LoadSet(AG.setdata.lastset)
    else 
        AG.setdata.lastset = false
    end
    
    AG.UpdateSetButtons()
end


--- loads profile with the bindId profileBindId as current set-list. 
-- stores the current set-list under its profileId
function AG.LoadProfileByBindID(profileBindId)
    AG.LoadProfile(profileBindId)
end

function AG.IsBuildEmpty(setdata, buildId)
    local set = setdata[buildId].Set
    if not set then return true end 

    return (set.gear == nil or set.gear == 0) 
            and (set.skill == nil or (set.skill[1] == 0 and set.skill[2] == 0)) 
            and (set.outfit == nil or set.outfit == -1)
end

function AG.IsProfileEmpty(profileId)

    local setdata = AG.setdata.profiles[profileId].setdata
    if not setdata then return true end

    for buildId = 1, MAXSLOT do
        if not AG.IsBuildEmpty(setdata, buildId) then
            return false
        end
    end
    return true
end

--- load the next profile according to sort-order
function AG.LoadNextProfile()
    trace("AG.LoadNextProfile()")
 
    -- init profileId after reload
    if not AG.setdata.currentProfileId or AG.setdata.currentProfileId == 0 then
        AG.setdata.currentProfileId = 1
    end

    local newProfileId = AG.setdata.currentProfileId
    local oldProfileId = AG.setdata.currentProfileId

    -- cycle through profiles until the next filled
    repeat
        if newProfileId < MAX_PROFILES then
            newProfileId = newProfileId + 1
        else
            newProfileId = 1
        end
        trace ("loop through profiles: old "..oldProfileId.." new "..newProfileId)
    until (newProfileId == oldProfileId) or (not AG.IsProfileEmpty(newProfileId))

    AG.LoadProfile(newProfileId)
end

--- load the previous profile according to sort-order
function AG.LoadPreviousProfile()
    trace("AG.LoadPreviousProfile()")

    -- init profileId after reload
    if not AG.setdata.currentProfileId or AG.setdata.currentProfileId == 0 then
        AG.setdata.currentProfileId = 1
    end

    local newProfileId = AG.setdata.currentProfileId
    local oldProfileId = AG.setdata.currentProfileId

    -- cycle through profiles until the next filled
    repeat
        if newProfileId > 1 then
            newProfileId = newProfileId - 1
        else
            newProfileId = MAX_PROFILES
        end
        trace ("loop through profiles: old "..oldProfileId.." new "..newProfileId)
    until (newProfileId == oldProfileId) or (not AG.IsProfileEmpty(newProfileId))

    AG.LoadProfile(newProfileId)
end

--- toggles between the last two used profiles
function AG.ToggleProfile()
    if AG.setdata.currentProfileId and AG.previousProfile then
        AG.LoadProfile(AG.previousProfile)
    else
        d(L.MsgNoPreviousProfile)
    end
end

function AG.ToggleDebug(extra)
    AG.isDebug = not AG.isDebug
    if AG.isDebug then
        d("AlphaGear 2: debug messages ON")
    else
        d("AlphaGear 2: debug messages OFF")
    end
end

--[[
function AG.OnGamepadPreferredModeChanged()
    trace ("GP Mode changed")
    -- update Layout
    AG.InitPositions()
end
]]--

function AG.OnScreenResized()
    trace ("Screen size changed")
    -- update Layout
    AG.InitPositions()
end


function AG:Initialize()

    SM:RegisterTopLevel(AG_Panel,false)

    EM:RegisterForEvent("AG4", EVENT_ARMORY_BUILD_RESTORE_RESPONSE,  AG.ClearAvailableEquipmentCache)
    EM:RegisterForEvent('AG4', EVENT_ACTION_SLOTS_FULL_UPDATE, AG.Swap)
    EM:RegisterForEvent('AG4', EVENT_INVENTORY_FULL_UPDATE, AG.ClearAvailableEquipmentCache)
    EM:RegisterForEvent('AG4', EVENT_PLAYER_COMBAT_STATE, AG.OnPlayerCombatState)
    EM:RegisterForEvent('AG4', EVENT_INVENTORY_ITEM_DESTROYED, AG.ClearAvailableEquipmentCache)
    EM:RegisterForEvent('AG4', EVENT_INVENTORY_SINGLE_SLOT_UPDATE, AG.HandleInventorySlotUpdate)
    EM:RegisterForEvent('AG4', EVENT_OPEN_BANK, AG.ClearAvailableEquipmentCache)
    EM:RegisterForEvent('AG4', EVENT_CLOSE_BANK, AG.ClearAvailableEquipmentCache)
    -- EM:RegisterForEvent("AG_GAMESTYLE_CHANGED", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, AG.OnGamepadPreferredModeChanged)
    EM:RegisterForEvent("AG_SCREEN_SIZE_CHANGED", EVENT_SCREEN_RESIZED, AG.OnScreenResized)


    -- EM:RegisterForEvent("AG4", EVENT_OUTFIT_EQUIP_RESPONSE, AG.ShowOutfits)
    -- EM:RegisterForEvent("AG4", EVENT_OUTFIT_CHANGE_RESPONSE, AG.ShowOutfits)


    UIElements = {AG_Panel, AG_UI_ButtonBg, AG_SetButtonBg, AG_SwapMessageBg, AG_RepairMainBg, AG_ChargeMainBg}
    
    SLASH_COMMANDS["/alphagear"] = AG.ShowMain
    SLASH_COMMANDS["/agdbg"] = AG.ToggleDebug
    SLASH_COMMANDS["/agclear"] = AG.ClearProfile
    SLASH_COMMANDS["/agimport"] = ImportProfileCommand
    
    -- initialize account wide settings
    AG.account = ZO_SavedVars:NewAccountWide('AGX2_Account', AG.accountVariableVersion, nil, AG.account_defaults)
    
   
    -- Post-Load Check for missing account members
    if AG.account.Integrations == nil then
        AG.account.Integrations = {table.unpack(AG.account_defaults.Integrations)}
    end
    

    -- initialize character wide settings
    
    local init_data =  AG.setdata_defaults
    AG.initSetData(init_data)
    
    --[[
    for x = 1, MAXSLOT do
        init_data[x] = {
            Gear = {}, 
            Skill = {},
            Set = { text = {0,0,0}, gear = 0, skill = {0,0}, icon = {0,0}, lock = 0, outfit = AG.OUTFIT_KEEP }
        }
        for z = 1, #SLOTS do init_data[x].Gear[z] = { id = 0, link = 0 } end
        for z = 1, 6 do init_data[x].Skill[z] = 0 end
    end 
    ]]--
    
    AG.setdata = ZO_SavedVars:New('AGX2_Character', AG.characterVariableVersion, nil, init_data)
    
    -- Post-Load Check for missing members
    for x = 1, MAXSLOT do
        -- new since 6.2.0
        -- Outfit-ID
        if AG.setdata[x].Set.outfit == nil then
            AG.setdata[x].Set.outfit = AG.OUTFIT_KEEP
        end

        -- Slot for Poison
        if AG.setdata[x].Gear[15] == nil then
            AG.setdata[x].Gear[15] = { id = 0, link = 0 }
        end

        -- Slot for BackupPoison
        if AG.setdata[x].Gear[16] == nil then
            AG.setdata[x].Gear[16] = { id = 0, link = 0 }
        end
        -- end new since 6.2.0
        -- new since 6.3.0
        for z = 1, 6 do 
            AG.CheckSkillId (x, z)
        end
        -- end new since 6.3.0
    end
    
    -- Initialize profile structure
    if AG.setdata.profiles == nil then
        AG.setdata.currentProfileId = 1
        AG.setdata.profiles = {}
        
        for i = 1, MAX_PROFILES do
            AG.setdata.profiles[i] = {}
            AG.setdata.profiles[i].name = 'Profile '..i
            AG.setdata.profiles[i].currentBuild = 1
        end
        
        -- store main set-list as profile 1
        AG.storeProfile(1)
    end

    
    
    -- initialize settings page
    self:CreateSettingsPage()


    -- for x = 1, MAXSLOT do
    -- for z = 1,6 do
    -- if type(AG.setdata[x].Skill[z]) == 'table' then
    -- local a,b,c = unpack(AG.setdata[x].Skill[z])
    -- AG.setdata[x].Skill[z] = GetSkillAbilityId(a,b,c,false) or 0
    -- end
    -- end
    -- end

    AG.SetupMainPanel()

    AG.DrawSetButtonsUI()
    AG.DrawInventory()
    AG.SetupInventoryCallback()
    
    AG:SetOptions()
    
    AG.InitEditProfileDialog()
    AGImportDlg.Initialize()
    
    zo_callLater(AG.SwapMessage,900)
    -- AG_PanelOptionPanelPlus:SetAnchor(8,AG_Option_2,8,0,0)

    AlphaGear_RegisterIcon('AlphaGear/asset/onehand.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/onehand_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/twohand.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/twohand_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/fire.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/fire_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/frost.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/frost_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/shock.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/shock_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/heal.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/heal_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/bow.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/bow_aoe.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/shield.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/power.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/bonehead.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/training.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/wolf.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/vampire.dds')
    AlphaGear_RegisterIcon('AlphaGear/asset/horse.dds')

    SELECT = AG.setdata.lastset

    -- Kyzer 12/5/21: fix /agimport because I pull that from the inactive set data
    ZO_PreHook("ReloadUI", function() AG.storeProfile(AG.setdata.currentProfileId) end)
    ZO_PreHook("Logout", function() AG.storeProfile(AG.setdata.currentProfileId) end)
    ZO_PreHook("SetCVar", function() AG.storeProfile(AG.setdata.currentProfileId) end)
    ZO_PreHook("Quit", function() AG.storeProfile(AG.setdata.currentProfileId) end)

    -- Kyzer 11/25/21: prehook to skip sorting (due to AutoCategory lag) when performing bulk mode
    -- Updated 12/5/21: hook after playeractivated due to AutoCategory change
    AG.recentInventoryType = INVENTORY_BACKPACK
    local prehookRetries = 0
    if (AutoCategory) then
        EVENT_MANAGER:RegisterForEvent(AG.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(AG.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED)
            EVENT_MANAGER:RegisterForUpdate(AG.name .. "ApplySortPrehook", 5000, function()
                if (AutoCategory.Inited == true) then
                    ZO_PreHook(PLAYER_INVENTORY, "ApplySort", function(self, inventoryType) AG.recentInventoryType = inventoryType return AG.InBulkMode end)
                    -- d("Successfully prehooked ApplySort after AutoCategory init.")
                    EVENT_MANAGER:UnregisterForUpdate(AG.name .. "ApplySortPrehook")
                elseif (prehookRetries > 5) then
                    d("Gave up trying to hook AutoCategory. Is something wrong? Yell at Kyzer, probably.")
                    EVENT_MANAGER:UnregisterForUpdate(AG.name .. "ApplySortPrehook")
                else
                    prehookRetries = prehookRetries + 1
                end
            end)
        end)
    end

    -- Kyzer 9/7/26: Add LibRadialMenu entries
    if (LibRadialMenu) then
        local LRM = LibRadialMenu
        LRM:RegisterAddon("AlphaGear 2", "AlphaGear 2")
        for i = 1, MAXSLOT do
            local texture
            if (i <= 8 and CrutchAlerts) then
                texture = string.format("CrutchAlerts/assets/shape/diamond_red_%d.dds", i)
            else
                texture = string.format("/esoui/art/icons/ability_weapon_0%02d.dds", i)
            end

            LRM:RegisterEntry(
                "AlphaGear 2",
                "Equip set " .. i,
                "Set" .. i,
                texture,
                function() AG.LoadSet(i) end,
                "Equips set (build) " .. i .. " of your current profile.")
        end
    end

    AG.init = true
end

function AG.OnAddOnLoaded(event, addonName)
  if addonName ~= AG.name then return end

  EM:UnregisterForEvent('AG4',EVENT_ADD_ON_LOADED)
  
  AG:Initialize()
end


EM:RegisterForEvent('AG4', EVENT_ADD_ON_LOADED, AG.OnAddOnLoaded)

