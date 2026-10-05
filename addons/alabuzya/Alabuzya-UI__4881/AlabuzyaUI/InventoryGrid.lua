local AlabuzyaUI = AlabuzyaUI
-- AlabuzyaUI InventoryGrid, alabuzya, 2026-09-24. GPL-3.0-or-later.
-- Original implementation using ESO scroll-list operations; no GridList assets/code bundled.
local SIZE, GAP = 64, 5
local states = {}
local saved
local deferredHooks = setmetatable({}, {__mode="k"})
local fields = {"Button", "ButtonIcon", "ButtonStackCount", "Name", "SellPrice", "SellPriceText",
    "Status", "TraitInfo", "SellInformation", "Bg", "Highlight", "ItemCondition", "ActiveIcon"}
local function Capture(c)
    -- GetAlpha includes the scene's current fade. Saving it would bake a
    -- partially opened inventory's opacity into every subsequent restoration.
    local s = { width=c:GetWidth(), height=c:GetHeight(), hidden=c:IsControlHidden(), alpha=c:GetControlAlpha(), layer=c:GetDrawLayer(), level=c:GetDrawLevel(), anchors={} }
    for i=0,c:GetNumAnchors()-1 do
        local valid, point, relative, relativePoint, x, y, constraints = c:GetAnchor(i)
        if valid then s.anchors[#s.anchors+1]={point,relative,relativePoint,x,y,constraints} end
    end
    return s
end
local function Restore(c,s)
    c:ClearAnchors()
    c:SetDimensions(s.width,s.height)
    for _,a in ipairs(s.anchors) do c:SetAnchor(unpack(a)) end
    c:SetHidden(s.hidden)
    c:SetAlpha(s.alpha)
    c:SetDrawLayer(s.layer) c:SetDrawLevel(s.level)
end
local function Place(c,point,parent,relative,x,y,w,h)
    if not c then return end
    c:ClearAnchors()
    c:SetAnchor(point,parent,relative,x,y)
    if w then c:SetDimensions(w,h) end
end
local function Prepare(row)
    if row.diaGridOriginal then return end
    local originals={}
    for _,name in ipairs(fields) do
        local c=row:GetNamedChild(name)
        if c then originals[c]=Capture(c) end
    end
    row.diaGridOriginal=originals
    row.diaGridBackground=WINDOW_MANAGER:CreateControl(nil,row,CT_BACKDROP)
    local bg=row.diaGridBackground
    bg:SetAnchorFill()
    bg:SetCenterColor(0.015,0.015,0.015,0.95)
    bg:SetEdgeTexture(nil,1,1,1)
    bg:SetDrawLayer(DL_BACKGROUND)
    bg:SetDrawLevel(0)
    bg:SetMouseEnabled(false)
end
-- Native ESO intentionally hides TraitInfo while shopping. Grids have room for
-- separate trait/sale badges; retain the native controls and their tooltips.
AlabuzyaUI.InventoryGrid = {}
-- Render the grid image directly on its cell, independently of the native
-- list button's nested texture geometry. Keep the native button for actions,
-- tooltips and cooldowns; native setup remains responsible for item tint.
function AlabuzyaUI.InventoryGrid.UpdateIcon(row,data,grid)
    local image=row.diaGridIcon
    if not grid then
        if image then image:SetHidden(true) end
        return
    end
    local button=row:GetNamedChild("Button")
    local native=button and button:GetNamedChild("Icon")
    if not native then return end
    if not image then
        image=WINDOW_MANAGER:CreateControl(nil,row,CT_TEXTURE)
        row.diaGridIcon=image
        image:SetMouseEnabled(false)
        Place(image,CENTER,row,CENTER,0,0,44,44)
    end
    image:SetDrawTier(row:GetDrawTier())
    image:SetDrawLayer(DL_CONTROLS)
    image:SetDrawLevel(2)
    local texture=data.iconFile
    if (not texture or texture=="") and data.bagId and data.slotIndex then
        texture=GetItemInfo(data.bagId,data.slotIndex)
    end
    if not texture or texture=="" then texture=native:GetTextureFileName() end
    local valid=texture and texture~=""
    -- Do not restart a pending texture request on every visible-row refresh.
    if image:GetTextureFileName()~=(texture or "") then image:SetTexture(texture or "") end
    image:SetColor(native:GetColor())
    -- The row already inherits the scene fade; copy only the icon's own alpha
    -- (including the native locked-item dimming), never the effective alpha.
    image:SetAlpha(native:GetControlAlpha())
    image:SetHidden(not valid)
    native:SetHidden(true)
end
function AlabuzyaUI.InventoryGrid.UpdateBadges(row, data)
    local trait = row:GetNamedChild("TraitInfo")
    local sell = row:GetNamedChild("SellInformation")
    local info = data.traitInformation
    local hasTrait = info and info ~= ITEM_TRAIT_INFORMATION_NONE
    if trait and trait.ClearIcons and ZO_GetPlatformTraitInformationIcon then
        trait:ClearIcons()
        local icon = hasTrait and ZO_GetPlatformTraitInformationIcon(info)
        hasTrait = icon and icon ~= ""
        if hasTrait then trait:AddIcon(icon) trait:Show() end
        trait:SetHidden(not hasTrait)
        trait:SetDrawLayer(DL_OVERLAY) trait:SetDrawLevel(5)
    end
    Place(trait,TOPRIGHT,row,TOPRIGHT,-2,2,18,18)
    Place(sell,TOPRIGHT,row,TOPRIGHT,-2,hasTrait and 22 or 2,18,18)
    if sell then sell:SetDrawLayer(DL_OVERLAY) sell:SetDrawLevel(5) end
end
local function Style(row,data,grid)
    local bg=row.diaGridBackground
    bg:SetHidden(not grid)
    if not grid then
        AlabuzyaUI.InventoryGrid.UpdateIcon(row,data,false)
        return
    end
    row:SetDimensions(SIZE,SIZE)
    for _,name in ipairs({"Name","SellPrice","SellPriceText","Bg","Highlight","ItemCondition"}) do
        local c=row:GetNamedChild(name)
        if c then c:SetHidden(true) end
    end
    local button=row:GetNamedChild("Button")
    Place(button,CENTER,row,CENTER,0,0,44,44)
    AlabuzyaUI.InventoryGrid.UpdateIcon(row,data,grid)
    Place(row:GetNamedChild("ButtonStackCount"),BOTTOMRIGHT,row,BOTTOMRIGHT,-3,-3)
    Place(row:GetNamedChild("Status"),TOPLEFT,row,TOPLEFT,2,2,18,18)
    AlabuzyaUI.InventoryGrid.UpdateBadges(row,data)
    Place(row:GetNamedChild("ActiveIcon"),TOPLEFT,row,TOPLEFT,2,2,18,18)
    local quality=data.quality or data.displayQuality or ITEM_DISPLAY_QUALITY_NORMAL
    local r,g,b=GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS,quality)
    -- Muted quality hue: thin, partly desaturated and dimmed.
    local gray = (r + g + b) / 3
    bg:SetEdgeColor((r * 0.8 + gray * 0.2) * 0.75,
        (g * 0.8 + gray * 0.2) * 0.75,
        (b * 0.8 + gray * 0.2) * 0.75, 0.85)
end
local function Apply(state)
    local list=state.list
    state.grid=saved[state.key] ~= false and not IsInGamepadPreferredMode()
    list.dataTypes=state.grid and state.gridTypes or state.originalTypes
    list.mode=state.grid and state.gridMode or state.originalMode
    list.uniformControlHeight=state.originalHeight
    if not state.grid then
        -- ESO's uniform list reuses entry.left when positioning rows.
        -- Grid columns must not leak into the restored list.
        for _,entry in ipairs(ZO_ScrollList_GetDataList(list)) do
            entry.left = 0
            entry.right = nil
        end
    end
    local ru = GetCVar("language.2") == "ru"
    state.button:SetText(state.grid and (ru and "Список" or "List") or (ru and "Сетка" or "Grid"))
    -- Commit computes bottom/left and visibleData for the new layout. Resetting
    -- first fires OnValueChanged against the previous uniform layout, whose
    -- entries have no bottom coordinate (FindStartPoint then subtracts nil).
    ZO_ScrollList_Commit(list)
    local ready=true
    if state.grid then
        local data=ZO_ScrollList_GetDataList(list)
        for _,index in ipairs(list.visibleData or {}) do
            if not data[index] or type(data[index].bottom)~="number" then ready=false break end
        end
    end
    -- Commit can defer until anchors give the list a positive height.
    if ready then
        ZO_ScrollList_ResetToTop(list)
        ZO_ScrollList_RefreshVisible(list)
    end
end
-- OnEffectivelyShown is also used by ESO to populate and reset the list.
-- Rebuild only after those handlers finish, not from a pre-hook inside them.
local function QueueRefresh(state, rebuild)
    state.rebuildPending=state.rebuildPending or rebuild
    if state.refreshPending then return end
    state.refreshPending=true
    zo_callLater(function()
        state.refreshPending=false
        if state.list:IsHidden() then return end
        local rebuildNow=state.rebuildPending
        state.rebuildPending=false
        if rebuildNow then Apply(state)
        else ZO_ScrollList_RefreshVisible(state.list) end
    end,0)
end
local function Install(list,key)
    if not list or not list.dataTypes or not list.contents or states[list] then return end
    -- Unknown header/custom data types keep their existing layout instead of risking broken interactions.
    for id,t in pairs(list.dataTypes) do
        if id<1 or id>3 or not t.pool or not t.setupCallback then return end
    end
    if not next(list.dataTypes) then return end
    local state={list=list,key=key,originalTypes=list.dataTypes,gridTypes={},
        originalMode=list.mode,originalHeight=list.uniformControlHeight}
    states[list]=state
    for id,t in pairs(state.originalTypes) do
        local nativeSetup=t.setupCallback
        local function Setup(row,data,...)
            Prepare(row)
            for c,s in pairs(row.diaGridOriginal) do Restore(c,s) end
            if not state.grid then row:SetHeight(t.height) end
            nativeSetup(row,data,...)
            Style(row,data,state.grid)
        end
        t.setupCallback=Setup
        list.dataTypes=state.gridTypes
        ZO_ScrollList_AddControlOperation(list,id,nil,SIZE,SIZE,nil,Setup,t.hideCallback,GAP,GAP,0,t.selectable,false)
        state.gridMode=list.mode -- Set by the native constructor; its enum is local to ESO.
        local op=state.gridTypes[id]
        op.pool=t.pool
        op.height=t.height
        op.selectSound=t.selectSound
    end
    list.dataTypes=state.originalTypes
    list.mode=state.originalMode
    local button=WINDOW_MANAGER:CreateControl(nil,list,CT_BUTTON)
    button:SetDimensions(126,26)
    button:SetMouseEnabled(true)
    local border=WINDOW_MANAGER:CreateControl(nil,button,CT_BACKDROP)
    border:SetAnchorFill()
    border:SetCenterColor(0.06,0.05,0.03,0.95)
    border:SetEdgeTexture(nil,1,1,1)
    border:SetEdgeColor(0.75,0.65,0.35,1)
    border:SetDrawLayer(DL_BACKGROUND)
    border:SetMouseEnabled(false)
    button:SetAnchor(BOTTOMLEFT,list,TOPLEFT,4,-28)
    button:SetFont(AlabuzyaUI.Theme.Font(17))
    button:SetNormalFontColor(0.85,0.75,0.5,1)
    button:SetMouseOverFontColor(1,1,1,1)
    button:SetDrawLayer(DL_OVERLAY)
    button:SetHandler("OnClicked",function()
        saved[key]=not state.grid
        Apply(state)
    end)
    state.button=button
    ZO_PostHookHandler(list,"OnEffectivelyShown",function() QueueRefresh(state,true) end)
    Apply(state)
end
local Discover
local function WatchWindow(window, key)
    if not window then return end
    if window.list then Install(window.list, key) end
    if window.OnDeferredInitialize and not deferredHooks[window] then
        deferredHooks[window] = true
        SecurePostHook(window, "OnDeferredInitialize", function() Discover() end)
    end
end
local function FindCraftingLists(object, seen, depth)
    if type(object) ~= "table" or seen[object] or depth > 3 then return end
    seen[object] = true
    if object.list and object.GetScrollDataType and object.GetDefaultTemplateSetupFunction then
        local name = object.list:GetName()
        if name and name ~= "" then Install(object.list, "crafting:" .. name) end
        return
    end
    for _,field in ipairs({"inventory", "deconstructionPanel", "improvementPanel",
        "refinementPanel", "creationPanel", "retraitPanel", "retrait", "extractionPanel"}) do
        FindCraftingLists(object[field], seen, depth + 1)
    end
end
Discover = function()
    if not saved or GridList then return end
    if PLAYER_INVENTORY and PLAYER_INVENTORY.inventories then
        -- Enumerate actual inventory objects, including furniture vault and future bag types.
        -- Preserve inventory<N> keys from 0.1.5 so existing choices survive the update.
        for kind, inventory in pairs(PLAYER_INVENTORY.inventories) do
            if type(inventory) == "table" then
                Install(inventory.listView, "inventory" .. tostring(kind))
            end
        end
    end
    for _,name in ipairs({"STORE_WINDOW", "BUY_BACK_WINDOW", "REPAIR_WINDOW", "QUICKSLOT_KEYBOARD"}) do
        WatchWindow(_G[name], name)
    end
    local seen = {}
    for _,name in ipairs({"SMITHING", "ENCHANTING", "ALCHEMY", "PROVISIONER",
        "ZO_RETRAIT_KEYBOARD", "RETRAIT_STATION_KEYBOARD", "UNIVERSAL_DECONSTRUCTION"}) do
        FindCraftingLists(_G[name], seen, 0)
    end
end
function AlabuzyaUI.InventoryGrid.Initialize()
    if AlabuzyaUI.Settings and not AlabuzyaUI.Settings.Enabled("grid") then return end
    saved=AlabuzyaUI.SavedVariables.Account("inventoryGrid",{})
    -- Native bag data is updated before these callbacks. Coalesce a burst of
    -- loot/stack changes into one refresh after ESO updates the visible rows.
    if SHARED_INVENTORY then
        local function RefreshItems()
            for _,state in pairs(states) do
                if state.grid and not state.list:IsHidden() then QueueRefresh(state,false) end
            end
        end
        for _,event in ipairs({"SingleSlotInventoryUpdate","FullInventoryUpdate"}) do
            SHARED_INVENTORY:RegisterCallback(event,RefreshItems)
        end
    end
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_PLAYER_ACTIVATED,Discover)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_OPEN_STORE,Discover)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_OPEN_BANK,Discover)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_OPEN_GUILD_BANK,Discover)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_GUILD_BANK_ITEMS_READY,Discover)
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_CRAFTING_STATION_INTERACT,function()
        zo_callLater(Discover, 0)
    end)
    if ZO_CraftingInventory and ZO_CraftingInventory.InitializeList then
        SecurePostHook(ZO_CraftingInventory, "InitializeList", function(inventory)
            if saved and not GridList and inventory.list then
                local name = inventory.list:GetName()
                if name and name ~= "" then Install(inventory.list, "crafting:" .. name) end
            end
        end)
    end
    EVENT_MANAGER:RegisterForEvent("AlabuzyaUIInventoryGrid",EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,function()
        for _,state in pairs(states) do Apply(state) end
    end)
    Discover()
end
