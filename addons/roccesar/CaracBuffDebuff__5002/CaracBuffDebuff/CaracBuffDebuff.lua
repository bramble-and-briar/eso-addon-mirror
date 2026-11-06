-- CaracBuffDebuff : tes buffs, les debuffs de ta cible et tes propres debuffs, en blocs déplaçables
local ADDON = "CaracBuffDebuff"
local SV_NAME = "CaracBuffDebuffSV" -- nom de la variable sauvegardée (inchangé, déclaré dans le .txt de l'addon)

------------------------------------------------------------
-- LIBELLÉS ET INFOBULLES (modifie ici sans risque)
-- Les réglages sont sauvegardés sous l'IDENTIFIANT (la clé à gauche, ex. "hawkEye"),
-- jamais sous le libellé : changer un texte ne fait donc perdre aucun réglage.
------------------------------------------------------------
local TEXT = {
    gear = { tip = "Paramétrage du panneau." },

    account = {
        label = "Paramètres communs au compte.",
        tip   = "Cochée : position du panneau et paramètres communs au compte ; Décochée : position du panneau et paramètres propres au personnage.",
    },
    playerBuffs = {
        label = "Bonus du joueur.",
        tip   = "Cochée : Affiche tous les bonus (buffs) du joueur ; Décochée : n’affiche pas les bonus (buffs) du joueur.",
    },
    hawkEye = {
        label = "Oeil de faucon (arc).",
        tip   = "Cochée : Le bonus du passif Oeil de faucon (arc) s’affiche dans une couleur différente, la couleur change lorsque le stack maximum est atteint.",
    },
    othersBuffs = {
        label = "Bonus des autres joueurs.",
        tip   = "Cochée : Affiche tous les bonus (buffs) donnés par les autres joueurs ; Décochée : n’affiche pas les bonus (buffs) donnés par les autres joueurs.",
    },
    foodDrink = {
        label = "Bonus de nourriture & boisson.",
        tip   = "Cochée : Affiche le bonus de nourriture ou de boisson ; Décochée : n’affiche pas le bonus de nourriture ou de boisson.",
    },
    longBuffs = {
        label = "Les bonus longs.",
        tip   = "Cochée : Affiche les bonus longs ; Décochée : n’affiche pas les bonus longs.",
    },
    vampLycan = {
        label = "Vampirisme & Lycanthropie.",
        tip   = "Cochée : Affiche le niveau de vampirisme et la lycanthropie ; Décochée : n’affiche ni le vampirisme ni la lycanthropie.",
    },
    mundus = {
        label = "Pierre de mundus.",
        tip   = "Cochée : Affiche la pierre de mundus ; Décochée : n’affiche pas la pierre de mundus.",
    },
    esoPlus = {
        label = "Abonnement ESO Plus.",
        tip   = "Cochée : Affiche l’abonnement ESO Plus s’il est actif ; Décochée : ne l’affiche pas.",
    },
    permOthers = {
        label = "Autres effets permanents.",
        tip   = "Cochée : Affiche les autres effets permanents (passifs, mythiques) ; Décochée : ne les affiche pas.",
    },
    showDebuffs = {
        label = "Afficher les malus (debuffs).",
        tip   = "Cochée : Affiche tous les malus (debuffs) ; Décochée : n’affiche pas les malus (debuffs).",
    },
    taunt = {
        label = "Provocation (couleur spéciale).",
        tip   = "Cochée : Le malus Provocation sur la cible s’affiche dans une couleur différente ; Décochée : il s’affiche comme les autres malus.",
    },
    reset = {
        label = "Réinitialiser",
        tip   = "Remet le panneau à sa position d’origine et les boîtes à cocher à leur valeur initiale.",
    },
}

-- Contenu du menu de chaque panneau (dans l'ordre d'affichage). Le bouton « Réinitialiser » est ajouté en dernier.
local MENU = {
    buff   = { "account", "playerBuffs", "hawkEye", "othersBuffs" },         -- panneau CaracBuff
    long   = { "account", "foodDrink", "longBuffs" },                        -- panneau CaracBuffLong
    self   = { "account", "showDebuffs" },                                   -- panneau CaracDebuffMoi
    debuff = { "account", "showDebuffs", "taunt" },                          -- panneau CaracDebuff (cible)
    perm   = { "account", "mundus", "esoPlus", "vampLycan", "permOthers" },  -- panneau CaracPermanent
}

------------------------------------------------------------
-- RÉGLAGES (modifie ici)
------------------------------------------------------------
local CFG = {
    iconSize       = 34,    -- taille des icônes
    rowGap         = 2,     -- espace vertical entre deux lignes
    nameWidth      = 190,   -- largeur réservée au nom du buff/debuff
    maxRows        = 30,    -- nombre maximal de lignes par bloc
    minSeconds     = 1,     -- un effet n'est affiché que s'il lui reste plus de X secondes
    onlyMine       = false, -- true : seulement les debuffs de la cible que TU as lancés ; false : tous
    updateMs       = 100,   -- fréquence de mise à jour
    otherColor     = { 0.45, 0.85, 1, 1 },        -- couleur du nom des buffs reçus d'un autre joueur (bleu clair)
    debuffColor    = { 1, 0.2, 0.2, 1  },      -- couleur du nom des debuffs subis par le joueur (rouge)
    debuffcibleColor    = { 0.8, 0.6, 1, 1  }, -- couleur du nom des debuffs appliqués sur la cible (violet)
    
    -- Provocation (malus sur la cible), repérée par son numéro, affichée dans une couleur spéciale
    tauntId        = 38254,
    tauntColor     = { 1, 0.8, 1 , 1 }, -- couleur du nom de la provocation (violet clair)

    -- Panneau CaracBuffLong : position d'origine = X lignes sous CaracBuff (ajuste ici ; le panneau reste déplaçable)
    longPanelRowsBelow = 16,

    -- Couleur du nom d'un bonus du panneau CaracBuffLong quand il lui reste peu de temps
    cooldownSeconds     = 300,   -- en couleur quand il reste X secondes ou moins (300 = 5 min)
    cooldownColor       = { 1, 0.6, 0.1, 1 }, -- couleur du cooldown : orange 

    -- Tape /caracids en jeu pour lire les IDs, résultat attendu : un chiffre comme 123456.

    -- BONUS LONGS À AFFICHER dans CaracBuffLong (case « Les bonus longs. »), repérés par leur numéro (indépendant de la langue).
    -- Un bonus listé ici est affiché quelle que soit sa durée (sauf s'il est reconnu comme nourriture/boisson, qui est prioritaire). Ajoute-y au fur et à mesure les bonus longs que tu identifies.
    -- Exemple : [123456] = true,
    longIds        = {
        [43752] = true, -- Invocation d'âme (recharge d'1 h du passif Magie des âmes)
    },
    -- Sont aussi considérés comme bonus longs : tout bonus de plus de longMinTotal secondes,
    longMinTotal   = 900,
    -- ... et tout bonus dont le NOM de fichier d'icône contient l'un de ces termes (en minuscules), même s'il dure moins longtemps.
    longIconPatterns = { "ability_alchemy" },
    -- Les effets permanents s’affichent dans CaracPermanent.

    -- NOURRITURE & BOISSON (case « Bonus de nourriture & boisson. ») : affichées quelle que soit leur durée restante.
    -- Repérées par le NOM du fichier de l'icône (/esoui/art/icons/NOM) : s'il contient l'un de ces termes (en minuscules).
    -- Complète la liste au fur et à mesure.
    foodIconPatterns = { "crafting", "food", "store", "event" },
    -- Nourriture ou boisson précise repérée par son numéro, si son icône ne contient aucun de ces termes.
    foodIds        = {
        -- [123456] = true,
    },

    -- VAMPIRISME (case « Vampirisme & Lycanthropie. ») : repéré par son numéro. Le niveau apparaît dans le libellé du jeu.
    vampireIds     = {
        [135397] = true,  -- Vampirisme niveau 1
        [135399] = true,  -- Vampirisme niveau 2
        [135400] = true,  -- Vampirisme niveau 3
        [135402] = true,  -- Vampirisme niveau 4
    },

    -- LYCANTHROPIE (case « Vampirisme & Lycanthropie. ») : repérée par son numéro, classée avec le vampirisme
    lycanIds       = {
        [35658] = true, -- Lycanthropie
    },

    -- Un effet dont la durée restante est négative de plus de X secondes est considéré comme permanent
    -- (le petit seuil évite de classer un effet qui vient juste de se terminer)
    permNegativeSeconds = 2,

    -- EFFETS PERMANENTS (panneau CaracPermanent) : tout bonus sans durée est considéré comme permanent.
    permanentColor     = { 1, 1, 1, 1 }, -- couleur du nom des effets permanents (blanc)
    -- Pierre de mundus : repérée par le nom du fichier de l'icône (en minuscules)
    mundusIconPatterns = { "mundus" },
    -- Effet précis à classer comme permanent, repéré par son numéro (même s'il a une durée)
    permIds            = {
        -- [123456] = true,
    },

    -- Abonnement ESO Plus : le jeu ne le fournit pas comme effet, il est ajouté à la main dans CaracPermanent
    esoPlusName = "ESO Plus",
    esoPlusIcon = "/esoui/art/icons/store_esoplus_01.dds",  

    -- Oeil de faucon (passif de l'arc), repéré par son identifiant (indépendant de la langue)
    hawkEye = {
        id        = 78855,
        color     = { 0.6, 0.8, 0.6, 1 },  -- couleur normale : vert terne
        maxStacks = 5,                  -- nombre de cumuls maximal
        maxColor  = { 0.2, 1, 0.2, 1 },    -- couleur au cumul maximal : vert vif
    },
}

local wm = WINDOW_MANAGER
-- Alignement sur la grille de pixels (évite les traits qui disparaissent selon l'échelle de l'interface)
local UI_SCALE = GetUIGlobalScale() or 1
local function S(v) return zo_round(v * UI_SCALE) / UI_SCALE end
local PX = 1 / UI_SCALE -- un pixel exact
local BLOCK_W = CFG.iconSize + 6 + CFG.nameWidth
local ROW_STEP = CFG.iconSize + CFG.rowGap
local MIN_H = CFG.iconSize * 2
local BTN_LEFT = 36   -- taille de la roue dentée
local CTRL_H = BTN_LEFT -- hauteur de la zone de la roue dentée

-- Couleur de l'interface du jeu (texte des menus), utilisée pour les libellés et les infobulles
local UI_R, UI_G, UI_B = ZO_NORMAL_TEXT:UnpackRGBA()

-- Position d'origine : buffs à gauche de ton personnage, debuffs à droite
local screenW, screenH = GuiRoot:GetDimensions()
local DEFAULTS = {
    buffX   = S(screenW / 2 - 170 - BLOCK_W),
    buffY   = S(screenH / 2 - 150),
    debuffX = S(screenW / 2 + 170),
    debuffY = S(screenH / 2 - 150),
    selfX   = S(screenW / 2 - 170 - 2 * BLOCK_W - 20),
    selfY   = S(screenH / 2 - 150),
    -- CaracBuffLong : sous CaracBuff (CFG.longPanelRowsBelow lignes plus bas) ; déplaçable ensuite
    longX   = S(screenW / 2 - 170 - BLOCK_W),
    longY   = S(screenH / 2 - 150 + CFG.longPanelRowsBelow * ROW_STEP),
    permX   = S(screenW / 2 + 170 + BLOCK_W + 20),
    permY   = S(screenH / 2 - 150),
}

------------------------------------------------------------
-- DONNÉES SAUVEGARDÉES
--   acc : réglages communs au compte, séparés par serveur (EU, NA, PTS) -> NewAccountWide + GetWorldName()
--   ch  : réglages du personnage, déjà distincts par serveur car les CharacterID sont uniques -> NewCharacterIdSettings
------------------------------------------------------------
local acc = {}
local ch = {}

-- Sous-table créée à la demande
local function Sub(t, k)
    if type(t[k]) ~= "table" then t[k] = {} end
    return t[k]
end

local function UsesAccount(key) return Sub(ch, "useAccount")[key] ~= false end

-- Table où sont rangées les cases à cocher du panneau : compte ou personnage (même case « Paramètres communs au compte »)
local function OptScope(key)
    if UsesAccount(key) then return Sub(Sub(acc, "opts"), key) end
    return Sub(Sub(ch, "opts"), key)
end

-- Cases à cocher du menu : cochées par défaut (tant que rien n'est enregistré, la valeur est « cochée »)
local function GetOpt(key, id) return OptScope(key)[id] ~= false end
local function SetOpt(key, id, checked) OptScope(key)[id] = checked and true or false end

-- Remet les cases à cocher du menu d'un panneau en accord avec les réglages enregistrés
local function RefreshChecks(block)
    for id, cb in pairs(block.checks) do
        local checked
        if id == "account" then checked = UsesAccount(block.key) else checked = GetOpt(block.key, id) end
        ZO_CheckButton_SetCheckState(cb, checked)
    end
end

-- Table où est rangée la position du panneau : compte (case « Paramètres communs au compte » cochée) ou personnage
local function PosScope(key)
    if UsesAccount(key) then return Sub(acc, "pos") end
    return Sub(ch, "pos")
end

local function GetSavedPosition(key)
    local p = PosScope(key)[key]
    if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then
        return p.x, p.y
    end
    return DEFAULTS[key .. "X"], DEFAULTS[key .. "Y"]
end

local function PlaceBlock(block)
    local x, y = GetSavedPosition(block.key)
    block.top:ClearAnchors()
    block.top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, S(x), S(y))
end

local function SavePosition(block)
    PosScope(block.key)[block.key] = { x = S(block.top:GetLeft()), y = S(block.top:GetTop()) }
end

-- Position d'origine ET valeurs initiales des cases (toutes cochées), pour le réglage actuellement utilisé (compte ou personnage)
local function ResetPanel(block)
    PosScope(block.key)[block.key] = nil
    local opts = Sub(UsesAccount(block.key) and Sub(acc, "opts") or Sub(ch, "opts"), block.key)
    for id in pairs(opts) do opts[id] = nil end
    PlaceBlock(block)
    RefreshChecks(block)
end

local function SetUsesAccount(block, checked)
    local key = block.key
    local flags = Sub(ch, "useAccount")
    checked = checked and true or false
    if (flags[key] ~= false) == checked then return end -- rien à changer

    -- Valeurs actuelles des cases, relevées avant le changement
    local current = {}
    for id in pairs(block.checks) do
        if id ~= "account" then current[id] = GetOpt(key, id) end
    end

    flags[key] = checked
    if checked then
        -- Le panneau reste où il est : sa position et l'état des cases deviennent ceux du compte
        Sub(acc, "pos")[key] = { x = S(block.top:GetLeft()), y = S(block.top:GetTop()) }
        local opts = Sub(Sub(acc, "opts"), key)
        for id, value in pairs(current) do opts[id] = value end
    else
        -- Réglages propres au personnage : le panneau reste où il est et les cases gardent leur état actuel,
        -- qui deviennent ceux du personnage
        Sub(ch, "pos")[key] = { x = S(block.top:GetLeft()), y = S(block.top:GetTop()) }
        local opts = Sub(Sub(ch, "opts"), key)
        for id, value in pairs(current) do opts[id] = value end
    end
    RefreshChecks(block)
end

------------------------------------------------------------
-- MIGRATION : récupère les positions de l'ancienne version
-- (anciennement rangées dans Default > @compte > $AccountWide, communes à tous les serveurs)
------------------------------------------------------------
local function MigrateLegacyPositions()
    if acc.migrated then return end
    acc.migrated = true

    local root = _G[SV_NAME]
    local old = root and root["Default"] and root["Default"][GetDisplayName()]
    old = old and old["$AccountWide"]
    if type(old) ~= "table" then return end

    local pos = Sub(acc, "pos")
    for _, key in ipairs({ "buff", "debuff", "self", "long", "perm" }) do
        local x, y = old[key .. "X"], old[key .. "Y"]
        if type(x) == "number" and type(y) == "number" and not pos[key] then
            pos[key] = { x = x, y = y }
        end
    end
end

------------------------------------------------------------
-- OUTILS
------------------------------------------------------------
-- Durée restante : "6,3" (secondes), "2m" au-delà d'une minute
local function FormatDuration(r)
    if r <= 0 then return "" end
    if r >= 60 then return zo_floor(r / 60) .. "m" end
    return (string.format("%.1f", r):gsub("%.", ","))
end

-- Ajoute un traitement à un événement de contrôle sans supprimer celui qui existe déjà
local function HookHandler(control, handlerName, fn)
    local old = control:GetHandler(handlerName)
    control:SetHandler(handlerName, function(...)
        fn(...)
        if old then return old(...) end
    end)
end

------------------------------------------------------------
-- INFOBULLE : celle du jeu (fond noir, texte et cadre aux couleurs de l'interface)
------------------------------------------------------------
local tipOwner = nil -- contrôle pour lequel notre infobulle est affichée

local function ShowTip(control, text)
    tipOwner = control
    ZO_Tooltips_ShowTextTooltip(control, BOTTOM, text) -- BOTTOM pour afficher en bas et TOP pour haut
end

-- Ne masque que notre propre infobulle, pour ne pas toucher à celles du jeu ou des autres addons
local function HideTip()
    if tipOwner then
        tipOwner = nil
        ZO_Tooltips_HideTextTooltip()
    end
end

local function AttachTooltip(control, text)
    HookHandler(control, "OnMouseEnter", function() ShowTip(control, text) end)
    HookHandler(control, "OnMouseExit", HideTip)
end

------------------------------------------------------------
-- BOÎTES D'INTERACTION
------------------------------------------------------------
-- Case à cocher du jeu + libellé cliquable + infobulle
local function MakeCheck(parent, name, text, tipTextStr, onToggle)
    local cb = wm:CreateControlFromVirtual(name, parent, "ZO_CheckButton")
    ZO_CheckButton_SetToggleFunction(cb, function(_, checked) onToggle(checked) end)

    local label = wm:CreateControl(name .. "Label", parent, CT_LABEL)
    label:SetFont("ZoFontGameBold")
    label:SetColor(UI_R, UI_G, UI_B, 1) -- même couleur que le texte des menus du jeu
    label:SetText(text)
    label:SetAnchor(LEFT, cb, RIGHT, 4, 0)
    label:SetMouseEnabled(true)
    label:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            local value = not ZO_CheckButton_IsChecked(cb)
            ZO_CheckButton_SetCheckState(cb, value)
            onToggle(value)
        end
    end)

    AttachTooltip(cb, tipTextStr)
    AttachTooltip(label, tipTextStr)
    return cb, label
end

-- Place la roue dentée au-dessus du panneau, ou en dessous si le panneau touche le haut de l'écran
local function UpdateRowAnchor(block)
    local below = block.top:GetTop() < CTRL_H + 10
    if below ~= block.rowBelow then
        block.rowBelow = below
        block.row:ClearAnchors()
        if below then
            block.row:SetAnchor(TOPLEFT, block.top, BOTTOMLEFT, 0, 4)
        else
            block.row:SetAnchor(BOTTOMLEFT, block.top, TOPLEFT, 0, -4)
        end
    end
end

-- Fond noir + cadre d'un pixel exact aux couleurs de l'interface pour le menu
local function AddMenuBackground(menu, prefix)
    local fill = wm:CreateControl(ADDON .. prefix .. "MenuFill", menu, CT_TEXTURE)
    fill:SetAnchorFill(menu)
    fill:SetColor(0, 0, 0, 0.92)

    local function Edge(suffix, p1, p2, w, h)
        local e = wm:CreateControl(ADDON .. prefix .. "MenuEdge" .. suffix, menu, CT_TEXTURE)
        e:SetColor(UI_R, UI_G, UI_B, 0.9)
        e:SetDrawLayer(DL_OVERLAY)
        e:SetAnchor(p1, menu, p1, 0, 0)
        e:SetAnchor(p2, menu, p2, 0, 0)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
    end
    Edge("T", TOPLEFT, TOPRIGHT, nil, PX)
    Edge("B", BOTTOMLEFT, BOTTOMRIGHT, nil, PX)
    Edge("L", TOPLEFT, BOTTOMLEFT, PX, nil)
    Edge("R", TOPRIGHT, BOTTOMRIGHT, PX, nil)
end

------------------------------------------------------------
-- BLOCS
------------------------------------------------------------
local allBlocks = {}

-- Referme tous les menus de paramétrage
local function CloseMenus()
    for _, b in ipairs(allBlocks) do
        if not b.menu:IsHidden() then b.menu:SetHidden(true) end
    end
end

local function ToggleMenu(block)
    local show = block.menu:IsHidden()
    CloseMenus()
    HideTip()
    block.menu:SetHidden(not show)
end

local function CreateBlock(prefix, labelText, key, colorOthers)
    local block = { key = key, count = -1, colorOthers = colorOthers, rowBelow = false, checks = {} }
    allBlocks[#allBlocks + 1] = block

    local top = wm:CreateTopLevelWindow(ADDON .. prefix .. "Top")
    top:SetDimensions(S(BLOCK_W), S(MIN_H))
    top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DEFAULTS[key .. "X"], DEFAULTS[key .. "Y"])
    top:SetClampedToScreen(true)
    top:SetMovable(true)
    top:SetMouseEnabled(true)
    top:SetDrawTier(DT_LOW) -- les fenêtres des autres addons passent devant nos cadres
    top:SetDrawLayer(DL_BACKGROUND)
    top:SetDrawLevel(0)
    block.top = top

    -- Cadre rouge transparent visible quand le curseur de la souris est libre :
    -- un fond et 4 bandes d'un pixel exact (PX), car une bordure « edge » peut perdre un côté selon l'échelle
    local outline = wm:CreateControl(ADDON .. prefix .. "Outline", top, CT_CONTROL)
    outline:SetAnchorFill(top)
    outline:SetHidden(true)
    block.outline = outline

    local outlineFill = wm:CreateControl(ADDON .. prefix .. "OutlineFill", outline, CT_TEXTURE)
    outlineFill:SetAnchorFill(outline)
    outlineFill:SetColor(0.8, 0.1, 0.1, 0.25)
    outlineFill:SetDrawLayer(DL_BACKGROUND)
    outlineFill:SetDrawLevel(1)

    local function Edge(suffix, p1, p2, w, h)
        local e = wm:CreateControl(ADDON .. prefix .. "OutlineEdge" .. suffix, outline, CT_TEXTURE)
        e:SetColor(1, 0.3, 0.3, 0.9)
        e:SetDrawLayer(DL_BACKGROUND)
        e:SetDrawLevel(2)
        e:SetAnchor(p1, outline, p1, 0, 0)
        e:SetAnchor(p2, outline, p2, 0, 0)
        if w then e:SetWidth(w) end
        if h then e:SetHeight(h) end
    end
    Edge("T", TOPLEFT, TOPRIGHT, nil, PX)
    Edge("B", BOTTOMLEFT, BOTTOMRIGHT, nil, PX)
    Edge("L", TOPLEFT, BOTTOMLEFT, PX, nil)
    Edge("R", TOPRIGHT, BOTTOMRIGHT, PX, nil)

    local placeholder = wm:CreateControl(ADDON .. prefix .. "Placeholder", top, CT_LABEL)
    placeholder:SetFont("ZoFontGameBold")
    placeholder:SetColor(1, 1, 1, 1)
    placeholder:SetText(labelText)
    placeholder:SetAnchor(CENTER, top, CENTER, 0, 0)
    placeholder:SetHidden(true)
    placeholder:SetDrawLayer(DL_BACKGROUND)
    placeholder:SetDrawLevel(3)
    block.placeholder = placeholder

    local slots = {}
    for i = 1, CFG.maxRows do
        local icon = wm:CreateControl(ADDON .. prefix .. "Icon" .. i, top, CT_TEXTURE)
        icon:SetDimensions(CFG.iconSize, CFG.iconSize)
        icon:SetAnchor(TOPLEFT, top, TOPLEFT, 0, (i - 1) * ROW_STEP)
        icon:SetHidden(true)

        local dur = wm:CreateControl(ADDON .. prefix .. "Dur" .. i, icon, CT_LABEL)
        dur:SetFont("ZoFontGameBold")
        dur:SetColor(1, 1, 1, 1)
        dur:SetAnchor(BOTTOM, icon, BOTTOM, 0, -1)

        local name = wm:CreateControl(ADDON .. prefix .. "Name" .. i, icon, CT_LABEL)
        name:SetFont("ZoFontGameBold")
        name:SetColor(1, 1, 1, 1)
        name:SetWidth(CFG.nameWidth)
        name:SetMaxLineCount(1)
        name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        name:SetAnchor(LEFT, icon, RIGHT, 6, 0)

        slots[i] = { icon = icon, dur = dur, name = name }
    end
    block.slots = slots

    -- Zone d'interaction (visible seulement quand le curseur est libre) : la roue dentée
    local row = wm:CreateControl(ADDON .. prefix .. "Row", top, CT_CONTROL)
    row:SetDimensions(CTRL_H, CTRL_H)
    row:SetAnchor(BOTTOMLEFT, top, TOPLEFT, 0, -4)
    row:SetHidden(true)
    block.row = row

    local gear = wm:CreateControl(ADDON .. prefix .. "Gear", row, CT_BUTTON)
    gear:SetDimensions(CTRL_H, CTRL_H)
    gear:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    gear:SetNormalTexture("EsoUI/Art/ChatWindow/chat_options_up.dds")
    gear:SetPressedTexture("EsoUI/Art/ChatWindow/chat_options_down.dds")
    gear:SetMouseOverTexture("EsoUI/Art/ChatWindow/chat_options_over.dds")
    gear:SetHandler("OnClicked", function() ToggleMenu(block) end)
    AttachTooltip(gear, TEXT.gear.tip)
    block.gear = gear

    -- Menu de paramétrage (fenêtre à part, au-dessus des panneaux), ouvert par la roue dentée
    local pad, rowH = 10, 26
    local menu = wm:CreateTopLevelWindow(ADDON .. prefix .. "Menu")
    menu:SetDrawTier(DT_MEDIUM)
    menu:SetMouseEnabled(true)
    menu:SetClampedToScreen(true)
    menu:SetHidden(true)
    menu:SetAnchor(TOPLEFT, gear, BOTTOMLEFT, 0, 4)
    AddMenuBackground(menu, prefix)
    block.menu = menu

    local maxW = 120 -- largeur minimale : celle du bouton
    local n = 0
    for _, id in ipairs(MENU[key]) do
        local t = TEXT[id]
        local onToggle
        if id == "account" then
            onToggle = function(checked) SetUsesAccount(block, checked) end
        else
            onToggle = function(checked) SetOpt(key, id, checked) end
        end

        local cb, lbl = MakeCheck(menu, ADDON .. prefix .. "Check_" .. id, t.label, t.tip, onToggle)
        cb:SetAnchor(TOPLEFT, menu, TOPLEFT, pad, pad + n * rowH)
        block.checks[id] = cb
        maxW = math.max(maxW, cb:GetWidth() + 4 + lbl:GetTextWidth())
        n = n + 1
    end

    local resetBtn = wm:CreateControlFromVirtual(ADDON .. prefix .. "Reset", menu, "ZO_DefaultButton")
    resetBtn:SetText(TEXT.reset.label)
    resetBtn:SetWidth(120)
    local btnY = pad + n * rowH + 6
    resetBtn:SetAnchor(TOP, menu, TOP, 0, btnY) -- centré horizontalement
    resetBtn:SetHandler("OnClicked", function() ResetPanel(block) end)
    AttachTooltip(resetBtn, TEXT.reset.tip)

    menu:SetDimensions(S(maxW + 2 * pad), S(btnY + 30 + pad))

    -- Le bloc disparaît dans les menus, comme le reste de l'interface de jeu
    local fragment = ZO_SimpleSceneFragment:New(top)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    top:SetHandler("OnMoveStop", function()
        SavePosition(block)
        PlaceBlock(block) -- recale sur la grille de pixels pour que le cadre reste net
    end)

    return block
end

local buffBlock = CreateBlock("Buff", "CaracBuff", "buff", true)
local debuffBlock = CreateBlock("Debuff", "CaracDebuff", "debuff")
local selfDebuffBlock = CreateBlock("SelfDebuff", "CaracDebuffMoi", "self")
local longBlock = CreateBlock("Long", "CaracBuffLong", "long")
local permBlock = CreateBlock("Perm", "CaracPermanent", "perm")

------------------------------------------------------------
-- LECTURE DES EFFETS
------------------------------------------------------------
-- Nom du fichier d'icône (sans les dossiers), en minuscules
local function IconFileName(iconFile)
    return string.lower(tostring(iconFile or "")):match("([^/\\]+)$") or ""
end

-- Le nom du fichier d'icône contient-il l'un des termes de la liste ?
local function FileMatches(iconFile, patterns)
    local fileName = IconFileName(iconFile)
    for _, pattern in ipairs(patterns) do
        if string.find(fileName, pattern, 1, true) then return true end
    end
    return false
end

-- Nourriture / boisson : par identifiant, ou à défaut par le nom du fichier d'icône
local function IsFood(abilityId, iconFile)
    return CFG.foodIds[abilityId] or FileMatches(iconFile, CFG.foodIconPatterns)
end

-- Vampirisme et lycanthropie : par identifiant
local function IsVampOrLycan(abilityId)
    return (CFG.vampireIds[abilityId] or CFG.lycanIds[abilityId]) and true or false
end

-- Durée restante et durée totale d'un effet (0 pour un effet permanent)
local function Timing(timeStarted, timeEnding, now)
    local remaining = (timeEnding and timeEnding > 0) and (timeEnding - now) or 0
    local total = (timeStarted and timeStarted > 0 and timeEnding and timeEnding > timeStarted) and (timeEnding - timeStarted) or 0
    return remaining, total
end

-- Range un bonus : "vampire", "food" (nourriture/boisson), "perm", "long", ou nil (bonus ordinaire).
-- Les bonus classés ici vont dans CaracBuffLong ou CaracPermanent et plus dans CaracBuff.
local function Classify(buffName, iconFile, abilityId, remaining, total)
    if IsVampOrLycan(abilityId) then return "vampire" end              -- même sans durée
    if CFG.permIds[abilityId] or FileMatches(iconFile, CFG.mundusIconPatterns) then return "perm" end
    if remaining < -CFG.permNegativeSeconds then return "perm" end     -- durée restante négative : effet permanent
    if remaining == 0 and total == 0 then return "perm" end            -- aucune durée : effet permanent
    if remaining <= CFG.minSeconds then return nil end                 -- presque terminé
    if IsFood(abilityId, iconFile) then return "food" end              -- nourriture/boisson : prioritaire, quelle que soit la durée
    if CFG.longIds[abilityId] then return "long" end                   -- bonus long identifié par son numéro
    if total >= CFG.longMinTotal or remaining >= CFG.longMinTotal then return "long" end
    if FileMatches(iconFile, CFG.longIconPatterns) then return "long" end
    return nil
end

-- Débuffs : mineOnly : ne garder que les effets lancés par toi
local function CollectDebuffs(unitTag, mineOnly, color)
    local list = {}
    local now = GetFrameTimeSeconds()
    local useTauntColor = (unitTag == "reticleover") and GetOpt("debuff", "taunt")

    for i = 1, GetNumBuffs(unitTag) do
        local buffName, _, timeEnding, _, stackCount, iconFile, _, effectType, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo(unitTag, i)

        if iconFile and iconFile ~= "" and effectType == BUFF_EFFECT_TYPE_DEBUFF
            and (castByPlayer or not mineOnly) then
            local remaining = (timeEnding and timeEnding > 0) and (timeEnding - now) or 0
            if remaining > CFG.minSeconds then
                local text = zo_strformat(SI_ABILITY_NAME, buffName)
                if stackCount and stackCount > 1 then text = text .. " x" .. stackCount end
                 -- Provocation sur la cible : couleur spéciale si la case est cochée
                local entryColor = color
                if useTauntColor and abilityId == CFG.tauntId then
                    entryColor = CFG.tauntColor
                end
                list[#list + 1] = { icon = iconFile, name = text, remaining = remaining, mine = castByPlayer and true or false, color = entryColor }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.remaining ~= b.remaining then return a.remaining < b.remaining end
        return a.name < b.name
    end)
    return list
end

-- Buffs ordinaires du joueur (hors bonus longs, permanents, nourriture et vampirisme), filtrés par les cases du panneau « buff »
local function CollectBuffs()
    local key = "buff"
    local list = {}
    local now = GetFrameTimeSeconds()

    local optPlayer = GetOpt(key, "playerBuffs")
    local optOthers = GetOpt(key, "othersBuffs")
    local optHawk   = GetOpt(key, "hawkEye")

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, iconFile, _, effectType, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo("player", i)
        if iconFile and iconFile ~= "" and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            local remaining, total = Timing(timeStarted, timeEnding, now)

            if remaining > CFG.minSeconds and not Classify(buffName, iconFile, abilityId, remaining, total) then
                local show, color = false, nil

                if abilityId == CFG.hawkEye.id and optHawk then
                    -- Oeil de faucon : affiché même si « Bonus du joueur » est décoché, avec sa couleur spéciale
                    show = true
                    color = CFG.hawkEye.color
                    if stackCount and stackCount >= CFG.hawkEye.maxStacks then color = CFG.hawkEye.maxColor end
                elseif castByPlayer then
                    show = optPlayer
                else
                    show = optOthers
                end

                if show then
                    local text = zo_strformat(SI_ABILITY_NAME, buffName)
                    if stackCount and stackCount > 1 then text = text .. " x" .. stackCount end
                    list[#list + 1] = { icon = iconFile, name = text, remaining = remaining, sort = remaining,
                                        mine = castByPlayer and true or false, color = color }
                end
            end
        end
    end

    -- Le plus proche de la fin en premier
    table.sort(list, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
    end)
    return list
end

-- Panneau CaracBuffLong : nourriture & boisson et bonus longs (selon les cases cochées)
local function CollectLong()
    local key = "long"
    local list = {}
    local now = GetFrameTimeSeconds()

    local optFood = GetOpt(key, "foodDrink")
    local optLong = GetOpt(key, "longBuffs")

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, iconFile, _, effectType, _, _, abilityId =
            GetUnitBuffInfo("player", i)

        if iconFile and iconFile ~= "" and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            local remaining, total = Timing(timeStarted, timeEnding, now)
            local class = Classify(buffName, iconFile, abilityId, remaining, total)

            if (class == "food" and optFood) or (class == "long" and optLong) then
                local text = zo_strformat(SI_ABILITY_NAME, buffName)
                if stackCount and stackCount > 1 then
                    text = text .. " x" .. stackCount
                end

                -- Nom en couleur quand il reste 5 minutes ou moins
                local color = (remaining > 0 and remaining <= CFG.cooldownSeconds) and CFG.cooldownColor or nil
                list[#list + 1] = { icon = iconFile, name = text, remaining = remaining,
                                    sort = (remaining > 0) and remaining or math.huge,
                                    mine = true, color = color }
            end
        end
    end

    table.sort(list, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
    end)
    return list
end

-- Panneau CaracPermanent : effets sans durée (mundus, abonnement, passifs, mythiques) + vampirisme & lycanthropie
local function CollectPermanent()
    local key = "perm"
    local list = {}
    local now = GetFrameTimeSeconds()

    local optMundus = GetOpt(key, "mundus")
    local optVamp   = GetOpt(key, "vampLycan")
    local optOthers = GetOpt(key, "permOthers")

    for i = 1, GetNumBuffs("player") do
        local buffName, timeStarted, timeEnding, _, stackCount, iconFile, _, effectType, _, _, abilityId =
            GetUnitBuffInfo("player", i)

        if iconFile and iconFile ~= "" then
            local remaining, total = Timing(timeStarted, timeEnding, now)
            local class = Classify(buffName, iconFile, abilityId, remaining, total)
            local isVamp = (class == "vampire")

            -- Vampirisme et lycanthropie : acceptés quel que soit leur type ; les autres permanents : buffs seulement
            if isVamp or (class == "perm" and effectType ~= BUFF_EFFECT_TYPE_DEBUFF) then
                local isMundus = FileMatches(iconFile, CFG.mundusIconPatterns)
                local show
                if isVamp then show = optVamp
                elseif isMundus then show = optMundus
                else show = optOthers end

                if show then
                    local text = zo_strformat(SI_ABILITY_NAME, buffName)
                    if not isVamp and stackCount and stackCount > 1 then text = text .. " x" .. stackCount end

                    -- Vampirisme : si une minuterie existe et qu'il reste peu de temps (changement de niveau proche),
                    -- on affiche la durée et le nom prend la couleur du cooldown
                    local color, shown = CFG.permanentColor, 0
                    if isVamp and remaining > 0 then
                        shown = remaining
                        if remaining <= CFG.cooldownSeconds then color = CFG.cooldownColor end
                    end

                    list[#list + 1] = { icon = iconFile, name = text, remaining = shown,
                                        mine = true, color = color }
                end

            end
        end
    end

    -- Abonnement ESO Plus : pas un effet du jeu, on l'ajoute si le compte est abonné
    if GetOpt(key, "esoPlus") and IsESOPlusSubscriber() then
        list[#list + 1] = { icon = CFG.esoPlusIcon, name = CFG.esoPlusName, remaining = 0,
                            mine = true, color = CFG.permanentColor }
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function FillBlock(block, entries, cursorMode)
    local count = math.min(#entries, CFG.maxRows)

    for i = 1, CFG.maxRows do
        local slot = block.slots[i]
        if i <= count then
            local e = entries[i]
            slot.icon:SetTexture(e.icon)
            slot.name:SetText(e.name)
            if e.color then
                slot.name:SetColor(e.color[1], e.color[2], e.color[3], e.color[4] or 1)
            elseif block.colorOthers and not e.mine then
                slot.name:SetColor(CFG.otherColor[1], CFG.otherColor[2], CFG.otherColor[3], CFG.otherColor[4] or 1)
            else
                slot.name:SetColor(1, 1, 1, 1)
            end
            slot.dur:SetText(FormatDuration(e.remaining))
            slot.icon:SetHidden(false)
        else
            slot.icon:SetHidden(true)
        end
    end

    block.outline:SetHidden(not cursorMode)
    block.top:SetMouseEnabled(cursorMode)
    block.placeholder:SetHidden(not (cursorMode and count == 0))
    block.row:SetHidden(not cursorMode)
    if cursorMode then UpdateRowAnchor(block) end

    if count ~= block.count then
        block.count = count
        block.top:SetDimensions(S(BLOCK_W), S(math.max(MIN_H, count * ROW_STEP - CFG.rowGap)))
    end
end

------------------------------------------------------------
-- MISE À JOUR
------------------------------------------------------------
local function Update()
    -- Curseur libre (mode interface) : cadres rouges, roues dentées et menus pour pouvoir régler les blocs
    local cursorMode = SCENE_MANAGER:IsShowing("hudui")
    if not cursorMode then
        HideTip()
        CloseMenus()
    end

    -- Buffs du joueur (filtrés par les cases du menu)
    FillBlock(buffBlock, CollectBuffs(), cursorMode)

    -- Bonus longs, nourriture & boisson
    FillBlock(longBlock, CollectLong(), cursorMode)

    -- Effets permanents
    FillBlock(permBlock, CollectPermanent(), cursorMode)

    -- Debuffs de la cible
    local debuffs = {}
    if GetOpt("debuff", "showDebuffs") and DoesUnitExist("reticleover") then
        debuffs = CollectDebuffs("reticleover", CFG.onlyMine, CFG.debuffcibleColor)
    end
    FillBlock(debuffBlock, debuffs, cursorMode)

    -- Debuffs subis par toi (lancés par d'autres, donc sans filtre « mes effets »)
    local selfDebuffs = GetOpt("self", "showDebuffs") and CollectDebuffs("player", false, CFG.debuffColor) or {}
    FillBlock(selfDebuffBlock, selfDebuffs, cursorMode)
end

------------------------------------------------------------
-- COMMANDE /caracids : liste les effets actifs sur toi avec leur ID, durées et chemin de l'icône
-- (sert à remplir longIds, foodIds, permIds et lycanIds et à vérifier les ID d'Oeil de faucon et du vampirisme)
------------------------------------------------------------
SLASH_COMMANDS["/caracids"] = function()
    local now = GetFrameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local name, started, ending, _, stackCount, icon, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        local remaining = (ending and ending > 0) and (ending - now) or 0
        local total = (started and started > 0 and ending and ending > started) and (ending - started) or 0
        local tag = ""
        local class = Classify(name, icon, abilityId, remaining, total)
        if class == "vampire" then
            tag = CFG.lycanIds[abilityId] and " [LYCANTHROPIE]" or " [VAMPIRISME]"
        elseif class == "food" then tag = " [NOURRITURE]"
        elseif class == "long" then tag = " [LONG]"
        elseif class == "perm" then tag = " [PERMANENT]" end
        d(string.format("%s : %s (cumuls : %d, reste : %ds, durée totale : %ds) %s%s",
            zo_strformat(SI_ABILITY_NAME, name), tostring(abilityId), stackCount or 0,
            zo_round(remaining), zo_round(total), tostring(icon), tag))
    end
end

------------------------------------------------------------
-- COMMANDE /caracidscible : liste les effets de la cible visée (lecture après 5 secondes)
------------------------------------------------------------
SLASH_COMMANDS["/caracidscible"] = function()
    d("Vise la cible : lecture dans 5 secondes...")
    zo_callLater(function()
        if not DoesUnitExist("reticleover") then
            d("Aucune cible visée.")
            return
        end
        local now = GetFrameTimeSeconds()
        for i = 1, GetNumBuffs("reticleover") do
            local name, started, ending, _, stackCount, icon, _, effectType, _, _, abilityId, _, castByPlayer =
                GetUnitBuffInfo("reticleover", i)
            local remaining = (ending and ending > 0) and (ending - now) or 0
            d(string.format("%s : %s (type : %s, lancé par moi : %s, cumuls : %d, reste : %ds) %s",
                zo_strformat(SI_ABILITY_NAME, name), tostring(abilityId), tostring(effectType),
                tostring(castByPlayer), stackCount or 0, zo_round(remaining), tostring(icon)))
        end
    end, 5000)
end

------------------------------------------------------------
-- CHARGEMENT
------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    -- Réglages communs au compte, séparés par serveur (le profil porte le nom du serveur : EU, NA, PTS)
    acc = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, {}, GetWorldName())
    -- Réglages propres au personnage : les CharacterID sont déjà uniques d'un serveur à l'autre
    ch = ZO_SavedVars:NewCharacterIdSettings(SV_NAME, 1, nil, {})

    -- Reprise des positions de l'ancienne version (une seule fois par serveur)
    MigrateLegacyPositions()

    for _, block in ipairs(allBlocks) do
        PlaceBlock(block)
        RefreshChecks(block)
    end

    EVENT_MANAGER:RegisterForUpdate(ADDON .. "Update", CFG.updateMs, Update)
end)
