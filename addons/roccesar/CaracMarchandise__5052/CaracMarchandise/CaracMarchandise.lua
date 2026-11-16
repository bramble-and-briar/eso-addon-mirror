--------------------------------------------------------------------------
-- CaracMarchandise
-- - choix de la quantité à vendre 
-- - calcul automatique du total (quantite x prix unitaire)
-- - mémorisation du dernier prix unitaire par objet
-- - si prix mémorisé, celui s'affiche dans la fenêtre de vente
-- - si Addon Tamriel Trade Center installé, affiche la moyenne des ventes
-- Aucune librairie requise.
--------------------------------------------------------------------------

-- ===== COULEURS MODIFIABLES (r, g, b) entre 0 et 1 =====
local TITLE_COLOR  = { 1.0, 0.85, 0.1 }     -- titre "CaracMarchandise" (jaune)
local TOTAL_COLOR  = { 0.0, 1.0, 1.0 }      -- total (cyan)
local BORDER_COLOR = { 0.77, 0.76, 0.62 }   -- cadre (couleur des menus ESO)
-- =======================================================

local FONT       = "ZoFontGameBold"
local FONT_TITLE = "ZoFontWinH2"
local FONT_LIGHT = "ZoFontGame"   -- police non grasse (moyenne des ventes et total)
local GOLD_ICON  = zo_iconFormat("EsoUI/Art/currency/currency_gold.dds", 18, 18)
local MAX_STACK  = 200
local MAX_TOTAL  = 2147483647   -- limite du jeu pour le prix (entier 32 bits)
local AVG_COLOR    = { 1.0, 1.0, 1.0 }      -- moyenne des ventes TTC (blanc)

local CM = {}
CM.name = "CaracMarchandise"

local ui = {}
local current = nil      -- { bag, slot, key, max }
local ignoreUntil = 0    -- ignore les événements "objet en attente" générés par l'addon
local split = nil        -- { slot, qty, total } : division de stack en cours

local function Now() return GetGameTimeMilliseconds() end

---------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------

-- Formate un grand nombre avec des espaces (sans passer par un entier 32 bits)
local function FormatNumber(n)
    local s = string.format("%.0f", n)
    local sign, digits = s:match("^(%-?)(%d+)$")
    if not digits then return s end
    digits = digits:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    return sign .. (digits:gsub("^ ", ""))
end

-- Clé "objet similaire" : meme id, meme qualite, meme niveau
local function MakeKey(bag, slot)
    local link = GetItemLink(bag, slot)
    if not link or link == "" then return nil end
    local id      = GetItemLinkItemId(link)
    local quality = GetItemLinkQuality(link)
    local level   = GetItemLinkRequiredLevel(link) + GetItemLinkRequiredChampionPoints(link)
    return id .. ":" .. quality .. ":" .. level
end

local function MaxQty()
    if current and current.max then return current.max end
    return MAX_STACK
end

-- Formate un nombre avec ses decimales (ex : 1 234,56)
local DECIMALS = 2     -- nombre de decimales affichees
local DEC_SEP  = ","   -- separateur decimal ("," ou ".")

local function FormatDecimal(n)
    local s = string.format("%." .. DECIMALS .. "f", n)
    local int, frac = s:match("^(%d+)%.?(%d*)$")
    if not int then return s end
    local text = FormatNumber(tonumber(int))
    if frac ~= "" then text = text .. DEC_SEP .. frac end
    return text
end

-- Moyenne des ventes par unité fournie par Tamriel Trade Centre (si disponible)
local function UpdateAverage()
    if not ui.avg then return end
    local value = GetString(CARACMARCHANDISE_AVG_UNKNOWN)
    if current and TamrielTradeCentrePrice and TamrielTradeCentrePrice.GetPriceInfo then
        local link = GetItemLink(current.bag, current.slot)
        local ok, info = pcall(TamrielTradeCentrePrice.GetPriceInfo, TamrielTradeCentrePrice, link)
        if ok and info and info.SaleAvg and info.SaleAvg > 0 then
            value = FormatDecimal(info.SaleAvg) .. " " .. GOLD_ICON
        end
    end
    ui.avg:SetText(GetString(CARACMARCHANDISE_AVG_LABEL) .. value .. "\n" .. GetString(CARACMARCHANDISE_AVG_SOURCE))
end

local function ReadQty()
    local q = math.floor(tonumber(ui.qty:GetText()) or 1)
    if q > MaxQty() then q = MaxQty() end
    if q < 1 then q = 1 end
    return q
end

local function ReadUnit()
    return math.floor(tonumber(ui.unit:GetText()) or 0)
end

-- Le bouton n'est cliquable que si la quantité saisie correspond au stack
local function UpdateButton()
    if not ui.btn then return end
    local ok = false
    if current then
        local stack = GetSlotStackSize(current.bag, current.slot)
        local q = tonumber(ui.qty:GetText())
        ok = q ~= nil and q >= 1 and q <= stack and ReadUnit() > 0
             and ReadQty() * ReadUnit() <= MAX_TOTAL and not split
    end
    ui.btn:SetEnabled(ok)
end

local function UpdateTotal()
    UpdateButton()
    if not current then
        ui.total:SetText(GetString(CARACMARCHANDISE_TOTAL) .. "-")
        return
    end
    local total = ReadQty() * ReadUnit()
    if total > MAX_TOTAL then
        ui.total:SetText(GetString(CARACMARCHANDISE_TOTAL) .. "|cFF0000" .. GetString(CARACMARCHANDISE_OUT_OF_LIMIT) .. "|r")
    else
        ui.total:SetText(GetString(CARACMARCHANDISE_TOTAL) .. FormatNumber(total) .. " " .. GOLD_ICON)
    end
end

-- Empêche de saisir une quantité superieure au stack
local function ClampQtyField()
    local q = tonumber(ui.qty:GetText())
    if q and q > MaxQty() then
        ui.qty:SetText(tostring(MaxQty()))
    end
    UpdateTotal()
end

-- Centre l'ensemble icône + nom dans la fenêtre (largeur 320)
local function CenterItem(avecIcone)
    local largeurNom = math.min(ui.name:GetTextWidth(), 240)
    local total = avecIcone and (44 + 10 + largeurNom) or largeurNom
    local x = math.floor((320 - total) / 2)

    ui.icon:ClearAnchors()
    ui.name:ClearAnchors()
    if avecIcone then
        ui.icon:SetAnchor(TOPLEFT, ui.win, TOPLEFT, x, 46)
        ui.name:SetAnchor(LEFT, ui.icon, RIGHT, 10, 0)
    else
        ui.icon:SetAnchor(TOPLEFT, ui.win, TOPLEFT, 14, 46)
        ui.name:SetAnchor(LEFT, ui.win, TOPLEFT, x, 68)
    end
end

-- Affiche icone + quantité disponible + nom
local function ShowItem(bag, slot)
    local icon, stack = GetItemInfo(bag, slot)
    local link = GetItemLink(bag, slot)
    local quality = GetItemLinkQuality(link)
    local name = zo_strformat("<<C:1>>", GetItemLinkName(link))
    ui.icon:SetTexture(icon)
    ui.icon:SetHidden(false)
    ui.iconCount:SetText(tostring(stack))
    ui.name:SetText(GetItemQualityColor(quality):Colorize(name))
    CenterItem(true)
end

local function ClearItem()
    current = nil
    UpdateAverage()
    ui.icon:SetHidden(true)
    ui.iconCount:SetText("")
    ui.name:SetText(GetString(CARACMARCHANDISE_NO_ITEM))
    CenterItem(false) 
    ui.qty:SetText("")
    ui.unit:SetText("")
    ui.total:SetText(GetString(CARACMARCHANDISE_TOTAL) .. "-")
    UpdateButton()    
end

---------------------------------------------------------------
-- Definir le prix de la mise en vente (plusieurs méthodes testées)
---------------------------------------------------------------

local function SetPrice(total)
    local th = TRADING_HOUSE
    if th and th.SetPendingPostPrice then
        if pcall(th.SetPendingPostPrice, th, total) then return true end
    end
    if SetPendingPostPrice then
        if pcall(SetPendingPostPrice, total) then return true end
    end
    -- dernier recours : ecrire dans le champ de prix natif
    local c = ZO_TradingHousePostItemPaneFormInvoiceSellPriceAmount
    if c and c.SetText then
        c:SetText(tostring(total))
        local h = c.GetHandler and c:GetHandler("OnTextChanged")
        if h then pcall(h, c) end
        return true
    end
    return false
end

---------------------------------------------------------------
-- Appliquer quantité + prix (séparation du stack impossible)
---------------------------------------------------------------

-- Appelle une fonction protégée du jeu si nécessaire
local function Secure(name, ...)
    if IsProtectedFunction(name) then
        return CallSecureProtected(name, ...)
    end
    return _G[name](...)
end

local OnInventorySlotUpdate   -- définie plus bas
local SPLIT_EVENT = CM.name .. "_Split"

local function StopSplitWatch()
    EVENT_MANAGER:UnregisterForEvent(SPLIT_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function StartSplitWatch()
    EVENT_MANAGER:RegisterForEvent(SPLIT_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(SPLIT_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:AddFilterForEvent(SPLIT_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
end

-- Met un stack complet en vente et applique le prix
local function PostStack(bag, slot, qty, total)
    ignoreUntil = Now() + 1500
    SetPendingItemPost(bag, slot, qty)
    zo_callLater(function()
        if not current or current.bag ~= bag or current.slot ~= slot then return end
        SetPrice(total)
        UpdateTotal()
    end, 250)
end

local function Apply()
    if not current or split then return end
    local bag, slot = current.bag, current.slot
    local stack = GetSlotStackSize(bag, slot)
    local qty   = ReadQty()
    local unit  = ReadUnit()
    local total = qty * unit
    if unit <= 0 or total > MAX_TOTAL or qty > stack then return end

    -- stack entier : comportement habituel
    if qty == stack then
        PostStack(bag, slot, stack, total)
        return
    end

    -- stack partiel : on divise d'abord vers un emplacement libre
    local free = FindFirstEmptySlotInBag(BAG_BACKPACK)
    if not free then
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(CARACMARCHANDISE_NO_FREE_SLOT))
        return
    end
    local mine = { slot = free, qty = qty, total = total }
    split = mine
    StartSplitWatch()
    UpdateButton()
    Secure("RequestMoveItem", bag, slot, BAG_BACKPACK, free, qty)

    -- sécurité : si le jeu ne confirme pas, on débloque
    zo_callLater(function()
        if split == mine then
            split = nil
            StopSplitWatch()
            UpdateButton()
            ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, GetString(CARACMARCHANDISE_SPLIT_FAILED))
        end
    end, 3000)
end

-- Le nouveau stack est apparu : on le met en vente
OnInventorySlotUpdate = function(_, bag, slot)
    if not split or bag ~= BAG_BACKPACK or slot ~= split.slot then return end
    if GetSlotStackSize(bag, slot) ~= split.qty then return end
    local s = split
    split = nil
    StopSplitWatch()
    current = { bag = bag, slot = slot, key = MakeKey(bag, slot), max = s.qty }
    ShowItem(bag, slot)
    UpdateButton()
    PostStack(bag, slot, s.qty, s.total)
end

---------------------------------------------------------------
-- Un objet est (de)sélectionné dans l'onglet "Vendre"
---------------------------------------------------------------

local function Refresh()
    local bag, slot, count = GetPendingItemPost()
    if not count or count <= 0 or not bag or not slot then
        ClearItem()
        return
    end

    local key = MakeKey(bag, slot)
    current = { bag = bag, slot = slot, key = key, max = GetSlotStackSize(bag, slot) }
    ShowItem(bag, slot)
    UpdateAverage()
    ui.qty:SetText(tostring(count))

    local saved = key and CM.sv.prix[key]
    if saved then
        ui.unit:SetText(tostring(saved))
        Apply()
    else
        ui.unit:SetText("")
        UpdateTotal()
    end
end

local function OnPendingItemUpdate()
    if split then return end
    if Now() < ignoreUntil then
        local bag, slot = GetPendingItemPost()
        if current and bag == current.bag and slot == current.slot then return end
    end
    Refresh()
end

---------------------------------------------------------------
-- Enregistrement du prix unitaire au moment de la mise en vente
---------------------------------------------------------------

local function OnRequestPost(bag, slot, qty, price)
    if not ui.win or ui.win:IsHidden() then return end
    if qty and qty > 0 and price and price > 0 then
        local key = MakeKey(bag, slot)
        if key then CM.sv.prix[key] = math.floor(price / qty) end
    end
end

local function OnCloseTradingHouse()
    ui.win:SetHidden(true)
    split = nil
    StopSplitWatch()
    EVENT_MANAGER:UnregisterForEvent(CM.name .. "_Close", EVENT_CLOSE_TRADING_HOUSE)
    EVENT_MANAGER:UnregisterForEvent(CM.name .. "_Pending", EVENT_TRADING_HOUSE_PENDING_ITEM_UPDATE)
end

local function OnOpenTradingHouse()
    ui.win:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(CM.name .. "_Close", EVENT_CLOSE_TRADING_HOUSE, OnCloseTradingHouse)
    EVENT_MANAGER:RegisterForEvent(CM.name .. "_Pending", EVENT_TRADING_HOUSE_PENDING_ITEM_UPDATE, OnPendingItemUpdate)
    Refresh()
end

---------------------------------------------------------------
-- Interface
---------------------------------------------------------------

local function Label(name, parent, text)
    local l = CreateControl(name, parent, CT_LABEL)
    l:SetFont(FONT)
    l:SetText(text)
    return l
end

-- Cadre : 4 bandes d'un pixel exact (s'affiche toujours sur les 4 cotes)
local PX = 1 / GetUIGlobalScale()

local function Border(parent, target)
    local r, g, b = unpack(BORDER_COLOR)
    local function Edge(suffix, p1, p2, w, h)
        local e = CreateControl(target:GetName() .. "Edge" .. suffix, parent, CT_TEXTURE)
        e:SetColor(r, g, b, 1)
        e:SetDrawLayer(DL_OVERLAY)
        e:SetAnchor(p1, target, p1, 0, 0)
        e:SetAnchor(p2, target, p2, 0, 0)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
    end
    Edge("T", TOPLEFT, TOPRIGHT, nil, PX)
    Edge("B", BOTTOMLEFT, BOTTOMRIGHT, nil, PX)
    Edge("L", TOPLEFT, BOTTOMLEFT, PX, nil)
    Edge("R", TOPRIGHT, BOTTOMRIGHT, PX, nil)
end

local function EditBox(name, parent, x, y, w)
    local bg = CreateControl(name .. "Bg", parent, CT_BACKDROP)
    bg:SetDimensions(w, 30)
    bg:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    bg:SetCenterColor(0, 0, 0, 0.7)
    bg:SetEdgeColor(0, 0, 0, 0)
    Border(parent, bg)

    local e = CreateControl(name, bg, CT_EDITBOX)
    e:SetFont(FONT)
    e:SetColor(1, 1, 1, 1)  -- mets en blanc la zone de saisie
    e:SetAnchor(TOPLEFT, bg, TOPLEFT, 8, 3)
    e:SetAnchor(BOTTOMRIGHT, bg, BOTTOMRIGHT, -8, -3)
    e:SetMaxInputChars(9)
    e:SetTextType(TEXT_TYPE_NUMERIC_UNSIGNED_INT)
    e:SetMouseEnabled(true)
    e:SetHandler("OnMouseDown", function() e:TakeFocus() end)
    e:SetHandler("OnEnter", function() e:LoseFocus() end)
    e:SetHandler("OnEscape", function() e:LoseFocus() end)
    return e
end

local function BuildUI()
    local win = CreateTopLevelWindow("CaracMarchandiseWindow")
    win:SetDimensions(320, 268)
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CM.pos.x, CM.pos.y)
    win:SetHandler("OnMoveStop", function()
        CM.pos.x = win:GetLeft()
        CM.pos.y = win:GetTop()
    end)
    local bg = CreateControl("CaracMarchandiseWindowBg", win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(0, 0, 0, 0.88)
    Border(win, bg)

    -- titre centre, en jaune
    local title = Label("CaracMarchandiseTitle", win, "CaracMarchandise")
    title:SetFont(FONT_TITLE)
    title:SetColor(unpack(TITLE_COLOR))
    title:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 10)
    title:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 10)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    -- icone + quantité en surimpression + nom
    ui.icon = CreateControl("CaracMarchandiseIcon", win, CT_TEXTURE)
    ui.icon:SetDimensions(44, 44)
    ui.icon:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 46)
    ui.icon:SetHidden(true)

    ui.iconCount = Label("CaracMarchandiseIconCount", win, "")
    ui.iconCount:SetDrawLayer(DL_OVERLAY)
    ui.iconCount:SetAnchor(BOTTOMRIGHT, ui.icon, BOTTOMRIGHT, -2, -1)

    ui.name = Label("CaracMarchandiseItem", win, GetString(CARACMARCHANDISE_NO_ITEM))
    ui.name:SetAnchor(LEFT, ui.icon, RIGHT, 10, 0)
    ui.name:SetDimensionConstraints(0, 0, 240, 0)

    ui.avg = Label("CaracMarchandiseAvg", win, GetString(CARACMARCHANDISE_AVG_LABEL) .. GetString(CARACMARCHANDISE_AVG_UNKNOWN) .. "\n" .. GetString(CARACMARCHANDISE_AVG_SOURCE))
    ui.avg:SetFont(FONT_LIGHT)
    ui.avg:SetColor(unpack(AVG_COLOR))
    ui.avg:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 96)
    ui.avg:SetAnchor(TOPRIGHT, win, TOPRIGHT, 0, 96)
    ui.avg:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    local qtyLbl = Label("CaracMarchandiseQtyLbl", win, GetString(CARACMARCHANDISE_QTY))
    qtyLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 162)
    ui.qty = EditBox("CaracMarchandiseQty", win, 170, 158, 130)

    local unitLbl = Label("CaracMarchandiseUnitLbl", win, string.format(GetString(CARACMARCHANDISE_UNIT_PRICE), GOLD_ICON))
    unitLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 198)
    ui.unit = EditBox("CaracMarchandiseUnit", win, 170, 194, 130)

    ui.total = Label("CaracMarchandiseTotal", win, GetString(CARACMARCHANDISE_TOTAL) .. "-")
    ui.total:SetFont(FONT_LIGHT)
    ui.total:SetColor(unpack(TOTAL_COLOR))
    ui.total:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 14, -16)

    local btn = CreateControlFromVirtual("CaracMarchandiseApply", win, "ZO_DefaultButton")
    btn:SetDimensions(120, 28)
    btn:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -12, -12)
    btn:SetFont(FONT)
    btn:SetText(GetString(CARACMARCHANDISE_APPLY))
    btn:SetHandler("OnClicked", Apply)
    ui.btn = btn

    ui.qty:SetHandler("OnTextChanged", ClampQtyField)
    ui.unit:SetHandler("OnTextChanged", UpdateTotal)
    UpdateButton()   -- (bouton grisé au démarrage)
    ui.win = win
end

---------------------------------------------------------------
-- Démarrage
---------------------------------------------------------------

local function OnAddOnLoaded(_, addonName)
    if addonName ~= CM.name then return end
    EVENT_MANAGER:UnregisterForEvent(CM.name, EVENT_ADD_ON_LOADED)

    CM.sv  = ZO_SavedVars:NewAccountWide("CaracMarchandiseSV", 1, nil, { prix = {} }, GetWorldName())
    CM.pos = ZO_SavedVars:NewCharacterIdSettings("CaracMarchandiseSV", 1, nil, { x = 40, y = 200 })

    BuildUI()

    EVENT_MANAGER:RegisterForEvent(CM.name, EVENT_OPEN_TRADING_HOUSE, OnOpenTradingHouse)
    ZO_PreHook("RequestPostItemOnTradingHouse", OnRequestPost)
end

EVENT_MANAGER:RegisterForEvent(CM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
