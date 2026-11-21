--------------------------------------------------------------------------
-- CaracMarchandise
-- Codé par Claude AI, Anthropic selon mes spécifications et testé par moi.
-- - choix de la quantité à vendre.
-- - calcul automatique du total (quantite x prix unitaire).
-- - mémorisation du dernier prix unitaire par objet.
-- - si le prix est mémorisé, celui s'affiche dans la fenêtre de vente.
-- - case "Report automatique" : envoie le prix mémorisé dans la fenêtre de vente (décochée par défaut).
-- - case "Sélection par 1 clic" : sélection de l'objet par un simple clic gauche (décochée par défaut, activation /reloadui requis).
-- Aucune librairie requise.
--------------------------------------------------------------------------

-- ===== COULEURS MODIFIABLES (r, g, b) entre 0 et 1 =====
local TITLE_COLOR  = { 1.0, 0.85, 0.1 }     -- titre "CaracMarchandise" (jaune)
local TOTAL_COLOR  = { 0.0, 1.0, 1.0 }      -- total (cyan)
local BORDER_COLOR = { 0.77, 0.76, 0.62 }   -- cadre (couleur des menus ESO)
local LABEL_COLOR  = { 0.77, 0.76, 0.62 }   -- intitulés des cases à cocher (couleur des menus ESO)
-- =======================================================

local FONT       = "ZoFontGameBold"
local FONT_TITLE = "ZoFontWinH2"
local FONT_LIGHT = "ZoFontGame"   -- police non grasse
local GOLD_ICON  = zo_iconFormat("EsoUI/Art/currency/currency_gold.dds", 18, 18)
local MAX_STACK  = 200
local MAX_TOTAL  = 2147483647   -- limite du jeu pour le prix (entier 32 bits)

local CM = {}
CM.name = "CaracMarchandise"

local ui = {}
local current = nil      -- { bag, slot, key, max }
local ignoreUntil = 0    -- ignore les événements "objet en attente" générés par l'addon
local split = nil        -- { slot, qty, total } : division de stack en cours

-- Retourne le temps de jeu en millisecondes (sert à ignorer brièvement les événements générés par l'addon)
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

-- Quantité maximale autorisée
local function MaxQty()
    if current and current.max then return current.max end
    return MAX_STACK
end

-- Quantité saisie, corrigée si besoin
local function ReadQty()
    local q = math.floor(tonumber(ui.qty:GetText()) or 1)
    if q > MaxQty() then q = MaxQty() end
    if q < 1 then q = 1 end
    return q
end

-- Prix unitaire saisi
local function ReadUnit()
    return math.floor(tonumber(ui.unit:GetText()) or 0)
end

-- Bouton cliquable seulement si quantité, prix et total sont valides
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

-- Mise à jour de la ligne total en fonction des données saisies
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

-- Vide l'affichage quand aucun objet n'est sélectionné
local function ClearItem()
    current = nil
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
-- Appliquer quantité + prix (division du stack si besoin)
---------------------------------------------------------------

local OnInventorySlotUpdate   -- définie plus bas
local SPLIT_EVENT = CM.name .. "_Split"

-- Arrête la surveillance des mises à jour d'inventaire
local function StopSplitWatch()
    EVENT_MANAGER:UnregisterForEvent(SPLIT_EVENT, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

-- Surveille l'apparition du nouveau stack dans le sac
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
        TRADING_HOUSE:SetPendingPostPrice(total)
        UpdateTotal()
    end, 250)
end

-- Applique quantité et prix (divise le stack si la quantité est partielle)
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
    CallSecureProtected("RequestMoveItem", bag, slot, BAG_BACKPACK, free, qty)

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

-- Met à jour la fenêtre selon l'objet sélectionné dans l'onglet "Vendre"
local function Refresh()
    local bag, slot, count = GetPendingItemPost()
    if not count or count <= 0 or not bag or not slot then
        ClearItem()
        return
    end

    local key = MakeKey(bag, slot)
    current = { bag = bag, slot = slot, key = key, max = GetSlotStackSize(bag, slot) }
    ShowItem(bag, slot)
    ui.qty:SetText(tostring(count))

    local saved = key and CM.sv.prix[key]
    if saved then
        ui.unit:SetText(tostring(saved))
        if CM.sv.autoReport then
            Apply()
        else
            UpdateTotal()
        end
    else
        ui.unit:SetText("")
        UpdateTotal()
    end
end

-- Réagit à un changement d'objet en attente de vente
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

-- Mémorise le prix unitaire au moment de la mise en vente
local function OnRequestPost(bag, slot, qty, price)
    if not ui.win or ui.win:IsHidden() then return end
    if qty and qty > 0 and price and price > 0 then
        local key = MakeKey(bag, slot)
        if key then CM.sv.prix[key] = math.floor(price / qty) end
    end
    ClearItem()
end

-- Cache la fenêtre et arrête les écoutes quand on quitte le comptoir
local function OnCloseTradingHouse()
    ui.win:SetHidden(true)
    split = nil
    StopSplitWatch()
    EVENT_MANAGER:UnregisterForEvent(CM.name .. "_Close", EVENT_CLOSE_TRADING_HOUSE)
    EVENT_MANAGER:UnregisterForEvent(CM.name .. "_Pending", EVENT_TRADING_HOUSE_PENDING_ITEM_UPDATE)
end

-- Affiche la fenêtre et démarre les écoutes à l'ouverture du comptoir
local function OnOpenTradingHouse()
    ui.win:SetHidden(false)
    EVENT_MANAGER:RegisterForEvent(CM.name .. "_Close", EVENT_CLOSE_TRADING_HOUSE, OnCloseTradingHouse)
    EVENT_MANAGER:RegisterForEvent(CM.name .. "_Pending", EVENT_TRADING_HOUSE_PENDING_ITEM_UPDATE, OnPendingItemUpdate)
    Refresh()
end

---------------------------------------------------------------
-- Interface
---------------------------------------------------------------

-- Crée un texte (label) avec la police par défaut
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

-- Crée un champ de saisie numérique avec fond et cadre
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

-- Crée la fenêtre : cadre, fond, titre, icône, cases, champs et bouton
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

    -- titre centré, en jaune
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

    -- case à cocher : report automatique du prix mémorisé (désactivée de base)
    local auto = CreateControlFromVirtual("CaracMarchandiseAuto", win, "ZO_CheckButton")
    auto:SetDimensions(20, 20)
    ZO_CheckButton_SetCheckState(auto, CM.sv.autoReport)
    ZO_CheckButton_SetToggleFunction(auto, function(_, checked)
        CM.sv.autoReport = checked
    end)
    local autoLbl = Label("CaracMarchandiseAutoLbl", win, GetString(CARACMARCHANDISE_AUTO))
    autoLbl:SetColor(unpack(LABEL_COLOR))
    autoLbl:SetAnchor(LEFT, auto, RIGHT, 8, 0)

    -- infobulle de la case "Report automatique"
    auto:SetMouseEnabled(true)
    auto:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, GetString(CARACMARCHANDISE_AUTO_TIP))
    end)
    auto:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    -- case à cocher : sélection de l'objet par un clic (prise en compte après /reloadui)
    local one = CreateControlFromVirtual("CaracMarchandiseOneClick", win, "ZO_CheckButton")
    one:SetDimensions(20, 20)
    ZO_CheckButton_SetCheckState(one, CM.sv.oneClick)
    ZO_CheckButton_SetToggleFunction(one, function(_, checked)
        CM.sv.oneClick = checked
    end)
    local oneLbl = Label("CaracMarchandiseOneClickLbl", win, GetString(CARACMARCHANDISE_ONECLICK))
    oneLbl:SetColor(unpack(LABEL_COLOR))
    oneLbl:SetAnchor(LEFT, one, RIGHT, 8, 0)

    -- infobulle d'avertissement pour la sélection du 1 clic
    one:SetMouseEnabled(true)
    one:SetHandler("OnMouseEnter", function(self)
        InitializeTooltip(InformationTooltip, self, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, GetString(CARACMARCHANDISE_ONECLICK_TIP))
    end)
    one:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    -- Centre les 2 cases à cocher (alignées entre elles) selon le libellé le plus long
    local largeur = 28 + math.max(autoLbl:GetTextWidth(), oneLbl:GetTextWidth())
    local x = math.floor((320 - largeur) / 2)
    auto:SetAnchor(TOPLEFT, win, TOPLEFT, x, 98)
    one:SetAnchor(TOPLEFT, win, TOPLEFT, x, 124)

    -- Affichage de la case quantité
    local qtyLbl = Label("CaracMarchandiseQtyLbl", win, GetString(CARACMARCHANDISE_QTY))
    qtyLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 162)
    ui.qty = EditBox("CaracMarchandiseQty", win, 170, 158, 130)

    -- Affichage de la case prix unitaire
    local unitLbl = Label("CaracMarchandiseUnitLbl", win, string.format(GetString(CARACMARCHANDISE_UNIT_PRICE), GOLD_ICON))
    unitLbl:SetAnchor(TOPLEFT, win, TOPLEFT, 14, 198)
    ui.unit = EditBox("CaracMarchandiseUnit", win, 170, 194, 130)

    -- Affichage du prix total calculé
    ui.total = Label("CaracMarchandiseTotal", win, GetString(CARACMARCHANDISE_TOTAL) .. "-")
    ui.total:SetFont(FONT_LIGHT)
    ui.total:SetColor(unpack(TOTAL_COLOR))
    ui.total:SetAnchor(BOTTOMLEFT, win, BOTTOMLEFT, 14, -16)

    -- Affichage du bouton Appliquer
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

    -- Rangement de la fenêtre dans la table ui
    ui.win = win
end

---------------------------------------------------------------
-- Sélection de l'objet par un simple clic gauche (option, décochée par défaut)
---------------------------------------------------------------

local function OnSlotClicked(inventorySlot, button)
    if not CM.sv.oneClick then return end
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if not ui.win or ui.win:IsHidden() then return end
    if GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then return end
    ZO_InventorySlot_DoPrimaryAction(inventorySlot)
end

---------------------------------------------------------------
-- Démarrage
---------------------------------------------------------------

-- Initialise l'addon : sauvegardes, interface, événements et hooks
local function OnAddOnLoaded(_, addonName)
    if addonName ~= CM.name then return end
    EVENT_MANAGER:UnregisterForEvent(CM.name, EVENT_ADD_ON_LOADED)

    CM.sv  = ZO_SavedVars:NewAccountWide("CaracMarchandiseSV", 1, nil, { prix = {}, autoReport = false, oneClick = false }, GetWorldName())
    CM.pos = ZO_SavedVars:NewCharacterIdSettings("CaracMarchandiseSV", 1, nil, { x = 40, y = 200 })

    BuildUI()

    EVENT_MANAGER:RegisterForEvent(CM.name, EVENT_OPEN_TRADING_HOUSE, OnOpenTradingHouse)

    -- simple clic gauche actif si la case est cochée par le joueur
    -- si décoché arrête déjà l’action tout de suite, même avant le reloadui
    if CM.sv.oneClick then
        ZO_PreHook("ZO_InventorySlot_OnSlotClicked", OnSlotClicked)
    end
    -- Intercepte la mise en vente pour mémoriser le prix
    ZO_PreHook("RequestPostItemOnTradingHouse", OnRequestPost)
end

-- Lance OnAddOnLoaded au chargement de l'addon
EVENT_MANAGER:RegisterForEvent(CM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)