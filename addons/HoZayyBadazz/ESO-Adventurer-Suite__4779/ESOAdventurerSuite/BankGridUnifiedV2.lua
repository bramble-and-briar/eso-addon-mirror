-- ESO Adventurer Suite
-- v0.29.534 - unified bank grid V2.
-- One bank owner. Grid is a sibling of the actual bank list and every visual
-- child receives an explicit high draw tier/layer so hitboxes and artwork match.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER or not EVENT_MANAGER then return end

local U = { open=false, collapsed={WITHDRAW={},DEPOSIT={}}, cells={}, headers={}, scroll=0 }
EPC.BankGridUnifiedV2 = U

local wm = WINDOW_MANAGER
local NAME = (EPC.name or "ESOAdventurerSuite") .. "_BankGridUnifiedV2029534"
local CELL, GAP, HEADER_H, MAX_CELLS = 48, 5, 28, 320

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a = pcall(fn, ...)
    if not ok or a == nil then return fallback end
    return a
end

local function num(fn, fallback, ...)
    return tonumber(first(fn, fallback, ...))
end

local function high(control, level)
    if not control then return end
    if type(control.SetAlpha)=="function" then control:SetAlpha(1) end
    if type(control.SetDrawTier)=="function" and rawget(_G,"DT_HIGH")~=nil then control:SetDrawTier(DT_HIGH) end
    if type(control.SetDrawLayer)=="function" and rawget(_G,"DL_OVERLAY")~=nil then control:SetDrawLayer(DL_OVERLAY) end
    if type(control.SetDrawLevel)=="function" then control:SetDrawLevel(level or 100) end
end

local function isBankOpen()
    if U.open then return true end
    local inv=rawget(_G,"PLAYER_INVENTORY")
    if type(inv)=="table" then
        if type(inv.IsBanking)=="function" then local ok,v=pcall(inv.IsBanking,inv); if ok and v then return true end end
        if type(inv.IsGuildBanking)=="function" then local ok,v=pcall(inv.IsGuildBanking,inv); if ok and v then return true end end
    end
    return false
end

local function invList(invType)
    local inv=rawget(_G,"PLAYER_INVENTORY")
    if type(inv)~="table" or type(inv.inventories)~="table" or invType==nil then return nil end
    local data=inv.inventories[invType]
    if type(data)~="table" then return nil end
    for _,k in ipairs({"list","listView","scrollList"}) do
        local c=data[k]
        if c and type(c.GetLeft)=="function" then return c end
    end
end

local function candidates()
    local out,seen={},{}
    local function add(mode,c)
        if not c or seen[c] or type(c.GetLeft)~="function" then return end
        seen[c]=true; out[#out+1]={mode=mode,control=c}
    end
    add("WITHDRAW",rawget(_G,"ZO_PlayerBankBackpack"))
    add("DEPOSIT",rawget(_G,"ZO_PlayerInventoryList"))
    add("WITHDRAW",invList(rawget(_G,"INVENTORY_BANK")))
    add("WITHDRAW",invList(rawget(_G,"INVENTORY_HOUSE_BANK")))
    add("WITHDRAW",invList(rawget(_G,"INVENTORY_GUILD_BANK")))
    add("DEPOSIT",invList(rawget(_G,"INVENTORY_BACKPACK")))
    return out
end

local function selectedMode()
    local inv=rawget(_G,"PLAYER_INVENTORY")
    local s=type(inv)=="table" and tonumber(inv.selectedTabType) or nil
    if s==rawget(_G,"INVENTORY_BACKPACK") then return "DEPOSIT" end
    if s==rawget(_G,"INVENTORY_BANK") or s==rawget(_G,"INVENTORY_HOUSE_BANK") or s==rawget(_G,"INVENTORY_GUILD_BANK") then return "WITHDRAW" end
end

local function resolvePane()
    if not isBankOpen() then return nil end
    local preferred=selectedMode(); local best
    for _,e in ipairs(candidates()) do
        local c=e.control
        if c and type(c.IsHidden)=="function" and first(c.IsHidden,true,c)==false then
            local l,t,r,b=num(c.GetLeft,nil,c),num(c.GetTop,nil,c),num(c.GetRight,nil,c),num(c.GetBottom,nil,c)
            if l and t and r and b then
                local w,h=r-l,b-t
                if w>250 and h>150 then
                    local score=w*h + ((preferred==e.mode) and 100000000 or 0)
                    if not best or score>best.score then best={mode=e.mode,control=c,w=w,h=h,score=score} end
                end
            end
        end
    end
    return best
end

local function same(value,...)
    for i=1,select("#",...) do local v=select(i,...); if v~=nil and value==v then return true end end
    return false
end

local function classify(link,bag,slot)
    local equip=tonumber(first(GetItemLinkEquipType,0,link)) or 0
    local itemType=tonumber(first(GetItemType,0,bag,slot)) or 0
    if same(equip,rawget(_G,"EQUIP_TYPE_MAIN_HAND"),rawget(_G,"EQUIP_TYPE_OFF_HAND"),rawget(_G,"EQUIP_TYPE_TWO_HAND"),rawget(_G,"EQUIP_TYPE_ONE_HAND")) then return "WEAPONS",10 end
    if same(equip,rawget(_G,"EQUIP_TYPE_HEAD"),rawget(_G,"EQUIP_TYPE_CHEST"),rawget(_G,"EQUIP_TYPE_SHOULDERS"),rawget(_G,"EQUIP_TYPE_WAIST"),rawget(_G,"EQUIP_TYPE_LEGS"),rawget(_G,"EQUIP_TYPE_FEET"),rawget(_G,"EQUIP_TYPE_HAND")) then return "ARMOR",20 end
    if same(equip,rawget(_G,"EQUIP_TYPE_RING"),rawget(_G,"EQUIP_TYPE_NECK")) then return "JEWELRY",30 end
    if same(itemType,rawget(_G,"ITEMTYPE_FOOD"),rawget(_G,"ITEMTYPE_DRINK"),rawget(_G,"ITEMTYPE_POTION"),rawget(_G,"ITEMTYPE_POISON"),rawget(_G,"ITEMTYPE_RECIPE"),rawget(_G,"ITEMTYPE_CONTAINER")) then return "CONSUMABLES",40 end
    if same(itemType,rawget(_G,"ITEMTYPE_BLACKSMITHING_MATERIAL"),rawget(_G,"ITEMTYPE_CLOTHIER_MATERIAL"),rawget(_G,"ITEMTYPE_WOODWORKING_MATERIAL"),rawget(_G,"ITEMTYPE_REAGENT"),rawget(_G,"ITEMTYPE_RAW_MATERIAL"),rawget(_G,"ITEMTYPE_STYLE_MATERIAL"),rawget(_G,"ITEMTYPE_TRAIT_MATERIAL"),rawget(_G,"ITEMTYPE_ENCHANTING_RUNE_ASPECT"),rawget(_G,"ITEMTYPE_ENCHANTING_RUNE_ESSENCE"),rawget(_G,"ITEMTYPE_ENCHANTING_RUNE_POTENCY")) then return "MATERIALS",50 end
    return "OTHER",90
end

local function qualityColor(q)
    q=tonumber(q) or 0
    local ct=rawget(_G,"INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS")
    if type(GetInterfaceColor)=="function" and ct~=nil then local ok,r,g,b=pcall(GetInterfaceColor,ct,q); if ok and r~=nil then return r,g,b end end
    return .35,.42,.50
end

local function searchText(mode)
    local names=mode=="WITHDRAW" and {"ZO_PlayerBankSearchFiltersTextSearchBox","ZO_PlayerBankSearchFiltersTextSearch"} or {"ZO_PlayerInventorySearchFiltersTextSearchBox","ZO_PlayerInventorySearchFiltersTextSearch"}
    for _,n in ipairs(names) do local c=rawget(_G,n); if c and type(c.GetText)=="function" then return string.lower(tostring(first(c.GetText,"",c) or "")) end end
    return ""
end

local CollectImpl

function U:Collect(...)

    return CollectImpl(self, ...)

end

CollectImpl = function(self, mode)
    local bags=mode=="WITHDRAW" and {rawget(_G,"BAG_BANK"),rawget(_G,"BAG_SUBSCRIBER_BANK")} or {rawget(_G,"BAG_BACKPACK")}
    local search=searchText(mode); local items={}
    for _,bag in ipairs(bags) do
        if bag~=nil and type(GetBagSize)=="function" then
            local size=tonumber(first(GetBagSize,0,bag)) or 0
            for slot=0,size-1 do
                local link=tostring(first(GetItemLink,"",bag,slot,rawget(_G,"LINK_STYLE_DEFAULT") or 0) or "")
                if link~="" then
                    local name=tostring(first(GetItemName,"",bag,slot) or "")
                    if search=="" or string.find(string.lower(name),search,1,true) then
                        local icon,stack,_,_,locked,_,_,quality
                        if type(GetItemInfo)=="function" then local ok; ok,icon,stack,_,_,locked,_,_,quality=pcall(GetItemInfo,bag,slot); if not ok then icon,stack,locked,quality=nil,nil,false,nil end end
                        stack=tonumber(stack) or tonumber(first(GetSlotStackSize,1,bag,slot)) or 1
                        quality=tonumber(quality) or tonumber(first(GetItemDisplayQuality,0,bag,slot)) or 0
                        local group,order=classify(link,bag,slot)
                        items[#items+1]={bag=bag,slot=slot,name=name,icon=tostring(icon or ""),stack=stack,quality=quality,locked=locked==true,group=group,order=order}
                    end
                end
            end
        end
    end
    table.sort(items,function(a,b) if a.order~=b.order then return a.order<b.order end if a.quality~=b.quality then return a.quality>b.quality end return string.lower(a.name)<string.lower(b.name) end)
    return items
end

local function emptyDestination(targets)
    for _,bag in ipairs(targets) do if bag~=nil and type(FindFirstEmptySlotInBag)=="function" then local s=first(FindFirstEmptySlotInBag,nil,bag); if s~=nil then return bag,s end end end
end

local MoveImpl

function U:Move(...)

    return MoveImpl(self, ...)

end

MoveImpl = function(self, item)
    if not item or not isBankOpen() then return end
    if item.locked and self.mode=="DEPOSIT" then return end
    local targets=self.mode=="WITHDRAW" and {rawget(_G,"BAG_BACKPACK")} or {rawget(_G,"BAG_BANK"),rawget(_G,"BAG_SUBSCRIBER_BANK")}
    local db,ds=emptyDestination(targets); if db==nil then return end
    local count=tonumber(first(GetSlotStackSize,1,item.bag,item.slot)) or tonumber(item.stack) or 1
    local prot=false; if type(IsProtectedFunction)=="function" then local ok,v=pcall(IsProtectedFunction,"RequestMoveItem"); prot=ok and v==true end
    if prot and type(CallSecureProtected)=="function" then pcall(CallSecureProtected,"RequestMoveItem",item.bag,item.slot,db,ds,count)
    elseif type(RequestMoveItem)=="function" then pcall(RequestMoveItem,item.bag,item.slot,db,ds,count) end
end

local CreateForImpl

function U:CreateFor(...)

    return CreateForImpl(self, ...)

end

CreateForImpl = function(self, info)
    local parent=type(info.control.GetParent)=="function" and info.control:GetParent() or GuiRoot
    if self.root and self.parent==parent then return end
    if self.root then self.root:SetHidden(true) end
    self.cells={}; self.headers={}; self.parent=parent
    local root=wm:CreateControl("EASBankUnifiedRoot029534",parent,CT_CONTROL)
    root:SetMouseEnabled(true); root:SetAlpha(1); high(root,900)
    root:SetAnchor(TOPLEFT,info.control,TOPLEFT,0,0); root:SetAnchor(BOTTOMRIGHT,info.control,BOTTOMRIGHT,0,0)
    self.root=root
    local bg=wm:CreateControl(nil,root,CT_BACKDROP); bg:SetAnchorFill(root); bg:SetCenterColor(.015,.02,.03,1); bg:SetEdgeColor(.55,.42,.16,1); bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds",1,1,2); high(bg,901); self.bg=bg
    local title=wm:CreateControl(nil,root,CT_LABEL); title:SetAnchor(TOPLEFT,root,TOPLEFT,8,5); title:SetDimensions(520,24); title:SetFont("ZoFontWinH4"); title:SetColor(1,.82,.26,1); high(title,902); self.title=title
    root:SetHandler("OnMouseWheel",function(_,delta) self.scroll=math.max(0,(tonumber(self.scroll) or 0)-(tonumber(delta) or 0)*100) end)
end

local GetHeaderImpl

function U:GetHeader(...)

    return GetHeaderImpl(self, ...)

end

GetHeaderImpl = function(self, i)
    local h=self.headers[i]; if h then return h end
    h=wm:CreateControl("EASBankUnifiedHeader029534_"..i,self.root,CT_BUTTON); h:SetHeight(HEADER_H); h:SetMouseEnabled(true); high(h,920)
    local bg=wm:CreateControl(nil,h,CT_BACKDROP); bg:SetAnchorFill(h); bg:SetCenterColor(.035,.055,.08,1); bg:SetEdgeColor(.35,.45,.55,1); bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds",1,1,1); high(bg,921); h.bg=bg
    local label=wm:CreateControl(nil,h,CT_LABEL); label:SetAnchor(TOPLEFT,h,TOPLEFT,8,3); label:SetAnchor(BOTTOMRIGHT,h,BOTTOMRIGHT,-4,-3); label:SetFont("ZoFontGameBold"); label:SetColor(1,.82,.26,1); high(label,922); h.label=label
    h:SetHandler("OnClicked",function(ctrl) if ctrl.group and self.mode then self.collapsed[self.mode][ctrl.group]=not(self.collapsed[self.mode][ctrl.group]==true) end end)
    self.headers[i]=h; return h
end

local GetCellImpl

function U:GetCell(...)

    return GetCellImpl(self, ...)

end

GetCellImpl = function(self, i)
    local c=self.cells[i]; if c then return c end
    c=wm:CreateControl("EASBankUnifiedCell029534_"..i,self.root,CT_BUTTON); c:SetDimensions(CELL,CELL); c:SetMouseEnabled(true); high(c,930)
    local bg=wm:CreateControl(nil,c,CT_BACKDROP); bg:SetAnchorFill(c); bg:SetCenterColor(.06,.07,.09,1); bg:SetEdgeTexture("EsoUI/Art/Miscellaneous/white_1x1.dds",1,1,2); high(bg,931); c.bg=bg
    local icon=wm:CreateControl(nil,c,CT_TEXTURE); icon:SetAnchor(TOPLEFT,c,TOPLEFT,3,3); icon:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-3,-3); icon:SetTextureCoords(.05,.95,.05,.95); icon:SetColor(1,1,1,1); high(icon,932); c.icon=icon
    local count=wm:CreateControl(nil,c,CT_LABEL); count:SetAnchor(BOTTOMRIGHT,c,BOTTOMRIGHT,-2,-1); count:SetDimensions(28,14); count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); count:SetFont("ZoFontGameSmall"); count:SetColor(1,1,1,1); high(count,933); c.count=count
    c:SetHandler("OnMouseEnter",function(ctrl) if ctrl.item and ItemTooltip and type(InitializeTooltip)=="function" then InitializeTooltip(ItemTooltip,ctrl,LEFT,-8,0,RIGHT); if type(ItemTooltip.SetBagItem)=="function" then pcall(ItemTooltip.SetBagItem,ItemTooltip,ctrl.item.bag,ctrl.item.slot) end end end)
    c:SetHandler("OnMouseExit",function() if ItemTooltip and type(ClearTooltip)=="function" then pcall(ClearTooltip,ItemTooltip) end end)
    c:SetHandler("OnClicked",function(ctrl) if ctrl.item then self:Move(ctrl.item) end end)
    self.cells[i]=c; return c
end

local function restore(c) if c then if type(c.SetAlpha)=="function" then c:SetAlpha(1) end if type(c.SetMouseEnabled)=="function" then c:SetMouseEnabled(true) end end end

local RenderImpl

function U:Render(...)

    return RenderImpl(self, ...)

end

RenderImpl = function(self, info)
    self:CreateFor(info); self.mode=info.mode; self.root:SetHidden(false); self.root:SetAlpha(1); high(self.root,900); self.title:SetText("ESO ADVENTURER SUITE — "..info.mode)
    local items=self:Collect(info.mode); if #items==0 then self.root:SetHidden(true); return false end
    local groups,order={},{}
    for _,it in ipairs(items) do if not groups[it.group] then groups[it.group]={}; order[#order+1]=it.group end groups[it.group][#groups[it.group]+1]=it end
    table.sort(order,function(a,b) return (groups[a][1].order or 90)<(groups[b][1].order or 90) end)
    local width=tonumber(first(self.root.GetWidth,info.w,self.root)) or info.w; local cols=math.max(4,math.floor((width-16)/(CELL+GAP))); local y=34-(tonumber(self.scroll) or 0); local hi,ci=0,0
    for _,group in ipairs(order) do
        hi=hi+1; local h=self:GetHeader(hi); h:SetHidden(false); high(h,920); h:ClearAnchors(); h:SetAnchor(TOPLEFT,self.root,TOPLEFT,4,y); h:SetWidth(width-12); h.group=group
        local collapsed=self.collapsed[info.mode][group]==true; h.label:SetText((collapsed and "+  " or "-  ")..group.."  ("..#groups[group]..")"); y=y+HEADER_H+GAP
        if not collapsed then
            local rows=0
            for i,it in ipairs(groups[group]) do ci=ci+1; if ci>MAX_CELLS then break end local c=self:GetCell(ci); c:SetHidden(false); high(c,930); c.item=it; c:ClearAnchors(); local col=(i-1)%cols; local row=math.floor((i-1)/cols); rows=math.max(rows,row+1); c:SetAnchor(TOPLEFT,self.root,TOPLEFT,4+col*(CELL+GAP),y+row*(CELL+GAP)); c.icon:SetTexture(it.icon~="" and it.icon or "EsoUI/Art/Icons/icon_missing.dds"); high(c.icon,932); high(c.bg,931); high(c.count,933); c.count:SetText(it.stack>1 and tostring(it.stack) or ""); local r,g,b=qualityColor(it.quality); c.bg:SetEdgeColor(r,g,b,1); c.bg:SetCenterColor(.05+r*.15,.06+g*.15,.08+b*.15,1) end
            y=y+rows*(CELL+GAP)+GAP
        end
    end
    for i=hi+1,#self.headers do self.headers[i]:SetHidden(true) end
    for i=ci+1,#self.cells do self.cells[i]:SetHidden(true); self.cells[i].item=nil end
    return hi>0 and ci>0
end

local RefreshImpl

function U:Refresh(...)

    return RefreshImpl(self, ...)

end

RefreshImpl = function(self)
    for _,e in ipairs(candidates()) do restore(e.control) end
    if not isBankOpen() then if self.root then self.root:SetHidden(true) end return end
    local info=resolvePane(); if not info then if self.root then self.root:SetHidden(true) end return end
    local ok,shown=pcall(self.Render,self,info); if not ok or not shown then if self.root then self.root:SetHidden(true) end return end
    -- Same-parent sibling now visibly covers the list. Suppress rows only after render.
    if type(info.control.SetAlpha)=="function" then info.control:SetAlpha(0) end
    if type(info.control.SetMouseEnabled)=="function" then info.control:SetMouseEnabled(false) end
end

EPC.Runtime:RegisterUpdate("BankGridUnifiedV2","Refresh",150,function() U:Refresh() end)
if rawget(_G,"EVENT_OPEN_BANK") then EPC.Runtime:RegisterEvent("BankGridUnifiedV2","Open",EVENT_OPEN_BANK,function() U.open=true; if type(zo_callLater)=="function" then zo_callLater(function() U:Refresh() end,50) else U:Refresh() end end) end
if rawget(_G,"EVENT_CLOSE_BANK") then EPC.Runtime:RegisterEvent("BankGridUnifiedV2","Close",EVENT_CLOSE_BANK,function() U.open=false; for _,e in ipairs(candidates()) do restore(e.control) end if U.root then U.root:SetHidden(true) end end) end


-- Absorbed bank correction layers: architecture hardening batch A

-- BEGIN ABSORBED: BankGridModeSwitchFix.lua
-- ESO Adventurer Suite
-- v0.29.535 - Bank Withdraw/Deposit mode-switch root reuse.
-- Reuse the working V2 bank grid instead of creating duplicate named controls
-- when ESO changes the active bank pane/parent.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U then return end

local baseCreateFor = CreateForImpl
local applyWheelHandler

local function forceHigh(control, level)
    if not control then return end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then
        pcall(control.SetDrawTier, control, DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then
        pcall(control.SetDrawLayer, control, DL_OVERLAY)
    end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 900) end
end

CreateForImpl = function(self, info)
    if type(info) ~= "table" or not info.control then return end

    local parent = nil
    if type(info.control.GetParent) == "function" then
        local ok, value = pcall(info.control.GetParent, info.control)
        if ok then parent = value end
    end
    parent = parent or rawget(_G, "GuiRoot")

    -- First bank pane: let V2 create the one named control pool normally.
    if not self.root then
        local result = baseCreateFor(self, info)
        if applyWheelHandler then applyWheelHandler(self) end
        return result
    end

    -- Later Withdraw <-> Deposit switches must reuse that pool. ESO controls are
    -- globally named, so creating EASBankUnifiedRoot029534 twice throws the
    -- duplicate-name error reported by the client.
    if parent and self.parent ~= parent and type(self.root.SetParent) == "function" then
        pcall(self.root.SetParent, self.root, parent)
    end
    self.parent = parent

    -- Re-anchor the existing root to whichever live bank list is active now.
    if type(self.root.ClearAnchors) == "function" then pcall(self.root.ClearAnchors, self.root) end
    if type(self.root.SetAnchor) == "function" then
        pcall(self.root.SetAnchor, self.root, TOPLEFT, info.control, TOPLEFT, 0, 0)
        pcall(self.root.SetAnchor, self.root, BOTTOMRIGHT, info.control, BOTTOMRIGHT, 0, 0)
    end

    if type(self.root.SetHidden) == "function" then pcall(self.root.SetHidden, self.root, false) end
    if type(self.root.SetMouseEnabled) == "function" then pcall(self.root.SetMouseEnabled, self.root, true) end
    forceHigh(self.root, 900)
    forceHigh(self.bg, 901)
    forceHigh(self.title, 902)

    -- Headers/cells are children of the reused root, so they move with it and
    -- retain their globally unique names. Reassert their visual state after the
    -- parent change because ESO/PerfectPixel can refresh the bank scene here.
    for _, h in ipairs(self.headers or {}) do
        if h then
            forceHigh(h, 920)
            forceHigh(h.bg, 921)
            forceHigh(h.label, 922)
        end
    end
    for _, c in ipairs(self.cells or {}) do
        if c then
            forceHigh(c, 930)
            forceHigh(c.bg, 931)
            forceHigh(c.icon, 932)
            forceHigh(c.count, 933)
        end
    end
    if applyWheelHandler then applyWheelHandler(self) end
end

-- END ABSORBED: BankGridModeSwitchFix.lua

-- BEGIN ABSORBED: BankGridScrollClampFix.lua
-- ESO Adventurer Suite
-- v0.29.536 - bank grid scroll clamp + manual viewport clipping.
-- The V2 bank grid uses plain controls, so child controls are not automatically
-- clipped by the parent. Clamp scrolling to content height and hide controls
-- outside the visible bank pane.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U then return end

local CELL, GAP, HEADER_H = 48, 5, 28
local TOP_INSET, BOTTOM_INSET = 34, 4

local baseRender = RenderImpl

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function contentHeight(self, info)
    if type(self.Collect) ~= "function" or type(info) ~= "table" then return TOP_INSET end
    local items = self:Collect(info.mode)
    if type(items) ~= "table" then return TOP_INSET end

    local groups, order = {}, {}
    for _, item in ipairs(items) do
        local group = tostring(item.group or "OTHER")
        if not groups[group] then
            groups[group] = {}
            order[#order + 1] = group
        end
        groups[group][#groups[group] + 1] = item
    end
    table.sort(order, function(a, b)
        return (tonumber(groups[a][1] and groups[a][1].order) or 90)
            < (tonumber(groups[b][1] and groups[b][1].order) or 90)
    end)

    local width = self.root and tonumber(first(self.root.GetWidth, info.w or 0, self.root)) or tonumber(info.w) or 0
    local cols = math.max(4, math.floor((width - 16) / (CELL + GAP)))
    local y = TOP_INSET
    local collapsedByMode = self.collapsed and self.collapsed[info.mode] or {}

    for _, group in ipairs(order) do
        y = y + HEADER_H + GAP
        if not (collapsedByMode and collapsedByMode[group] == true) then
            local rows = math.ceil(#groups[group] / cols)
            y = y + rows * (CELL + GAP) + GAP
        end
    end
    return y
end

applyWheelHandler = function(self)
    if not self.root or type(self.root.SetHandler) ~= "function" then return end
    self.root:SetHandler("OnMouseWheel", function(_, delta)
        local maxScroll = tonumber(self.maxScroll029536) or 0
        local current = tonumber(self.scroll) or 0
        local step = 92
        self.scroll = math.max(0, math.min(maxScroll, current - (tonumber(delta) or 0) * step))
    end)
end

local function clipControls(self)
    local root = self.root
    if not root then return end
    local rootTop = tonumber(first(root.GetTop, nil, root))
    local rootBottom = tonumber(first(root.GetBottom, nil, root))
    if not rootTop or not rootBottom then return end

    local clipTop = rootTop + TOP_INSET
    local clipBottom = rootBottom - BOTTOM_INSET

    local function clip(control)
        if not control or type(control.GetTop) ~= "function" or type(control.GetBottom) ~= "function" then return end
        local top = tonumber(first(control.GetTop, nil, control))
        local bottom = tonumber(first(control.GetBottom, nil, control))
        if not top or not bottom then return end
        local outside = bottom <= clipTop or top >= clipBottom or top < clipTop or bottom > clipBottom
        if type(control.SetHidden) == "function" then control:SetHidden(outside) end
        if type(control.SetMouseEnabled) == "function" then control:SetMouseEnabled(not outside) end
    end

    for _, header in ipairs(self.headers or {}) do clip(header) end
    for _, cell in ipairs(self.cells or {}) do clip(cell) end
end

RenderImpl = function(self, info)
    if type(info) ~= "table" then return false end

    -- Ensure the root exists before calculating viewport/content dimensions.
    self:CreateFor(info)

    local height = self.root and tonumber(first(self.root.GetHeight, info.h or 0, self.root)) or tonumber(info.h) or 0
    local total = contentHeight(self, info)
    self.maxScroll029536 = math.max(0, total - math.max(0, height - BOTTOM_INSET))
    self.scroll = math.max(0, math.min(self.maxScroll029536, tonumber(self.scroll) or 0))

    local shown = baseRender(self, info)
    if shown then
        clipControls(self)
    end
    return shown
end

-- END ABSORBED: BankGridScrollClampFix.lua

-- BEGIN ABSORBED: BankGridCategoryFix.lua
-- ESO Adventurer Suite
-- v0.29.655 - bank visible set-name grouping + companion category correctness.
-- Set gear is presented under one collapsible header per set in BOTH Withdraw
-- and Deposit. Companion gear is kept separate from player Weapons/Armor/Jewelry.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U then return end

local CELL, GAP, HEADER_H, MAX_CELLS = 48, 5, 28, 320
local TOP_INSET, BOTTOM_INSET, SIDE_INSET = 34, 4, 4

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function high(control, level)
    if not control then return end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
    if type(control.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then pcall(control.SetDrawTier, control, DT_HIGH) end
    if type(control.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then pcall(control.SetDrawLayer, control, DL_OVERLAY) end
    if type(control.SetDrawLevel) == "function" then pcall(control.SetDrawLevel, control, level or 900) end
end

local CATEGORY_ORDER = { WEAPONS=110, ARMOR=120, JEWELRY=130, COMPANION=135, CONSUMABLES=140, MATERIALS=150, OTHER=190 }
local CATEGORY_LABELS = { WEAPONS="Weapons (No Set)", ARMOR="Armor (No Set)", JEWELRY="Jewelry (No Set)", COMPANION="Companion Gear", CONSUMABLES="Consumables", MATERIALS="Materials", OTHER="Other" }
local GEAR_FAMILY_ORDER = { WEAPONS=10, ARMOR=20, JEWELRY=30, COMPANION=35 }

local function ensureState(self, mode)
    self.collapsed = self.collapsed or {}
    self.collapsed.WITHDRAW = self.collapsed.WITHDRAW or {}
    self.collapsed.DEPOSIT = self.collapsed.DEPOSIT or {}
    self.collapsed[mode] = self.collapsed[mode] or {}
    return self.collapsed[mode]
end

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function itemLess(a, b)
    local af, bf = GEAR_FAMILY_ORDER[a and a.group] or 90, GEAR_FAMILY_ORDER[b and b.group] or 90
    if af ~= bf then return af < bf end

    if a and b and a.group == "ARMOR" and b.group == "ARMOR" then
        local as = tonumber(a._easArmorSlotOrder029652) or 999
        local bs = tonumber(b._easArmorSlotOrder029652) or 999
        if as ~= bs then return as < bs end
    end

    local aq, bq = tonumber(a and a.quality) or 0, tonumber(b and b.quality) or 0
    if aq ~= bq then return aq > bq end

    return lower(a and a.name) < lower(b and b.name)
end

local function groupItems(items)
    local groups, order, labels, meta = {}, {}, {}, {}

    for _, item in ipairs(items or {}) do
        local groupKey
        local displayName = tostring(item and item._easSetDisplayName029652 or "")
        local setKey = tostring(item and item._easSetName029652 or "")
        local hasSet = item and item._easHasSet029652 == true and setKey ~= "" and item.group ~= "COMPANION"

        if hasSet then
            groupKey = "SET:" .. setKey
            labels[groupKey] = displayName ~= "" and displayName or setKey
            meta[groupKey] = { isSet=true, sortName=setKey, order=10 }
        else
            local category = tostring(item and item.group or "OTHER")
            if not CATEGORY_ORDER[category] then category = "OTHER" end
            groupKey = category
            labels[groupKey] = CATEGORY_LABELS[category] or category
            meta[groupKey] = { isSet=false, sortName=lower(labels[groupKey]), order=CATEGORY_ORDER[category] or 190 }
        end

        if not groups[groupKey] then
            groups[groupKey] = {}
            order[#order + 1] = groupKey
        end
        groups[groupKey][#groups[groupKey] + 1] = item
    end

    table.sort(order, function(a, b)
        local am, bm = meta[a] or {}, meta[b] or {}
        local ao, bo = tonumber(am.order) or 999, tonumber(bm.order) or 999
        if ao ~= bo then return ao < bo end
        return tostring(am.sortName or a) < tostring(bm.sortName or b)
    end)

    for key, list in pairs(groups) do
        if meta[key] and meta[key].isSet == true then
            table.sort(list, itemLess)
        end
    end

    return groups, order, labels
end

local baseGetHeader = GetHeaderImpl
GetHeaderImpl = function(self, i)
    local header = baseGetHeader(self, i)
    if header and not header._easCategoryClick029537 then
        header._easCategoryClick029537 = true
        header:SetHandler("OnClicked", function(ctrl)
            local mode, group = self.mode, ctrl.group
            if not mode or not group then return end
            local state = ensureState(self, mode)
            state[group] = not (state[group] == true)
            self.scroll = 0
            self.dirty = true
        end)
    end
    return header
end

local function deactivatePool(self)
    for _, header in ipairs(self.headers or {}) do
        header._easBankActive029543 = false
        if type(header.SetHidden) == "function" then pcall(header.SetHidden, header, true) end
        if type(header.SetMouseEnabled) == "function" then pcall(header.SetMouseEnabled, header, false) end
    end
    for _, cell in ipairs(self.cells or {}) do
        cell._easBankActive029543 = false
        cell.item = nil
        if type(cell.SetHidden) == "function" then pcall(cell.SetHidden, cell, true) end
        if type(cell.SetMouseEnabled) == "function" then pcall(cell.SetMouseEnabled, cell, false) end
    end
end

local function clipToViewport(self)
    local root = self.root
    if not root then return end
    local rootTop = tonumber(first(root.GetTop,nil,root))
    local rootBottom = tonumber(first(root.GetBottom,nil,root))
    local rootLeft = tonumber(first(root.GetLeft,nil,root))
    local rootRight = tonumber(first(root.GetRight,nil,root))
    if not rootTop or not rootBottom or not rootLeft or not rootRight then return end

    local clipTop, clipBottom = rootTop + TOP_INSET, rootBottom - BOTTOM_INSET
    local clipLeft, clipRight = rootLeft + SIDE_INSET, rootRight - SIDE_INSET

    local function geometry(control)
        if not control then return nil end
        local top = type(control.GetTop)=="function" and tonumber(first(control.GetTop,nil,control)) or nil
        local bottom = type(control.GetBottom)=="function" and tonumber(first(control.GetBottom,nil,control)) or nil
        local left = type(control.GetLeft)=="function" and tonumber(first(control.GetLeft,nil,control)) or nil
        local right = type(control.GetRight)=="function" and tonumber(first(control.GetRight,nil,control)) or nil
        return top,bottom,left,right
    end

    for _, header in ipairs(self.headers or {}) do
        if header._easBankActive029543 ~= true then
            if type(header.SetHidden)=="function" then pcall(header.SetHidden,header,true) end
            if type(header.SetMouseEnabled)=="function" then pcall(header.SetMouseEnabled,header,false) end
        else
            local top,bottom,left,right = geometry(header)
            local visible = top and bottom and left and right and bottom > clipTop and top < clipBottom and right > clipLeft and left < clipRight
            if type(header.SetHidden)=="function" then pcall(header.SetHidden,header,not visible) end
            if type(header.SetMouseEnabled)=="function" then pcall(header.SetMouseEnabled,header,visible==true) end
        end
    end

    for _, cell in ipairs(self.cells or {}) do
        if cell._easBankActive029543 ~= true or cell.item == nil then
            if type(cell.SetHidden)=="function" then pcall(cell.SetHidden,cell,true) end
            if type(cell.SetMouseEnabled)=="function" then pcall(cell.SetMouseEnabled,cell,false) end
        else
            local top,bottom,left,right = geometry(cell)
            local contained = top and bottom and left and right and top >= clipTop and bottom <= clipBottom and left >= clipLeft and right <= clipRight
            if type(cell.SetHidden)=="function" then pcall(cell.SetHidden,cell,not contained) end
            if type(cell.SetMouseEnabled)=="function" then pcall(cell.SetMouseEnabled,cell,contained==true) end
        end
    end
end

RenderImpl = function(self, info)
    if type(info) ~= "table" then return false end
    self:CreateFor(info)
    if not self.root then return false end

    self.mode = info.mode
    local collapsed = ensureState(self, info.mode)
    self.root:SetHidden(false)
    self.root:SetAlpha(1)
    high(self.root,900)
    if self.title then self.title:SetText("ESO ADVENTURER SUITE — " .. tostring(info.mode or "BANK")) end

    deactivatePool(self)

    local items = type(self.Collect)=="function" and self:Collect(info.mode) or {}
    if type(items) ~= "table" or #items == 0 then return true end

    local groups, order, labels = groupItems(items)
    if #order == 0 then return true end

    local width = tonumber(first(self.root.GetWidth,info.w or 0,self.root)) or tonumber(info.w) or 0
    local height = tonumber(first(self.root.GetHeight,info.h or 0,self.root)) or tonumber(info.h) or 0
    local cols = math.max(4, math.floor((width - 16)/(CELL + GAP)))

    local totalY = TOP_INSET
    for _, group in ipairs(order) do
        totalY = totalY + HEADER_H + GAP
        if not collapsed[group] then totalY = totalY + math.ceil(#groups[group]/cols)*(CELL+GAP) + GAP end
    end
    self.maxScroll029536 = math.max(0,totalY - math.max(0,height - BOTTOM_INSET))
    self.scroll = math.max(0,math.min(self.maxScroll029536,tonumber(self.scroll) or 0))

    local y, hi, ci = TOP_INSET - self.scroll, 0, 0
    for _, group in ipairs(order) do
        hi = hi + 1
        local header = self:GetHeader(hi)
        header._easBankActive029543 = true
        header.group = group
        header:ClearAnchors()
        header:SetAnchor(TOPLEFT,self.root,TOPLEFT,SIDE_INSET,y)
        header:SetWidth(width - (SIDE_INSET*2 + 4))
        header:SetHidden(false)
        header:SetMouseEnabled(true)
        high(header,920); high(header.bg,921); high(header.label,922)

        local isCollapsed = collapsed[group] == true
        header.label:SetText((isCollapsed and "+  " or "-  ") .. tostring(labels[group] or group) .. "  (" .. tostring(#groups[group]) .. ")")
        y = y + HEADER_H + GAP

        if not isCollapsed then
            local rows = 0
            for i,item in ipairs(groups[group]) do
                ci = ci + 1
                if ci > MAX_CELLS then break end
                local cell = self:GetCell(ci)
                cell._easBankActive029543 = true
                cell.item = item
                cell:ClearAnchors()
                local col = (i-1)%cols
                local row = math.floor((i-1)/cols)
                rows = math.max(rows,row+1)
                cell:SetAnchor(TOPLEFT,self.root,TOPLEFT,SIDE_INSET + col*(CELL+GAP),y + row*(CELL+GAP))
                cell:SetHidden(false)
                cell:SetMouseEnabled(true)
                high(cell,930); high(cell.bg,931); high(cell.icon,932); high(cell.count,933)
                if cell.icon then cell.icon:SetTexture(item.icon ~= "" and item.icon or "EsoUI/Art/Icons/icon_missing.dds") end
                if cell.count then cell.count:SetText((tonumber(item.stack) or 1) > 1 and tostring(item.stack) or "") end
            end
            y = y + rows*(CELL+GAP) + GAP
        end
    end

    clipToViewport(self)
    return hi > 0
end

U.dirty = true

-- END ABSORBED: BankGridCategoryFix.lua

-- BEGIN ABSORBED: BankGridFilterAndSwitchFix.lua
-- ESO Adventurer Suite
-- v0.29.654 - exact bank top-category filtering without double-filter false negatives.
-- Bank Withdraw and Deposit use ESO's selected top display category as the one
-- authoritative category predicate. Do not run ShouldAddSlotToList a second time
-- against the Suite's separately collected bag items; that could incorrectly hide
-- valid Materials, Jewelry, and other categories.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U then return end

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function inventoryList(invType)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" or invType == nil then return nil end
    local data = manager.inventories[invType]
    if type(data) ~= "table" then return nil end
    for _, key in ipairs({ "list", "listView", "scrollList" }) do
        local control = data[key]
        if control and type(control.GetLeft) == "function" then return control end
    end
    return nil
end

local function candidates()
    local out, seen = {}, {}
    local function add(mode, control, invType)
        if not control or seen[control] or type(control.GetLeft) ~= "function" then return end
        seen[control] = true
        out[#out + 1] = { mode = mode, control = control, invType = invType }
    end

    local BACKPACK = rawget(_G, "INVENTORY_BACKPACK")
    local BANK = rawget(_G, "INVENTORY_BANK")
    local HOUSE = rawget(_G, "INVENTORY_HOUSE_BANK")
    local GUILD = rawget(_G, "INVENTORY_GUILD_BANK")

    add("WITHDRAW", rawget(_G, "ZO_PlayerBankBackpack"), BANK)
    add("DEPOSIT", rawget(_G, "ZO_PlayerInventoryList"), BACKPACK)
    add("WITHDRAW", inventoryList(BANK), BANK)
    add("WITHDRAW", inventoryList(HOUSE), HOUSE)
    add("WITHDRAW", inventoryList(GUILD), GUILD)
    add("DEPOSIT", inventoryList(BACKPACK), BACKPACK)
    return out
end

local function bankInventoryType(mode)
    if mode == "DEPOSIT" then return rawget(_G, "INVENTORY_BACKPACK") end
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) == "table" then
        if type(manager.GetBankInventoryType) == "function" then
            local ok, value = pcall(manager.GetBankInventoryType, manager)
            if ok and value ~= nil then return value end
        end
        if type(manager.IsGuildBanking) == "function" then
            local ok, value = pcall(manager.IsGuildBanking, manager)
            if ok and value == true then return rawget(_G, "INVENTORY_GUILD_BANK") end
        end
    end
    return rawget(_G, "INVENTORY_BANK")
end

local function nativeInventoryForMode(mode)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" then return nil, nil, nil end
    local invType = bankInventoryType(mode)
    local inventory = invType ~= nil and manager.inventories[invType] or nil
    if type(inventory) ~= "table" then return manager, nil, invType end
    return manager, inventory, invType
end

local function nativeSlotData(inventory, item)
    if type(item) ~= "table" then return nil end
    if type(inventory) == "table" and type(inventory.slots) == "table" then
        local bagSlots = inventory.slots[item.bag]
        if type(bagSlots) == "table" then
            local direct = bagSlots[item.slot]
            if type(direct) == "table" then return direct end
            for _, slotData in pairs(bagSlots) do
                if type(slotData) == "table" and slotData.bagId == item.bag and slotData.slotIndex == item.slot then
                    return slotData
                end
            end
        end
    end
    local shared = rawget(_G, "SHARED_INVENTORY")
    if type(shared) == "table" and type(shared.GenerateSingleSlotData) == "function" then
        local ok, data = pcall(shared.GenerateSingleSlotData, shared, item.bag, item.slot)
        if ok and type(data) == "table" then return data end
    end
    return nil
end

U._easBankTopFilter029542 = U._easBankTopFilter029542 or {}

local manager = rawget(_G, "PLAYER_INVENTORY")
if type(manager) == "table" and type(manager.ChangeFilter) == "function" and not manager._easBankExactFilterHook029542 then
    manager._easBankExactFilterHook029542 = true
    local baseChangeFilter = manager.ChangeFilter
    manager.ChangeFilter = function(self, filterTab, ...)
        local results = { baseChangeFilter(self, filterTab, ...) }
        if type(filterTab) == "table" and not filterTab.isSubFilter then
            local invType = filterTab.inventoryType
            local filterType = filterTab.filterType or filterTab.descriptor
            if invType ~= nil and filterType ~= nil then U._easBankTopFilter029542[invType] = filterType end
        end
        U.scroll = 0
        U.dirty = true
        if type(zo_callLater) == "function" then
            zo_callLater(function() if U and type(U.Refresh) == "function" then U:Refresh() end end, 0)
        elseif type(U.Refresh) == "function" then U:Refresh() end
        return unpack(results)
    end
end

local function activeTopFilter(inventory, invType)
    local captured = U._easBankTopFilter029542 and U._easBankTopFilter029542[invType]
    if captured ~= nil then return captured end
    return type(inventory) == "table" and inventory.currentFilter or rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_ALL")
end

local function topCategoryPass(slotData, filter)
    local ALL = rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_ALL")
    if filter == nil or filter == ALL then return true end
    local utils = rawget(_G, "ZO_ItemFilterUtils")
    if type(utils) == "table" and type(utils.IsSlotInItemTypeDisplayCategory) == "function" and type(slotData) == "table" then
        local ok, allowed = pcall(utils.IsSlotInItemTypeDisplayCategory, slotData, filter)
        if ok then return allowed == true end
    end
    -- If ESO cannot classify the generated slot data, fail open rather than
    -- hiding a real item the player can clearly see in the source bag.
    return true
end

local baseCollect = CollectImpl
CollectImpl = function(self, mode)
    local items = type(baseCollect) == "function" and baseCollect(self, mode) or {}
    if type(items) ~= "table" then return {} end

    local _, inventory, invType = nativeInventoryForMode(mode)
    if type(inventory) ~= "table" then return items end

    local filter = activeTopFilter(inventory, invType)
    local ALL = rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_ALL")
    if filter == nil or filter == ALL then return items end

    local filtered = {}
    for _, item in ipairs(items) do
        local slotData = nativeSlotData(inventory, item)
        if topCategoryPass(slotData, filter) then filtered[#filtered + 1] = item end
    end
    return filtered
end

local function selectedMode()
    local mgr = rawget(_G, "PLAYER_INVENTORY")
    local selected = type(mgr) == "table" and tonumber(mgr.selectedTabType) or nil
    if selected == rawget(_G, "INVENTORY_BACKPACK") then return "DEPOSIT" end
    if selected == rawget(_G, "INVENTORY_BANK") or selected == rawget(_G, "INVENTORY_HOUSE_BANK") or selected == rawget(_G, "INVENTORY_GUILD_BANK") then return "WITHDRAW" end
    return nil
end

local function resolvePane()
    local preferred = selectedMode()
    local best
    for _, entry in ipairs(candidates()) do
        local c = entry.control
        if c and type(c.IsHidden) == "function" and first(c.IsHidden, true, c) == false then
            local l = tonumber(first(c.GetLeft, nil, c)); local t = tonumber(first(c.GetTop, nil, c))
            local r = tonumber(first(c.GetRight, nil, c)); local b = tonumber(first(c.GetBottom, nil, c))
            if l and t and r and b then
                local w, h = r - l, b - t
                if w > 250 and h > 150 then
                    local score = w * h + ((preferred == entry.mode) and 100000000 or 0)
                    if not best or score > best.score then best = { mode=entry.mode, control=c, invType=entry.invType, w=w, h=h, score=score } end
                end
            end
        end
    end
    return best
end

local function restore(control)
    if not control then return end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
    if type(control.SetMouseEnabled) == "function" then pcall(control.SetMouseEnabled, control, true) end
end

local function suppress(control)
    if not control then return end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 0) end
    if type(control.SetMouseEnabled) == "function" then pcall(control.SetMouseEnabled, control, false) end
end

local function bankOpen()
    if U.open == true then return true end
    local mgr = rawget(_G, "PLAYER_INVENTORY")
    if type(mgr) == "table" then
        if type(mgr.IsBanking) == "function" then local ok,v=pcall(mgr.IsBanking,mgr); if ok and v==true then return true end end
        if type(mgr.IsGuildBanking) == "function" then local ok,v=pcall(mgr.IsGuildBanking,mgr); if ok and v==true then return true end end
    end
    return false
end

RefreshImpl = function(self)
    if not bankOpen() then
        for _, entry in ipairs(candidates()) do restore(entry.control) end
        if self.root and type(self.root.SetHidden) == "function" then pcall(self.root.SetHidden, self.root, true) end
        self._suiteBankActive029539 = false
        return
    end
    local info = resolvePane()
    if not info or type(self.Render) ~= "function" then
        if self._suiteBankActive029539 then for _, entry in ipairs(candidates()) do suppress(entry.control) end end
        return
    end
    local ok, shown = pcall(self.Render, self, info)
    if ok and shown == true then
        self._suiteBankActive029539 = true
        for _, entry in ipairs(candidates()) do suppress(entry.control) end
        if self.root and type(self.root.SetHidden) == "function" then pcall(self.root.SetHidden, self.root, false) end
        return
    end
    if not self._suiteBankActive029539 then
        for _, entry in ipairs(candidates()) do restore(entry.control) end
        if self.root and type(self.root.SetHidden) == "function" then pcall(self.root.SetHidden, self.root, true) end
    else
        for _, entry in ipairs(candidates()) do suppress(entry.control) end
    end
end

U.dirty = true

-- END ABSORBED: BankGridFilterAndSwitchFix.lua

-- BEGIN ABSORBED: BankArmorSortFix.lua
-- ESO Adventurer Suite
-- v0.29.652 - Bank gear set-name sorting.
-- Set-bearing gear is grouped alphabetically by set name before its secondary
-- equipment ordering. Armor keeps Head -> Shoulders -> Chest -> Hands -> Waist
-- -> Legs -> Feet inside each set. Non-set gear follows named sets.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U or type(U.Collect) ~= "function" or U._easArmorSort029652 then return end
U._easArmorSort029652 = true

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function setNameForLink(link)
    if link == "" or type(GetItemLinkSetInfo) ~= "function" then return "", false end
    local ok, hasSet, setName = pcall(GetItemLinkSetInfo, link, false)
    if not ok or hasSet ~= true then return "", false end
    setName = tostring(setName or "")
    if setName == "" then return "", false end
    return setName, true
end

local ARMOR_SLOT_ORDER = {}
local function put(name, order)
    local value = rawget(_G, name)
    if value ~= nil then ARMOR_SLOT_ORDER[value] = order end
end
put("EQUIP_TYPE_HEAD", 10)
put("EQUIP_TYPE_SHOULDERS", 20)
put("EQUIP_TYPE_CHEST", 30)
put("EQUIP_TYPE_HAND", 40)
put("EQUIP_TYPE_WAIST", 50)
put("EQUIP_TYPE_LEGS", 60)
put("EQUIP_TYPE_FEET", 70)

local GEAR_GROUPS = { WEAPONS=true, ARMOR=true, JEWELRY=true }

local function applyAuthoritativeGearSort(items)
    if type(items) ~= "table" or #items < 1 then return items end

    for _, item in ipairs(items) do
        item._easArmorSlotOrder029652 = nil
        item._easSetName029652 = item._easSetName029652 or ""
        item._easSetDisplayName029652 = item._easSetDisplayName029652 or ""
        item._easHasSet029652 = item._easHasSet029652 == true

        if item and GEAR_GROUPS[item.group] then
            local link = ""
            if type(GetItemLink) == "function" and item.bag ~= nil and item.slot ~= nil then
                link = tostring(first(GetItemLink, "", item.bag, item.slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
            end

            local setName, hasSet = setNameForLink(link)
            item._easSetDisplayName029652 = setName
            item._easSetName029652 = string.lower(setName)
            item._easHasSet029652 = hasSet

            if item.group == "ARMOR" then
                local equipType = 0
                if link ~= "" and type(GetItemLinkEquipType) == "function" then
                    equipType = tonumber(first(GetItemLinkEquipType, 0, link)) or 0
                end
                item._easArmorSlotOrder029652 = ARMOR_SLOT_ORDER[equipType] or 999
            end
        end
    end

    table.sort(items, function(a, b)
        local ac, bc = a and a._easCompanion029656 == true, b and b._easCompanion029656 == true
        if ac ~= bc then return not ac end

        local ao, bo = tonumber(a and a.order) or 90, tonumber(b and b.order) or 90
        if ao ~= bo then return ao < bo end

        local sameGearGroup = a and b and a.group == b.group and GEAR_GROUPS[a.group] == true
        if sameGearGroup then
            local ah, bh = a._easHasSet029652 == true, b._easHasSet029652 == true
            if ah ~= bh then return ah end

            if ah and bh then
                local aset = tostring(a._easSetName029652 or "")
                local bset = tostring(b._easSetName029652 or "")
                if aset ~= bset then return aset < bset end
            end

            if a.group == "ARMOR" then
                local as = tonumber(a._easArmorSlotOrder029652) or 999
                local bs = tonumber(b._easArmorSlotOrder029652) or 999
                if as ~= bs then return as < bs end
            end
        end

        local aq, bq = tonumber(a and a.quality) or 0, tonumber(b and b.quality) or 0
        if aq ~= bq then return aq > bq end
        return string.lower(tostring(a and a.name or "")) < string.lower(tostring(b and b.name or ""))
    end)

    return items
end

-- END ABSORBED: BankArmorSortFix.lua


-- Absorbed bank correction layers: architecture hardening batch B

-- BEGIN ABSORBED: BankItemClassificationFix.lua
-- ESO Adventurer Suite
-- v0.29.656 - bank jewelry set grouping + authoritative companion classification.
-- Jewelry recovery now preserves set metadata so rings/necklaces group under their
-- actual set headers. Companion classification is stamped after every upstream
-- sorter so companion gear cannot fall back into character Weapons/Armor/Jewelry.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U or type(U.Collect) ~= "function" then return end

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function same(value, ...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil and value == v then return true end
    end
    return false
end

local function activeInventory(mode)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" then return nil end
    local invType
    if mode == "DEPOSIT" then
        invType = rawget(_G, "INVENTORY_BACKPACK")
    elseif type(manager.GetBankInventoryType) == "function" then
        local ok, value = pcall(manager.GetBankInventoryType, manager)
        if ok then invType = value end
    end
    invType = invType or rawget(_G, "INVENTORY_BANK")
    return invType and manager.inventories[invType] or nil
end

local function activeFilter(mode)
    local inventory = activeInventory(mode)
    if type(inventory) == "table" and inventory.currentFilter ~= nil then
        return inventory.currentFilter
    end
    local cache = U._easBankTopFilter029542
    local manager = rawget(_G, "PLAYER_INVENTORY")
    local invType = mode == "DEPOSIT" and rawget(_G, "INVENTORY_BACKPACK") or rawget(_G, "INVENTORY_BANK")
    if type(manager) == "table" and mode ~= "DEPOSIT" and type(manager.GetBankInventoryType) == "function" then
        local ok, value = pcall(manager.GetBankInventoryType, manager)
        if ok and value ~= nil then invType = value end
    end
    return type(cache) == "table" and cache[invType] or nil
end

local function isJewelryFilter(filter)
    return same(filter,
        rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_JEWELRY"),
        rawget(_G, "ITEMFILTERTYPE_JEWELRY"),
        rawget(_G, "ITEMFILTERTYPE_JEWELRY_CRAFTING"))
end

local function searchText(mode)
    local names = mode == "WITHDRAW"
        and { "ZO_PlayerBankSearchFiltersTextSearchBox", "ZO_PlayerBankSearchFiltersTextSearch" }
        or { "ZO_PlayerInventorySearchFiltersTextSearchBox", "ZO_PlayerInventorySearchFiltersTextSearch" }
    for _, name in ipairs(names) do
        local control = rawget(_G, name)
        if control and type(control.GetText) == "function" then
            return string.lower(tostring(first(control.GetText, "", control) or ""))
        end
    end
    return ""
end

local function itemLink(bag, slot)
    return tostring(first(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
end

local function actorCategoryFor(bag, slot, link)
    if type(GetItemActorCategory) == "function" then
        local value = first(GetItemActorCategory, nil, bag, slot)
        if value ~= nil then return value end
    end
    local linkFn = rawget(_G, "GetItemLinkActorCategory")
    if type(linkFn) == "function" and tostring(link or "") ~= "" then
        local value = first(linkFn, nil, link)
        if value ~= nil then return value end
    end
    return nil
end

local function isCompanionItem(bag, slot, link)
    local companion = rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    if companion == nil then return false end
    return actorCategoryFor(bag, slot, link or itemLink(bag, slot)) == companion
end

local function setMetadata(link)
    if link == "" or type(GetItemLinkSetInfo) ~= "function" then return "", "", false end
    local ok, hasSet, setName = pcall(GetItemLinkSetInfo, link, false)
    if not ok or hasSet ~= true then return "", "", false end
    setName = tostring(setName or "")
    if setName == "" then return "", "", false end
    return string.lower(setName), setName, true
end

local function isJewelry(bag, slot)
    local link = itemLink(bag, slot)
    if link == "" then return false end
    local equip = tonumber(first(GetItemLinkEquipType, 0, link)) or 0
    return same(equip, rawget(_G, "EQUIP_TYPE_RING"), rawget(_G, "EQUIP_TYPE_NECK"))
end

local function buildItem(bag, slot)
    local link = itemLink(bag, slot)
    if link == "" then return nil end
    local name = tostring(first(GetItemName, "", bag, slot) or "")
    local icon, stack, _, _, locked, _, _, quality
    if type(GetItemInfo) == "function" then
        local ok
        ok, icon, stack, _, _, locked, _, _, quality = pcall(GetItemInfo, bag, slot)
        if not ok then icon, stack, locked, quality = nil, nil, false, nil end
    end
    stack = tonumber(stack) or tonumber(first(GetSlotStackSize, 1, bag, slot)) or 1
    quality = tonumber(quality) or tonumber(first(GetItemDisplayQuality, 0, bag, slot)) or 0

    local companion = isCompanionItem(bag, slot, link)
    local setKey, setDisplay, hasSet = setMetadata(link)
    if companion then
        setKey, setDisplay, hasSet = "", "", false
    end

    return {
        bag = bag,
        slot = slot,
        name = name,
        icon = tostring(icon or ""),
        stack = stack,
        quality = quality,
        locked = locked == true,
        group = companion and "COMPANION" or "JEWELRY",
        order = companion and 35 or 30,
        _easSetName029652 = setKey,
        _easSetDisplayName029652 = setDisplay,
        _easHasSet029652 = hasSet,
        _easCompanion029656 = companion,
    }
end

local function enforceAuthoritativeClassification(item)
    if type(item) ~= "table" or item.bag == nil or item.slot == nil then return end
    local link = itemLink(item.bag, item.slot)
    local companion = isCompanionItem(item.bag, item.slot, link)
    item._easCompanion029656 = companion

    if companion then
        item.group = "COMPANION"
        item.order = 35
        item._easHasSet029652 = false
        item._easSetName029652 = ""
        item._easSetDisplayName029652 = ""
        return
    end

    -- Preserve/repair player gear set metadata after all previous collectors have
    -- run. This is especially important for Jewelry rebuilt by the fallback path.
    if item.group == "WEAPONS" or item.group == "ARMOR" or item.group == "JEWELRY" then
        local setKey, setDisplay, hasSet = setMetadata(link)
        item._easSetName029652 = setKey
        item._easSetDisplayName029652 = setDisplay
        item._easHasSet029652 = hasSet
    end
end

local baseCollect = CollectImpl
CollectImpl = function(self, mode, ...)
    local items = baseCollect(self, mode, ...)
    if type(items) ~= "table" then items = {} end

    for _, item in ipairs(items) do
        enforceAuthoritativeClassification(item)
    end

    -- Jewelry recovery path. ESO can leave the hidden bank list empty when the
    -- top tab reports a descriptor rather than the display-category enum. Rebuild
    -- from source bags, but preserve complete set/actor metadata this time.
    if isJewelryFilter(activeFilter(mode)) then
        local bags = mode == "WITHDRAW"
            and { rawget(_G, "BAG_BANK"), rawget(_G, "BAG_SUBSCRIBER_BANK") }
            or { rawget(_G, "BAG_BACKPACK") }
        local search = searchText(mode)
        local rebuilt = {}
        for _, bag in ipairs(bags) do
            if bag ~= nil and type(GetBagSize) == "function" then
                local size = tonumber(first(GetBagSize, 0, bag)) or 0
                for slot = 0, size - 1 do
                    if isJewelry(bag, slot) then
                        local item = buildItem(bag, slot)
                        if item and (search == "" or string.find(string.lower(item.name), search, 1, true)) then
                            rebuilt[#rebuilt + 1] = item
                        end
                    end
                end
            end
        end
        return applyAuthoritativeGearSort(rebuilt)
    end

    return applyAuthoritativeGearSort(items)
end

U._easBankClassification029656 = true

-- END ABSORBED: BankItemClassificationFix.lua

-- BEGIN ABSORBED: BankContextMenuAndCompanionFix.lua
-- ESO Adventurer Suite
-- v0.29.659 - stable full bank right-click compatibility + authoritative companion filtering.
-- Bank grid cells remember the actual mouse-down button so ESO OnClicked calls
-- that omit the button argument cannot misinterpret a right-click as a transfer.

local EPC = ESOProgressionCoach
if not EPC then return end

local U = EPC.BankGridUnifiedV2
local Grid = rawget(_G, "EASInventoryGrid")
if not U then return end

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function same(value, ...)
    for i = 1, select("#", ...) do
        local candidate = select(i, ...)
        if candidate ~= nil and value == candidate then return true end
    end
    return false
end

local function itemLink(bag, slot)
    if type(GetItemLink) ~= "function" then return "" end
    return tostring(first(GetItemLink, "", bag, slot, rawget(_G, "LINK_STYLE_DEFAULT") or 0) or "")
end

local function itemTypeFor(bag, slot, link)
    local itemType = tonumber(first(GetItemType, nil, bag, slot))
    if itemType ~= nil then return itemType end
    if link ~= "" and type(GetItemLinkItemType) == "function" then
        return tonumber(first(GetItemLinkItemType, nil, link))
    end
    return nil
end

local function isCompanionItem(bag, slot, link)
    if bag == nil or slot == nil then return false end

    local companionActor = rawget(_G, "GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    if companionActor ~= nil and type(GetItemActorCategory) == "function" then
        local actor = first(GetItemActorCategory, nil, bag, slot)
        if actor == companionActor then return true end
    end

    link = link or itemLink(bag, slot)
    local itemType = itemTypeFor(bag, slot, link)
    if same(itemType,
        rawget(_G, "ITEMTYPE_COMPANION_ARMOR"),
        rawget(_G, "ITEMTYPE_COMPANION_WEAPON")) then
        return true
    end

    return false
end

local function activeInventory(mode)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" then return nil, nil end

    local invType
    if mode == "DEPOSIT" then
        invType = rawget(_G, "INVENTORY_BACKPACK")
    elseif type(manager.GetBankInventoryType) == "function" then
        local ok, value = pcall(manager.GetBankInventoryType, manager)
        if ok then invType = value end
    end
    invType = invType or rawget(_G, "INVENTORY_BANK")
    return invType and manager.inventories[invType] or nil, invType
end

local function activeFilter(mode)
    local inventory, invType = activeInventory(mode)
    if type(inventory) == "table" and inventory.currentFilter ~= nil then
        return inventory.currentFilter
    end
    local cache = U._easBankTopFilter029542
    return type(cache) == "table" and invType ~= nil and cache[invType] or nil
end

local function isCompanionFilter(filter)
    return same(filter,
        rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_COMPANION"),
        rawget(_G, "ITEM_TYPE_DISPLAY_CATEGORY_COMPANION_ITEMS"),
        rawget(_G, "ITEMFILTERTYPE_COMPANION"),
        rawget(_G, "ITEMFILTERTYPE_COMPANION_EQUIPMENT"),
        rawget(_G, "ITEMFILTERTYPE_COMPANION_ITEMS"))
end

local function searchText(mode)
    local names = mode == "WITHDRAW"
        and { "ZO_PlayerBankSearchFiltersTextSearchBox", "ZO_PlayerBankSearchFiltersTextSearch" }
        or { "ZO_PlayerInventorySearchFiltersTextSearchBox", "ZO_PlayerInventorySearchFiltersTextSearch" }
    for _, name in ipairs(names) do
        local control = rawget(_G, name)
        if control and type(control.GetText) == "function" then
            return string.lower(tostring(first(control.GetText, "", control) or ""))
        end
    end
    return ""
end

local function buildCompanionItem(bag, slot)
    local link = itemLink(bag, slot)
    if link == "" or not isCompanionItem(bag, slot, link) then return nil end

    local name = tostring(first(GetItemName, "", bag, slot) or "")
    local icon, stack, _, _, locked, _, _, quality
    if type(GetItemInfo) == "function" then
        local ok
        ok, icon, stack, _, _, locked, _, _, quality = pcall(GetItemInfo, bag, slot)
        if not ok then icon, stack, locked, quality = nil, nil, false, nil end
    end

    stack = tonumber(stack) or tonumber(first(GetSlotStackSize, 1, bag, slot)) or 1
    quality = tonumber(quality) or tonumber(first(GetItemDisplayQuality, 0, bag, slot)) or 0

    return {
        bag = bag,
        slot = slot,
        name = name,
        icon = tostring(icon or ""),
        stack = stack,
        quality = quality,
        locked = locked == true,
        group = "COMPANION",
        order = 35,
        _easCompanion029657 = true,
        _easHasSet029652 = false,
        _easSetName029652 = "",
        _easSetDisplayName029652 = "",
    }
end

if type(U.Collect) == "function" and not U._easCompanionAuthoritative029657 then
    U._easCompanionAuthoritative029657 = true
    local baseCollect = CollectImpl
    CollectImpl = function(self, mode, ...)
        if isCompanionFilter(activeFilter(mode)) then
            local bags = mode == "WITHDRAW"
                and { rawget(_G, "BAG_BANK"), rawget(_G, "BAG_SUBSCRIBER_BANK") }
                or { rawget(_G, "BAG_BACKPACK") }
            local search = searchText(mode)
            local rebuilt = {}
            for _, bag in ipairs(bags) do
                if bag ~= nil and type(GetBagSize) == "function" then
                    local size = tonumber(first(GetBagSize, 0, bag)) or 0
                    for slot = 0, math.max(0, size - 1) do
                        local item = buildCompanionItem(bag, slot)
                        if item and (search == "" or string.find(string.lower(item.name), search, 1, true)) then
                            rebuilt[#rebuilt + 1] = item
                        end
                    end
                end
            end
            table.sort(rebuilt, function(a, b)
                local aq, bq = tonumber(a.quality) or 0, tonumber(b.quality) or 0
                if aq ~= bq then return aq > bq end
                return string.lower(a.name or "") < string.lower(b.name or "")
            end)
            return rebuilt
        end

        local items = baseCollect(self, mode, ...)
        if type(items) ~= "table" then return items end
        for _, item in ipairs(items) do
            if item and item.bag ~= nil and item.slot ~= nil then
                local link = itemLink(item.bag, item.slot)
                if isCompanionItem(item.bag, item.slot, link) then
                    item.group = "COMPANION"
                    item.order = 35
                    item._easCompanion029657 = true
                    item._easHasSet029652 = false
                    item._easSetName029652 = ""
                    item._easSetDisplayName029652 = ""
                end
            end
        end
        return items
    end
end

-- ESO can invoke OnClicked without a mouse-button argument. Record the real
-- gesture on mouse-down so a right-click can never be mistaken for left-click.
if type(U.GetCell) == "function" and not U._easFullBankContextMenu029657 then
    U._easFullBankContextMenu029657 = true
    local baseGetCell = GetCellImpl
    GetCellImpl = function(self, index)
        local cell = baseGetCell(self, index)
        if cell and not cell._easFullContextMenu029657 and type(cell.SetHandler) == "function" then
            cell._easFullContextMenu029657 = true

            cell:SetHandler("OnMouseDown", function(control, button)
                control._easBankGestureButton029659 = button
            end)

            cell:SetHandler("OnClicked", function(control, button)
                local left = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
                local gesture = control._easBankGestureButton029659
                if button ~= nil then gesture = button end
                if left == nil or gesture ~= left then return end
                if control.item then self:Move(control.item) end
            end)

            cell:SetHandler("OnMouseUp", function(control, button, upInside)
                local right = rawget(_G, "MOUSE_BUTTON_INDEX_RIGHT")
                if upInside == false or button ~= right then
                    if type(zo_callLater) == "function" then
                        zo_callLater(function()
                            if control then control._easBankGestureButton029659 = nil end
                        end, 0)
                    end
                    return
                end

                local item = control.item
                if not item or item.bag == nil or item.slot == nil then return end

                control.bagId = item.bag
                control.slotIndex = item.slot
                control.slotType = rawget(_G, "SLOT_TYPE_ITEM")

                local grid = rawget(_G, "EASInventoryGrid") or Grid
                if type(grid) == "table" and type(grid.ShowCompatibleItemMenu) == "function" then
                    grid:ShowCompatibleItemMenu(control)
                elseif type(ZO_InventorySlot_ShowContextMenu) == "function" then
                    pcall(ZO_InventorySlot_ShowContextMenu, control)
                end

                local enchantPlus = rawget(_G, "EASEnchantPlus")
                if type(enchantPlus) == "table" and type(enchantPlus.SuppressNativeEnchantEntry) == "function" then
                    pcall(enchantPlus.SuppressNativeEnchantEntry)
                    if type(zo_callLater) == "function" then
                        zo_callLater(function()
                            pcall(enchantPlus.SuppressNativeEnchantEntry)
                        end, 0)
                    end
                end

                -- Clear only after ESO has had a chance to dispatch OnClicked.
                if type(zo_callLater) == "function" then
                    zo_callLater(function()
                        if control then control._easBankGestureButton029659 = nil end
                    end, 25)
                end
            end)
        end
        return cell
    end
end

EPC.bankContextMenuAndCompanionFix029657 = true

-- END ABSORBED: BankContextMenuAndCompanionFix.lua

-- BEGIN ABSORBED: BankMenuRefreshGuardFix.lua
-- ESO Adventurer Suite
-- v0.29.660 - keep bank context menus open while the bank's 150 ms refresh loop runs.
-- BankGridUnifiedV2 refreshes continuously. Re-rendering the Suite bank while
-- ZO_Menu/LibCustomMenu is open causes the menu to disappear almost immediately.

local EPC = ESOProgressionCoach
if not EPC then return end
local U = EPC.BankGridUnifiedV2
if not U or type(U.Refresh) ~= "function" or U._easMenuRefreshGuard029660 then return end
U._easMenuRefreshGuard029660 = true

local function isVisible(control)
    if not control then return false end
    if type(control.IsHidden) == "function" then
        local ok, hidden = pcall(control.IsHidden, control)
        if ok then return hidden == false end
    end
    return false
end

local function contextMenuOpen()
    if isVisible(rawget(_G, "ZO_Menu")) then return true end
    if isVisible(rawget(_G, "LibCustomMenuSubmenu")) then return true end
    return false
end

-- Refresh policy is enforced by the final authoritative U:Refresh below.\n\nEPC.bankMenuRefreshGuard029660 = true

-- END ABSORBED: BankMenuRefreshGuardFix.lua

-- BEGIN ABSORBED: BankPresentationCleanupFix.lua
-- ESO Adventurer Suite
-- v0.29.661 - bank presentation cleanup.
-- Keep the Suite bank grid/categories/interactions, but remove the full dark
-- panel backdrop and the Suite WITHDRAW/DEPOSIT title requested by the user.

local EPC = ESOProgressionCoach
if not EPC then return end

local U = EPC.BankGridUnifiedV2
if not U then return end

local function cleanup(self)
    if not self then return end

    if self.bg then
        if type(self.bg.SetHidden) == "function" then self.bg:SetHidden(true) end
        if type(self.bg.SetMouseEnabled) == "function" then self.bg:SetMouseEnabled(false) end
    end

    if self.title then
        if type(self.title.SetText) == "function" then self.title:SetText("") end
        if type(self.title.SetHidden) == "function" then self.title:SetHidden(true) end
        if type(self.title.SetMouseEnabled) == "function" then self.title:SetMouseEnabled(false) end
    end
end

cleanup(U)
EPC.bankPresentationCleanupFix029661 = true

-- END ABSORBED: BankPresentationCleanupFix.lua

-- BEGIN ABSORBED: BankContextMenuSecureTransferFix.lua
-- ESO Adventurer Suite
-- v0.29.664 - replace insecure native bank context-menu transfer callbacks.
-- Detect the native TryBankItem closures by callback source as well as label so
-- localization/string changes cannot leave PickupInventoryItem attached.

local EPC = ESOProgressionCoach
local Grid = rawget(_G, "EASInventoryGrid")
if not EPC or type(Grid) ~= "table" or type(Grid.ShowCompatibleItemMenu) ~= "function" then return end
if Grid._easSecureBankContextTransfer029664 then return end
Grid._easSecureBankContextTransfer029664 = true

local function textFor(idName, fallback)
    local id = rawget(_G, idName)
    if id ~= nil and type(GetString) == "function" then
        local ok, value = pcall(GetString, id)
        if ok and tostring(value or "") ~= "" then return tostring(value) end
    end
    return fallback
end

local function normalizeText(value)
    local text = tostring(value or "")
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return string.lower(text)
end

local function isBankBag(bag)
    return bag == rawget(_G, "BAG_BANK") or bag == rawget(_G, "BAG_SUBSCRIBER_BANK")
end

local function findEmpty(bags)
    for _, bag in ipairs(bags) do
        if bag ~= nil and type(FindFirstEmptySlotInBag) == "function" then
            local ok, slot = pcall(FindFirstEmptySlotInBag, bag)
            if ok and slot ~= nil then return bag, slot end
        end
    end
end

local function secureTransfer(bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if bag == nil or slot == nil then return false end

    local targets
    if isBankBag(bag) then
        targets = { rawget(_G, "BAG_BACKPACK") }
    elseif bag == rawget(_G, "BAG_BACKPACK") then
        targets = { rawget(_G, "BAG_BANK"), rawget(_G, "BAG_SUBSCRIBER_BANK") }
    else
        return false
    end

    local destBag, destSlot = findEmpty(targets)
    if destBag == nil then return false end

    local count = 1
    if type(GetSlotStackSize) == "function" then
        local ok, value = pcall(GetSlotStackSize, bag, slot)
        if ok and tonumber(value) then count = tonumber(value) end
    end

    if type(IsProtectedFunction) == "function" then
        local ok, protected = pcall(IsProtectedFunction, "RequestMoveItem")
        if ok and protected == true and type(CallSecureProtected) == "function" then
            return pcall(CallSecureProtected, "RequestMoveItem", bag, slot, destBag, destSlot, count)
        end
    end
    if type(RequestMoveItem) == "function" then
        return pcall(RequestMoveItem, bag, slot, destBag, destSlot, count)
    end
    return false
end

local bankLabels = {}
local function addLabel(idName, fallback)
    bankLabels[normalizeText(textFor(idName, fallback))] = true
end
addLabel("SI_ITEM_ACTION_BANK_DEPOSIT", "Deposit")
addLabel("SI_ITEM_ACTION_BANK_WITHDRAW", "Withdraw")
addLabel("SI_ITEM_ACTION_BANK_DEPOSIT_ALL", "Deposit All")
addLabel("SI_ITEM_ACTION_BANK_WITHDRAW_ALL", "Withdraw All")

local function isNativeBankCallback(callback)
    if type(callback) ~= "function" or type(debug) ~= "table" or type(debug.getinfo) ~= "function" then return false end
    local ok, info = pcall(debug.getinfo, callback, "S")
    if not ok or type(info) ~= "table" then return false end

    local source = string.lower(tostring(info.source or info.short_src or ""))
    if not string.find(source, "inventoryslot.lua", 1, true) then return false end

    -- Current ESO API places bank_deposit/bank_withdraw closures around these
    -- lines. Keep a narrow compatibility window for line movement between minor
    -- API patches while avoiding unrelated inventory actions.
    local line = tonumber(info.linedefined) or 0
    if line >= 1690 and line <= 1760 then return true end

    return false
end

local base = Grid.ShowCompatibleItemMenu
function Grid:ShowCompatibleItemMenu(control, ...)
    local result = base(self, control, ...)
    local bag, slot = tonumber(control and control.bagId), tonumber(control and control.slotIndex)
    if bag == nil or slot == nil then return result end
    if not isBankBag(bag) and bag ~= rawget(_G, "BAG_BACKPACK") then return result end

    local menu = rawget(_G, "ZO_Menu")
    if menu and type(menu.items) == "table" then
        for _, entry in ipairs(menu.items) do
            local item = entry and entry.item
            if item then
                local label = item.nameLabel and type(item.nameLabel.GetText) == "function" and normalizeText(item.nameLabel:GetText()) or ""
                local callback = item.OnSelect
                local shouldReplace = bankLabels[label] == true or isNativeBankCallback(callback)

                if shouldReplace then
                    item.OnSelect = function()
                        secureTransfer(bag, slot)
                    end
                end
            end
        end
    end
    return result
end

EPC.bankContextMenuSecureTransferFix029664 = true

-- END ABSORBED: BankContextMenuSecureTransferFix.lua

-- BEGIN ABSORBED: BankLockIndicatorFix.lua
-- ESO Adventurer Suite
-- v0.29.663 - bank lock indicator visibility.
-- Adds ESO's lock icon to Suite bank cells and drives visibility from the live
-- IsItemPlayerLocked(bag, slot) state so lock/unlock changes are visible.

local EPC = ESOProgressionCoach
if not EPC or not WINDOW_MANAGER then return end

local U = EPC.BankGridUnifiedV2
if not U then return end

local wm = WINDOW_MANAGER
local LOCK_ICON_TEXTURE = (type(rawget(_G, "ZO_KEYBOARD_LOCKED_ICON")) == "string" and rawget(_G, "ZO_KEYBOARD_LOCKED_ICON")) or "EsoUI/Art/Miscellaneous/status_locked.dds"

local function liveLocked(item)
    if not item or item.bag == nil or item.slot == nil then return false end
    if type(IsItemPlayerLocked) == "function" then
        local ok, value = pcall(IsItemPlayerLocked, item.bag, item.slot)
        if ok then return value == true end
    end
    return item.locked == true
end

local function ensureLockIcon(cell)
    if not cell then return nil end
    if cell._easBankLockIcon029663 then return cell._easBankLockIcon029663 end

    local icon = wm:CreateControl(nil, cell, CT_TEXTURE)
    icon:SetDimensions(16, 16)
    icon:SetAnchor(TOPLEFT, cell, TOPLEFT, 2, 2)
    icon:SetTexture(LOCK_ICON_TEXTURE)
    icon:SetColor(1, 1, 1, 1)
    if type(icon.SetDrawTier) == "function" and rawget(_G, "DT_HIGH") ~= nil then icon:SetDrawTier(DT_HIGH) end
    if type(icon.SetDrawLayer) == "function" and rawget(_G, "DL_OVERLAY") ~= nil then icon:SetDrawLayer(DL_OVERLAY) end
    if type(icon.SetDrawLevel) == "function" then icon:SetDrawLevel(980) end
    icon:SetMouseEnabled(false)
    icon:SetHidden(true)

    cell._easBankLockIcon029663 = icon
    cell.lockIcon = icon
    return icon
end

if type(U.GetCell) == "function" and not U._easBankLockCells029663 then
    U._easBankLockCells029663 = true
    local baseGetCell = GetCellImpl
    GetCellImpl = function(self, index)
        local cell = baseGetCell(self, index)
        ensureLockIcon(cell)
        return cell
    end
end

if type(U.Render) == "function" and not U._easBankLockRender029663 then
    U._easBankLockRender029663 = true
    local baseRender = RenderImpl
    RenderImpl = function(self, info, ...)
        local shown = baseRender(self, info, ...)
        for _, cell in ipairs(self.cells or {}) do
            if cell then
                local icon = ensureLockIcon(cell)
                local item = cell.item
                local hidden = true
                if item and type(cell.IsHidden) == "function" and cell:IsHidden() == false then
                    local locked = liveLocked(item)
                    item.locked = locked
                    hidden = not locked
                end
                if icon then icon:SetHidden(hidden) end
            end
        end
        return shown
    end
end

EPC.bankLockIndicatorFix029663 = true

-- END ABSORBED: BankLockIndicatorFix.lua


-- BEGIN ABSORBED: GuildBankNativeSafetyFix.lua
-- ESO Adventurer Suite
-- v0.29.618 - specialized storage ownership boundary.
-- Personal Bank keeps the Suite bank grid. Guild Bank keeps ESO's native
-- presentation. House Storage and Furnishing Vault are reserved exclusively for
-- their dedicated Suite renderers and must never be restored/rendered here.

local EPC = ESOProgressionCoach
if not EPC or not EPC.BankGridUnifiedV2 then return end

local U = EPC.BankGridUnifiedV2

local function first(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function isShown(control)
    if not control or type(control.IsHidden) ~= "function" then return false end
    return first(control.IsHidden, true, control) == false
end

local function inventoryList(invType)
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" or type(manager.inventories) ~= "table" or invType == nil then return nil end
    local data = manager.inventories[invType]
    if type(data) ~= "table" then return nil end
    for _, key in ipairs({ "list", "listView", "scrollList" }) do
        local control = data[key]
        if control then return control end
    end
    return nil
end

local function furnishingVaultVisible029583()
    if isShown(rawget(_G, "ZO_FurnitureVaultTabs"))
        or isShown(rawget(_G, "ZO_FurnitureVaultSearchFilters"))
        or isShown(rawget(_G, "ZO_FurnitureVaultSearchFiltersTextSearchBox"))
        or isShown(rawget(_G, "ZO_FurnitureVaultInfoBar"))
        or isShown(rawget(_G, "ZO_FurnitureVaultList")) then
        return true
    end

    local function fragmentShown(fragment)
        if not fragment then return false end
        if type(fragment.IsShowing) == "function" then
            local ok, shown = pcall(fragment.IsShowing, fragment)
            if ok and shown == true then return true end
        end
        if type(fragment.GetState) == "function" then
            local ok, state = pcall(fragment.GetState, fragment)
            if ok then
                return state == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                    or state == rawget(_G, "SCENE_FRAGMENT_SHOWN")
            end
        end
        return false
    end

    if fragmentShown(rawget(_G, "BACKPACK_FURNITURE_VAULT_LAYOUT_FRAGMENT")) then return true end
    if fragmentShown(rawget(_G, "FURNITURE_VAULT_FRAGMENT")) then return true end

    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) == "table" and type(manager.inventories) == "table" then
        for _, inventoryType in ipairs({ rawget(_G, "INVENTORY_BACKPACK"), rawget(_G, "INVENTORY_FURNITURE_VAULT") }) do
            local data = inventoryType ~= nil and manager.inventories[inventoryType] or nil
            if type(data) == "table" and tostring(data.currentContext or "") == "furnitureVaultTextSearch" then
                return true
            end
        end
    end

    local sm = rawget(_G, "SCENE_MANAGER")
    if sm and type(sm.IsShowing) == "function" then
        local ok, shown = pcall(sm.IsShowing, sm, "furnitureVault")
        if ok and shown == true then return true end
    end
    return false
end

local function houseStorageActive029608()
    local function fragmentShown(fragment)
        if not fragment then return false end
        if type(fragment.IsShowing) == "function" then
            local ok, shown = pcall(fragment.IsShowing, fragment)
            if ok and shown == true then return true end
        end
        if type(fragment.GetState) == "function" then
            local ok, state = pcall(fragment.GetState, fragment)
            if ok then
                return state == rawget(_G, "SCENE_FRAGMENT_SHOWING")
                    or state == rawget(_G, "SCENE_FRAGMENT_SHOWN")
            end
        end
        return false
    end

    if fragmentShown(rawget(_G, "BACKPACK_HOUSE_BANK_LAYOUT_FRAGMENT")) then return true end
    if fragmentShown(rawget(_G, "HOUSE_BANK_FRAGMENT")) then return true end
    if fragmentShown(rawget(_G, "HOUSE_BANK_MENU_FRAGMENT")) then return true end

    local sm = rawget(_G, "SCENE_MANAGER")
    if sm and type(sm.IsShowing) == "function" then
        local ok, shown = pcall(sm.IsShowing, sm, "houseBank")
        if ok and shown == true then return true end
    end
    return false
end

local function activeSpecialInventoryType()
    local manager = rawget(_G, "PLAYER_INVENTORY")
    if type(manager) ~= "table" then return nil end

    local GUILD = rawget(_G, "INVENTORY_GUILD_BANK")
    local HOUSE = rawget(_G, "INVENTORY_HOUSE_BANK")
    local FURNITURE = rawget(_G, "INVENTORY_FURNITURE_VAULT")

    -- Dedicated Suite storage renderers are detected before selectedTabType because
    -- their Deposit sides use INVENTORY_BACKPACK while the special scene is live.
    if HOUSE ~= nil and houseStorageActive029608() then return HOUSE end
    if FURNITURE ~= nil and furnishingVaultVisible029583() then return FURNITURE end

    if type(manager.IsGuildBanking) == "function" and first(manager.IsGuildBanking, false, manager) == true then
        return GUILD
    end

    local selected = tonumber(manager.selectedTabType)
    if selected ~= nil and (selected == GUILD or selected == HOUSE) then
        return selected
    end

    if type(manager.GetBankInventoryType) == "function" then
        local bankType = tonumber(first(manager.GetBankInventoryType, nil, manager))
        if bankType ~= nil and (bankType == GUILD or bankType == HOUSE) then
            return bankType
        end
    end

    local houseList = inventoryList(HOUSE) or rawget(_G, "ZO_HouseBankBackpack")
    if HOUSE ~= nil and isShown(houseList) and houseStorageActive029608() then return HOUSE end

    return nil
end

local function restore(control)
    if not control then return end
    if type(control.SetAlpha) == "function" then pcall(control.SetAlpha, control, 1) end
    if type(control.SetMouseEnabled) == "function" then pcall(control.SetMouseEnabled, control, true) end
end

local function hideGenericBankGrid()
    if U.root and type(U.root.SetHidden) == "function" then
        pcall(U.root.SetHidden, U.root, true)
    end
    U._suiteBankActive029539 = false
end

local function reserveHouseStorage()
    -- Do not restore or suppress House Storage controls here. Its dedicated
    -- renderer needs the live native data list and owns native-row suppression.
    hideGenericBankGrid()
    U.specialStorageNative029558 = rawget(_G, "INVENTORY_HOUSE_BANK")
end

local function reserveFurnishingVault()
    -- Same ownership rule as House Storage: only disable the generic bank overlay.
    -- FurnishingVaultPureNativeFix.lua owns row suppression, grid layout and input.
    hideGenericBankGrid()
    U.specialStorageNative029558 = rawget(_G, "INVENTORY_FURNITURE_VAULT")
    U.furnishingVaultSuiteExclusive029617 = true
    U.furnishingVaultSuiteGrid029577 = false
    U.furnishingVaultDeposit029576 = false
end

local function restoreSpecialInventory(invType)
    restore(inventoryList(invType))
    restore(inventoryList(rawget(_G, "INVENTORY_BACKPACK")))
    restore(rawget(_G, "ZO_PlayerInventoryList"))

    if invType == rawget(_G, "INVENTORY_GUILD_BANK") then
        restore(rawget(_G, "ZO_GuildBankBackpack"))
    end

    hideGenericBankGrid()
    U.specialStorageNative029558 = invType
end

local BaseRefresh029558 = RefreshImpl
RefreshImpl = function(self, ...)
    if contextMenuOpen() then return end
    local specialType = activeSpecialInventoryType()
    if specialType == rawget(_G, "INVENTORY_HOUSE_BANK") then
        reserveHouseStorage()
        return
    end
    if specialType == rawget(_G, "INVENTORY_FURNITURE_VAULT") then
        reserveFurnishingVault()
        return
    end
    if specialType ~= nil then
        restoreSpecialInventory(specialType)
        return
    end
    self.specialStorageNative029558 = nil
    self.furnishingVaultSuiteExclusive029617 = false
    local result
    if type(BaseRefresh029558) == "function" then
        result = BaseRefresh029558(self, ...)
    end
    cleanup(self)
    return result
end

local BaseCollect029558 = CollectImpl
CollectImpl = function(self, mode, ...)
    local specialType = activeSpecialInventoryType()
    if specialType == rawget(_G, "INVENTORY_HOUSE_BANK") then
        reserveHouseStorage()
        return {}
    end
    if specialType == rawget(_G, "INVENTORY_FURNITURE_VAULT") then
        reserveFurnishingVault()
        return {}
    end
    if specialType ~= nil then
        restoreSpecialInventory(specialType)
        return {}
    end
    if type(BaseCollect029558) == "function" then
        return BaseCollect029558(self, mode, ...)
    end
    return {}
end

local BaseMove029558 = MoveImpl
MoveImpl = function(self, item, ...)
    local specialType = activeSpecialInventoryType()
    if specialType == rawget(_G, "INVENTORY_HOUSE_BANK") then
        reserveHouseStorage()
        return
    end
    if specialType == rawget(_G, "INVENTORY_FURNITURE_VAULT") then
        reserveFurnishingVault()
        return
    end
    if specialType ~= nil then
        restoreSpecialInventory(specialType)
        return
    end
    if type(BaseMove029558) == "function" then
        return BaseMove029558(self, item, ...)
    end
end

if EVENT_MANAGER then
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_SpecialStorageNative029618"
    local pending = false
    local function scheduleRefresh()
        if pending then return end
        pending = true
        local function run()
            pending = false
            if U and U.Refresh then U:Refresh() end
        end
        if type(zo_callLater) == "function" then zo_callLater(run, 0) else run() end
    end

    for _, eventName in ipairs({
        "EVENT_OPEN_GUILD_BANK",
        "EVENT_CLOSE_GUILD_BANK",
        "EVENT_OPEN_BANK",
        "EVENT_CLOSE_BANK",
        "EVENT_INVENTORY_FULL_UPDATE",
        "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
    }) do
        local eventCode = rawget(_G, eventName)
        if eventCode ~= nil then
            EVENT_MANAGER:RegisterForEvent(prefix .. "_" .. eventName, eventCode, scheduleRefresh)
        end
    end
end

-- END ABSORBED: GuildBankNativeSafetyFix.lua
