------------------------------------------------------------
-- RÉGLAGES (modifie ici)
------------------------------------------------------------
local VERSION_ADDON       = "v1.1"   -- version affichée à côté du titre (même couleur que le titre)

local TAILLE_ICONE        = 60     -- taille de l'icône de l'addon (en pixels)
local FOND_BOUTON         = false  -- true = fond noir translucide derrière l'icône
local OPACITE_FOND        = 0.8    -- opacité de départ du fond noir (0 = invisible, 1 = opaque, 0.6 = base) ; ensuite réglée avec les boutons - / +
local ICONE_MAISON        = "/esoui/art/guild/guildhistory_indexicon_guildstore_over.dds"
local COUL_TITRE          = "|cFFD700"   -- couleur du titre (doré)
local COUL_ERREUR         = "|cFF5A4A"   -- couleur des avertissements (rouge) pour rouge sombre |cFF3333 ou rose |cFF7FCD
local COUL_MENU           = ZO_NORMAL_TEXT   -- couleur des intitulés (celle des boutons du jeu)
local COUL_VENDEUR        = "|c76BCC3"   -- couleur du nom des vendeurs (turquoise clair)
local COUL_MOI            = "|c4CFF66"   -- couleur de ton propre nom dans la liste (vert)
local COUL_RECHERCHE      = "|c4CFF66"   -- couleur du joueur recherché (loupe) dans la liste (vert pour l'instant)
local COUL_NBRE           = "|cFFFFFF"   -- couleur du nombre de vendeurs à afficher (blanc)

local ICONE_LOUPE         = "/esoui/art/miscellaneous/search_icon.dds"   -- loupe de la zone de recherche
local ICONE_OR            = "/esoui/art/currency/currency_gold.dds"
local TAILLE_ICONE_OR     = 16     -- taille de l'icône d'or dans les chiffres

local ICONE_VOYANT_OK     = "/esoui/art/contacts/social_status_online.dds"   -- boule verte
local ICONE_VOYANT_KO     = "/esoui/art/contacts/social_status_dnd.dds"      -- boule rouge
local TAILLE_VOYANT       = 28     -- taille des voyants vert / rouge (pixels)
local LARGEUR_INFOBULLE_HISTO = 480   -- largeur maximale de l'infobulle du voyant (pixels) ; le texte passe à la ligne

local TEXTE_HISTO_INCOMPLET = "Historique incomplet : sans trou depuis le %s."   -- %s = date, ne pas l'enlever
local TEXTE_HISTO_AIDE = COUL_ERREUR .. "Patientez ou listez manuellement les pages de l'historique du Marchand (option guilde) pour accélérer la récupération, puis relancez l'opération. Le voyant restera rouge si les données sont manquantes sur la période : pas de marchand de guilde, guilde rejointe depuis moins de 7 jours, trou dans l'historique, etc."

local COUL_CHAMP_RECHERCHE = "FFD700"   -- couleur du nom écrit dans la zone de recherche  

local JOUR_RESET          = 2      -- jour de rotation des marchands : 0=dimanche, 1=lundi, 2=mardi...
local HEURE_RESET_UTC     = 14     -- heure de rotation en UTC (14h UTC = 16h été / 15h hiver en France)
local EVENEMENTS_PAR_IMAGE = 200   -- vitesse de la collecte (plus bas = plus fluide, plus lent)
local EVENEMENTS_PAR_IMAGE_RECHERCHE = 1500   -- vitesse de la recherche des dernières ventes

local NB_MEILLEURS_DEFAUT = 5      -- nombre de meilleurs vendeurs affichés au départ
local NB_MEILLEURS_MAX    = 10     -- maximum réglable avec les boutons - / +
local NB_LETTRES_AIDE     = 3      -- nombre de lettres tapées avant l'ouverture de la liste de propositions
local NB_PROPOSITIONS     = 8      -- nombre maximum de joueurs proposés
local LARGEUR_PROPOSITIONS = 280   -- largeur de la liste de propositions (pixels)

local TITRE_DERNIERES_VENTES = "Dernière(s) vente(s) enregistrée(s)"   -- titre de la section des objets vendus
local NB_LIGNES_VENTES    = 6      -- nombre de lignes visibles dans la section (les autres défilent)
local TEXTE_BTN_AFFICHER  = "Afficher"
local TEXTE_BTN_MASQUER   = "Masquer"
local TEXTE_STATUT_PRET   = "Prêt."   -- message affiché à l'ouverture de la fenêtre
local PRIX_EST_POUR_LE_LOT = true  -- true : le prix donné par le jeu est celui du lot entier ; false : celui d'une pièce
local LARGEUR_SEPARATEUR  = 0.7    -- largeur des lignes de séparation (0.5 = moitié du tableau, 1 = toute la largeur)
local ICONE_FLECHE_HAUT   = "/esoui/art/buttons/scrollbox_uparrow_up.dds"     -- flèche ▲ de la barre de défilement
local ICONE_FLECHE_BAS    = "/esoui/art/buttons/scrollbox_downarrow_up.dds"   -- flèche ▼ de la barre de défilement
local TAILLE_FLECHE       = 16     -- taille des flèches (pixels)

local POLICE_ENTETES      = "ZoFontGameBold"   -- police des titres de colonnes (gras)
local POLICE_STATUT       = "ZoFontGameBold"   -- police des messages d'information (gras)

local LARGEUR_TABLEAU     = 880

local TEXTE_INFO_COLLECTER = "Lance la récupération des ventes."
local TEXTE_INFO_PURGER    = "Efface les données sauvegardées, à utiliser notamment lors de la première utilisation, si les ventes ne s'affichent pas."
local TEXTE_INFO_FERMER    = "Ferme la fenêtre."

------------------------------------------------------------
-- FIN DES RÉGLAGES
------------------------------------------------------------

CaracVentes = CaracVentes or {}
local CV = CaracVentes

CV.name = "CaracVentes"
CV.MAX_GUILDES = 5
CV.tableauOuvert = false   -- toujours fermé après un /reloadui
CV.semaine = "Cur"         -- "Cur" = semaine en cours (par défaut), "Pas" = semaine passée
CV.fonds = {}              -- fonds noirs (pour régler leur opacité)
CV.nomRecherche = nil      -- joueur recherché (nil = toi)
CV.ventesOuvertes = false  -- section "Dernières ventes" affichée ?
CV.ventes = nil            -- résultats de la dernière recherche (jamais sauvegardés)
CV.defil = 0               -- décalage de défilement de la liste des ventes
CV.nbRows = 0

CV.defaults = {
    bouton  = { x = 200, y = 200 },
    fenetre = { x = 200, y = 200 },
    guildesDesactivees = {},   -- [guildId] = true si décochée
    options = { taxeDeduite = true, nbMeilleurs = NB_MEILLEURS_DEFAUT, opacite = OPACITE_FOND },
    -- Totaux seulement : [guildId] = { nom, dernierId, dernierTs, couvertDepuis, collecte,
    --   sem = { [début de semaine] = { [vendeur normalisé] = { n = nom, b = brut, t = taxe, c = nombre } } } }
    ventes = {},
}

local CASE_COCHEE  = "/esoui/art/buttons/checkbox_checked.dds"
local CASE_VIDE    = "/esoui/art/buttons/checkbox_unchecked.dds"
local LARGEUR_BARRE = LARGEUR_TABLEAU - 24

local WM = WINDOW_MANAGER
local CATEGORIE = GUILD_HISTORY_EVENT_CATEGORY_TRADER
local TYPE_VENTE = GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD

---------------------------------------------------------------
-- Outils
---------------------------------------------------------------
local function AjouterFond(parent)
    local fond = WM:CreateControl(nil, parent, CT_BACKDROP)
    fond:SetAnchorFill(parent)
    fond:SetCenterColor(0, 0, 0, (CV.sv and CV.sv.options.opacite) or OPACITE_FOND)
    fond:SetEdgeColor(0, 0, 0, 0)
    CV.fonds[#CV.fonds + 1] = fond
    return fond
end

-- cadre de la même couleur que les titres et les boutons
local function AjouterCadre(fond)
    fond:SetEdgeTexture(nil, 2, 2, 2, 2)
    fond:SetEdgeColor(COUL_MENU:UnpackRGBA())
end

local function CreerLabel(nom, parent, police, texte, x, y, largeur, hauteur)
    local l = WM:CreateControl(nom, parent, CT_LABEL)
    l:SetFont(police)
    l:SetText(texte or "")
    l:SetColor(1, 1, 1, 1)
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    if largeur then l:SetDimensions(largeur, hauteur or 24) end
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return l
end

-- case à cocher avec son texte (cliquer sur le texte fonctionne aussi)
local function CreerCaseACocher(nom, parent, texte, action)
    local b = WM:CreateControl(nom, parent, CT_BUTTON)
    b:SetDimensions(24, 24)
    b:SetNormalTexture(CASE_VIDE)
    b:SetHandler("OnClicked", action)

    local l = WM:CreateControl(nom .. "Texte", parent, CT_LABEL)
    l:SetFont("ZoFontGame")
    l:SetColor(COUL_MENU:UnpackRGBA())
    l:SetText(texte)
    l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    l:SetDimensions(l:GetTextWidth() + 4, 24)
    l:SetMouseEnabled(true)
    l:SetHandler("OnMouseUp", function(_, bouton, dansLeBloc)
        if bouton == MOUSE_BUTTON_INDEX_LEFT and dansLeBloc then action() end
    end)
    return b, l
end

-- place une case et son texte à la position x
local function PlacerCase(b, l, x, y)
    local parent = b:GetParent()
    b:ClearAnchors()
    b:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    l:ClearAnchors()
    l:SetAnchor(TOPLEFT, parent, TOPLEFT, x + 28, y)
end

local function DefinirCase(bouton, coche)
    bouton:SetNormalTexture(coche and CASE_COCHEE or CASE_VIDE)
end

local function SauverPosition(ctrl, cle)
    CV.sv[cle].x = ctrl:GetLeft()
    CV.sv[cle].y = ctrl:GetTop()
end

local function CreerBlocDeplacable(nom, largeur, hauteur, cle, avecFond, avecCadre)
    local c = WM:CreateTopLevelWindow(nom)
    c:SetDimensions(largeur, hauteur)
    c:SetClampedToScreen(true)
    c:SetMovable(true)
    c:SetMouseEnabled(true)
    c:SetHidden(true)
    c:ClearAnchors()
    c:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, CV.sv[cle].x, CV.sv[cle].y)
    c:SetHandler("OnMoveStop", function() SauverPosition(c, cle) end)
    if avecFond then
        local fond = AjouterFond(c)
        if avecCadre then AjouterCadre(fond) end
    end
    return c
end

-- Fragment maison : affiche le contrôle sur l'écran de jeu seulement si
-- estAffiche() renvoie true (évite que le jeu rouvre la fenêtre tout seul).
local FragmentCV = ZO_SceneFragment:Subclass()

function FragmentCV:Initialize(ctrl, estAffiche)
    ZO_SceneFragment.Initialize(self)
    self.ctrl = ctrl
    self.estAffiche = estAffiche
end

function FragmentCV:Show()
    self.ctrl:SetHidden(not self.estAffiche())
    self:OnShown()
end

function FragmentCV:Hide()
    self.ctrl:SetHidden(true)
    self:OnHidden()
end

local function AfficherSurHUD(ctrl, estAffiche)
    local fragment = FragmentCV:New(ctrl, estAffiche)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

-- Format "1 234 567" + icône d'or
local function FormaterOr(n)
    return ZO_CommaDelimitNumber(math.floor(n + 0.5)) .. " |t" ..
        TAILLE_ICONE_OR .. ":" .. TAILLE_ICONE_OR .. ":" .. ICONE_OR .. "|t"
end

-- compare les pseudos sans "@", espaces ni majuscules
local function Normaliser(nom)
    local s = string.lower(tostring(nom or ""))
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    s = string.gsub(s, "^@", "")
    return s
end

-- Début (secondes UTC) de la semaine de marchand qui contient l'instant t
local function DebutSemaineDe(t)
    local jours = math.floor(t / 86400)
    -- le 1er janvier 1970 était un jeudi (4, avec dimanche = 0)
    local joursDepuis = (jours + 4 - JOUR_RESET) % 7
    local debut = (jours - joursDepuis) * 86400 + HEURE_RESET_UTC * 3600
    if debut > t then debut = debut - 7 * 86400 end
    return debut
end

-- Début de la semaine en cours et de la semaine passée
local function DebutsDePeriode()
    local cur = DebutSemaineDe(GetTimeStamp())
    return cur, cur - 7 * 86400
end

local function DateLisible(ts)
    return os.date("!%d/%m/%Y %H:%M UTC", ts)
end

-- ajoute une vente aux totaux : semaines[début de semaine][vendeur] = { n, b, t, c }
local function Agreger(semaines, ts, vendeur, prix, taxe)
    local debut = DebutSemaineDe(ts)
    local s = semaines[debut]
    if not s then
        s = {}
        semaines[debut] = s
    end
    local cle = Normaliser(vendeur)
    local e = s[cle]
    if not e then
        e = { n = tostring(vendeur), b = 0, t = 0, c = 0 }
        s[cle] = e
    end
    e.b = e.b + prix
    e.t = e.t + taxe
    e.c = e.c + 1
end

-- fusionne les totaux src dans dest
local function FusionnerSemaines(dest, src)
    for debut, vendeurs in pairs(src) do
        local d = dest[debut]
        if not d then
            d = {}
            dest[debut] = d
        end
        for cle, e in pairs(vendeurs) do
            local x = d[cle]
            if not x then
                d[cle] = { n = e.n, b = e.b, t = e.t, c = e.c }
            else
                x.b, x.t, x.c = x.b + e.b, x.t + e.t, x.c + e.c
            end
        end
    end
end

---------------------------------------------------------------
-- Bloc "bouton" (icône de l'addon)
---------------------------------------------------------------
function CV:CreerBouton()
    local c = CreerBlocDeplacable("CaracVentesBouton", TAILLE_ICONE + 12, TAILLE_ICONE + 12, "bouton", FOND_BOUTON)
    self.bouton = c

    local icone = WM:CreateControl("CaracVentesBoutonIcone", c, CT_TEXTURE)
    icone:SetDimensions(TAILLE_ICONE, TAILLE_ICONE)
    icone:SetAnchor(CENTER, c, CENTER, 0, 0)
    icone:SetTexture(ICONE_MAISON)

    -- infobulle : nom de l'addon
    local fondTip = WM:CreateControl("CaracVentesBoutonInfobulle", c, CT_BACKDROP)
    fondTip:SetCenterColor(0, 0, 0, 1)
    AjouterCadre(fondTip)
    fondTip:SetDrawTier(DT_HIGH)
    fondTip:SetDrawLayer(DL_OVERLAY)
    fondTip:SetHidden(true)

    local texteTip = WM:CreateControl("CaracVentesBoutonInfobulleTexte", fondTip, CT_LABEL)
    texteTip:SetFont("ZoFontGame")
    texteTip:SetColor(COUL_MENU:UnpackRGBA())
    texteTip:SetText("CaracVentes")
    texteTip:SetAnchor(CENTER, fondTip, CENTER, 0, 0)
    texteTip:SetDrawTier(DT_HIGH)
    texteTip:SetDrawLayer(DL_OVERLAY)

    fondTip:SetDimensions(texteTip:GetTextWidth() + 20, 28)
    fondTip:SetAnchor(CENTER, c, CENTER, 0, 0)
    self.infobulleBouton = fondTip

    c:SetHandler("OnMouseEnter", function() fondTip:SetHidden(false) end)
    c:SetHandler("OnMouseExit",  function() fondTip:SetHidden(true) end)

    -- tout le bloc est cliquable ; un glisser (déplacement) n'ouvre pas le tableau
    c:SetHandler("OnMouseDown", function()
        c.departX, c.departY = c:GetLeft(), c:GetTop()
    end)
    c:SetHandler("OnMouseUp", function(_, bouton, dansLeBloc)
        if bouton == MOUSE_BUTTON_INDEX_LEFT and dansLeBloc
            and c:GetLeft() == c.departX and c:GetTop() == c.departY then
            CV:OuvrirTableau()
        end
    end)

    AfficherSurHUD(c, function() return not CV.tableauOuvert end)
    c:SetHidden(CV.tableauOuvert)
end

---------------------------------------------------------------
-- Tableau
---------------------------------------------------------------
local COLONNES = {
    -- { clé, titre, x, largeur }
    { "nom",   "Guilde(s)",    44,  190 },
    { "moi",   "Ventes",       250, 160 },
    { "gui",   "Total guilde", 420, 160 },
    { "gains", "Gains Guilde", 590, 160 },
    { "histo", "Historique",   760, 100 },
}

local CLES_CHIFFRES = { "moi", "gui", "gains" }

-- colonnes de la section "Dernières ventes" : { clé, titre, x, largeur }
local COLONNES_VENTES = {
    { "article", "Article",    54,  300 },
    { "unite",   "Prix/pièce", 360, 150 },
    { "total",   "Prix total", 520, 160 },
    { "acheteur", "Acheteur",  700, 150 },
}

function CV:ChoisirSemaine(code)
    self.semaine = code
    self:FermerVentes()
    DefinirCase(self.caseCur, code == "Cur")
    DefinirCase(self.casePas, code == "Pas")
    self:RafraichirGuildes()
end

function CV:BasculerTaxe()
    self.sv.options.taxeDeduite = not self.sv.options.taxeDeduite
    DefinirCase(self.caseTaxe, self.sv.options.taxeDeduite)
    self:RafraichirGuildes()
end

local function CreerSeparateur(nom, parent)
    local t = WM:CreateControl(nom, parent, CT_TEXTURE)
    local r, g, b = COUL_MENU:UnpackRGBA()
    t:SetColor(r, g, b, 0.6)
    t:SetDimensions(math.floor(LARGEUR_TABLEAU * LARGEUR_SEPARATEUR), 2)   -- 2 px au lieu de 1
    t:SetDrawLevel(10)
    t:SetHidden(true)
    return t
end

function CV:CreerTableau()
    local c = CreerBlocDeplacable("CaracVentesTableau", LARGEUR_TABLEAU, 500, "fenetre", true, true)
    self.tableau = c

    -- ligne du titre : titre, case "taxes déduites", choix de la semaine
    local titre = CreerLabel("CaracVentesTableauTitre", c, "ZoFontWinH3",
        COUL_TITRE .. "CaracVentes|r", 12, 8, 170, 26)
    local version = CreerLabel("CaracVentesTableauVersion", c, "ZoFontGame",
        COUL_TITRE .. VERSION_ADDON .. "|r", 12 + titre:GetTextWidth() + 8, 8, 70, 26)

    local bT, lT = CreerCaseACocher("CaracVentesCaseTaxe", c, "Ventes taxes déduites",
        function() CV:BasculerTaxe() end)
    local bC, lC = CreerCaseACocher("CaracVentesCaseCur", c, "Semaine en cours",
        function() CV:ChoisirSemaine("Cur") end)
    local bP, lP = CreerCaseACocher("CaracVentesCasePas", c, "Semaine passée",
        function() CV:ChoisirSemaine("Pas") end)
    self.caseTaxe, self.caseCur, self.casePas = bT, bC, bP

    -- les trois cases sont centrées dans l'espace à droite du titre
    local ECART = 40   -- espace entre deux cases (pixels)
    local largeurs = { 28 + lT:GetWidth(), 28 + lC:GetWidth(), 28 + lP:GetWidth() }
    local total = largeurs[1] + largeurs[2] + largeurs[3] + 2 * ECART
    local zoneDebut = 12 + titre:GetTextWidth() + 8 + version:GetTextWidth() + 20
    local zoneFin = LARGEUR_TABLEAU - 12
    local x = zoneDebut + math.floor((zoneFin - zoneDebut - total) / 2)
    PlacerCase(bT, lT, x, 9)
    x = x + largeurs[1] + ECART
    PlacerCase(bC, lC, x, 9)
    x = x + largeurs[2] + ECART
    PlacerCase(bP, lP, x, 9)

    DefinirCase(bT, self.sv.options.taxeDeduite)
    DefinirCase(bC, self.semaine == "Cur")
    DefinirCase(bP, self.semaine == "Pas")

    -- en-têtes du tableau des guildes
    for _, col in ipairs(COLONNES) do
        local cle, titre, x, largeur = col[1], col[2], col[3], col[4]
        local l = CreerLabel("CaracVentesEntete_" .. cle, c, POLICE_ENTETES, titre, x, 47, largeur, 22)
        l:SetColor(COUL_MENU:UnpackRGBA())
        if cle ~= "nom" then l:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    end

    -- lignes (5 guildes maximum)
    self.lignes = {}
    for i = 1, self.MAX_GUILDES do
        local y = 80 + (i - 1) * 30
        local ligne = {}

        local cb = WM:CreateControl("CaracVentesCase" .. i, c, CT_BUTTON)
        cb:SetDimensions(24, 24)
        cb:SetAnchor(TOPLEFT, c, TOPLEFT, 12, y)
        cb:SetNormalTexture(CASE_COCHEE)
        cb:SetHandler("OnClicked", function() CV:BasculerGuilde(i) end)
        ligne.case = cb

        for _, col in ipairs(COLONNES) do
            local cle, x, largeur = col[1], col[3], col[4]
            if cle == "histo" then
                -- voyant vert / rouge avec infobulle
                local v = WM:CreateControl("CaracVentesVoyant" .. i, c, CT_BUTTON)
                v:SetDimensions(TAILLE_VOYANT, TAILLE_VOYANT)
                v:SetAnchor(TOPLEFT, c, TOPLEFT, x + (largeur - TAILLE_VOYANT) / 2, y + 12 - TAILLE_VOYANT / 2)
                v:SetMouseEnabled(true)
                v:SetHidden(true)
                v:SetHandler("OnMouseEnter", function() CV:AfficherInfobulle(v, ligne.texteHisto) end)
                v:SetHandler("OnMouseExit",  function() CV:CacherInfobulle() end)
                ligne.voyant = v
            else
                local l = CreerLabel("CaracVentes_" .. cle .. i, c, "ZoFontGame", "", x, y, largeur, 24)
                if cle ~= "nom" then l:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
                ligne[cle] = l
            end
        end
        self.lignes[i] = ligne
    end

    -- ligne Total : seulement dans la colonne "Ventes"
    local xMoi, largeurMoi
    for _, col in ipairs(COLONNES) do
        if col[1] == "moi" then xMoi, largeurMoi = col[3], col[4] end
    end
    self.xMoi, self.xTraitTotal = xMoi, xMoi + largeurMoi - 120

    self.totalTrait = WM:CreateControl("CaracVentesTotalTrait", c, CT_TEXTURE)
    self.totalTrait:SetColor(COUL_MENU:UnpackRGBA())
    self.totalTrait:SetDimensions(120, 2)
    self.totalTrait:SetHidden(true)

    self.totalNom = CreerLabel("CaracVentesTotalNom", c, "ZoFontGameBold", "Total", 44, 234, 190, 24)
    self.totalNom:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.totalNom:SetColor(COUL_MENU:UnpackRGBA())
    self.totalNom:SetHidden(true)

    self.totalValeur = CreerLabel("CaracVentesTotalValeur", c, "ZoFontGame", "", xMoi, 234, largeurMoi, 24)
    self.totalValeur:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.totalValeur:SetHidden(true)

    -- lignes de séparation entre les rubriques
    self.sep1 = CreerSeparateur("CaracVentesSeparateur1", c)
    self.sep2 = CreerSeparateur("CaracVentesSeparateur2", c)

    -- section "Dernières ventes" : titre centré + bouton
    self.ventesTitre = CreerLabel("CaracVentesVentesTitre", c, "ZoFontGameBold",
        TITRE_DERNIERES_VENTES, 12, 0, LARGEUR_TABLEAU - 24, 28)
    self.ventesTitre:SetColor(COUL_MENU:UnpackRGBA())
    self.ventesTitre:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    self.btnVentes = WM:CreateControlFromVirtual("CaracVentesBtnVentes", c, "ZO_DefaultButton")
    self.btnVentes:SetText(TEXTE_BTN_AFFICHER)
    self.btnVentes:SetDimensions(140, 28)
    self.btnVentes:SetHandler("OnClicked", function() CV:BasculerVentes() end)

    -- en-têtes des colonnes des ventes
    self.entetesVentes = {}
    for _, col in ipairs(COLONNES_VENTES) do
        local l = CreerLabel("CaracVentesEnteteVentes_" .. col[1], c, POLICE_ENTETES, col[2], 0, 0, col[4], 24)
        l:SetColor(COUL_MENU:UnpackRGBA())
        if col[1] ~= "article" and col[1] ~= "acheteur" then l:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
        l:SetHidden(true)
        self.entetesVentes[#self.entetesVentes + 1] = l
    end

    -- zone des lignes de ventes (reçoit la molette de la souris)
    local zone = WM:CreateControl("CaracVentesZoneVentes", c, CT_CONTROL)
    zone:SetDimensions(LARGEUR_TABLEAU, NB_LIGNES_VENTES * 30)
    zone:SetMouseEnabled(true)
    zone:SetHidden(true)
    zone:SetHandler("OnMouseWheel", function(_, delta) CV:Defiler(-delta) end)
    self.zoneVentes = zone

    self.lignesVentes = {}
    for k = 1, NB_LIGNES_VENTES do
        local y = (k - 1) * 30
        local L = {}
        L.icone = WM:CreateControl("CaracVentesVenteIcone" .. k, zone, CT_TEXTURE)
        L.icone:SetDimensions(28, 28)
        L.icone:SetAnchor(TOPLEFT, zone, TOPLEFT, 20, y + 1)

        L.qte = WM:CreateControl("CaracVentesVenteQte" .. k, zone, CT_LABEL)
        L.qte:SetFont("ZoFontGameBold")
        L.qte:SetColor(1, 1, 1, 1)
        L.qte:SetAnchor(BOTTOMRIGHT, L.icone, BOTTOMRIGHT, 2, 2)
        L.qte:SetDrawLevel(10)

-- zone de survol : icône + nom ; affiche la fiche de l'objet
        L.survol = WM:CreateControl("CaracVentesVenteSurvol" .. k, zone, CT_BUTTON)
        L.survol:SetDimensions(COLONNES_VENTES[1][3] + COLONNES_VENTES[1][4] - 20, 30)
        L.survol:SetAnchor(TOPLEFT, zone, TOPLEFT, 20, y)
        L.survol:SetHandler("OnMouseEnter", function()
            if L.lien then
                InitializeTooltip(ItemTooltip, L.survol, LEFT, 10, 0, RIGHT)
                ItemTooltip:SetLink(L.lien)
            end
        end)
        L.survol:SetHandler("OnMouseExit", function() ClearTooltip(ItemTooltip) end)
        L.survol:SetHandler("OnMouseWheel", function(_, delta) CV:Defiler(-delta) end)

        local function Texte(cle, x, largeur, droite)
            local l = CreerLabel("CaracVentesVente_" .. cle .. k, zone, "ZoFontGame", "", x, y, largeur, 30)
            if droite then l:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
            return l
        end
        L.nom      = Texte("nom",      COLONNES_VENTES[1][3], COLONNES_VENTES[1][4], false)
        L.unite    = Texte("unite",    COLONNES_VENTES[2][3], COLONNES_VENTES[2][4], true)
        L.total    = Texte("total",    COLONNES_VENTES[3][3], COLONNES_VENTES[3][4], true)
        L.acheteur = Texte("acheteur", COLONNES_VENTES[4][3], COLONNES_VENTES[4][4], false)
        self.lignesVentes[k] = L
    end

    -- barre de défilement (piste + curseur, purement visuels)
    self.pisteVentes = WM:CreateControl("CaracVentesPiste", zone, CT_TEXTURE)
    self.pisteVentes:SetColor(0.25, 0.25, 0.25, 0.9)
    self.pisteVentes:SetDimensions(8, NB_LIGNES_VENTES * 30)
    self.pisteVentes:SetAnchor(TOPRIGHT, zone, TOPRIGHT, -14, 0)

    self.curseurVentes = WM:CreateControl("CaracVentesCurseur", zone, CT_TEXTURE)
    self.curseurVentes:SetColor(COUL_MENU:UnpackRGBA())
    self.curseurVentes:SetDimensions(8, 20)
    self.curseurVentes:SetDrawLevel(5)

    -- zone cliquable plus large, invisible, posée par-dessus la barre
    local prise = WM:CreateControl("CaracVentesPrise", zone, CT_CONTROL)
    prise:SetDimensions(24, NB_LIGNES_VENTES * 30)
    prise:SetAnchor(TOPRIGHT, zone, TOPRIGHT, -6, 0)
    prise:SetDrawLevel(20)
    prise:SetMouseEnabled(true)
    prise:SetHandler("OnMouseDown", function(_, bouton)
        if bouton == MOUSE_BUTTON_INDEX_LEFT then
            CV:ClicPiste()
            CV:DebutGlisse()
        end
    end)
    prise:SetHandler("OnMouseUp", function() CV.glisse = false end)
    prise:SetHandler("OnMouseWheel", function(_, delta) CV:Defiler(-delta) end)
    self.priseVentes = prise

    -- flèches ▲ et ▼ aux deux extrémités de la barre de défilement
    local function CreerFleche(nom, icone, delta)
        local b = WM:CreateControl(nom, zone, CT_BUTTON)
        b:SetDimensions(TAILLE_FLECHE, TAILLE_FLECHE)
        b:SetNormalTexture(icone)
        b:SetMouseOverTexture((string.gsub(icone, "_up%.dds$", "_over.dds")))
        b:SetHandler("OnClicked", function() CV:Defiler(delta) end)
        return b
    end
    self.flecheHaut = CreerFleche("CaracVentesFlecheHaut", ICONE_FLECHE_HAUT, -1)
    self.flecheHaut:SetAnchor(BOTTOMRIGHT, zone, TOPRIGHT, -10, -2)
    self.flecheBas = CreerFleche("CaracVentesFlecheBas", ICONE_FLECHE_BAS, 1)
    self.flecheBas:SetAnchor(TOPRIGHT, zone, BOTTOMRIGHT, -10, 2)

    -- meilleurs vendeurs : titre, texte, boutons - / + et lignes
    self.meilleursTitre = CreerLabel("CaracVentesMeilleursTitre", c, "ZoFontGameBold", "", 12, 0, 420, 26)
    self.meilleursTitre:SetHorizontalAlignment(TEXT_ALIGN_LEFT)

    local function BoutonNombre(nom, texte, delta)
        local b = WM:CreateControlFromVirtual("CaracVentesBtn" .. nom, c, "ZO_DefaultButton")
        b:SetText(texte)
        b:SetDimensions(30, 26)
        b:SetHandler("OnClicked", function() CV:ChangerNbMeilleurs(delta) end)
        return b
    end
    self.btnMoins = BoutonNombre("Moins", "-", -1)
    self.btnPlus  = BoutonNombre("Plus",  "+", 1)

    self.meilleursNombre = CreerLabel("CaracVentesMeilleursNombre", c, "ZoFontGame",
        "Nombre de vendeur(s) :", 0, 0)
    self.meilleursNombre:SetColor(COUL_MENU:UnpackRGBA())

    -- une ligne = un contrôle (25 lignes au maximum)
    self.meilleursLignes = {}
    for k = 1, 25 do
        local l = CreerLabel("CaracVentesMeilleurs" .. k, c, "ZoFontGame", "", 12, 0, LARGEUR_TABLEAU - 24, 24)
        l:SetHidden(true)
        self.meilleursLignes[k] = l
    end

    -- contrôle invisible servant à mesurer la largeur des textes
    local mesure = CreerLabel("CaracVentesMesure", c, "ZoFontGame", "", 0, 0)
    mesure:SetAlpha(0)
    self.mesure = mesure

    -- barre de progression (visible seulement pendant une opération)
    local fondBarre = WM:CreateControl("CaracVentesBarreFond", c, CT_BACKDROP)
    fondBarre:SetDimensions(LARGEUR_BARRE, 10)
    fondBarre:SetCenterColor(0.15, 0.15, 0.15, 0.9)
    fondBarre:SetEdgeColor(0, 0, 0, 0)
    fondBarre:SetHidden(true)

    local barre = WM:CreateControl("CaracVentesBarre", c, CT_TEXTURE)
    barre:SetColor(0.9, 0.75, 0.2, 1)
    barre:SetAnchor(TOPLEFT, fondBarre, TOPLEFT, 0, 0)
    barre:SetDimensions(1, 10)
    barre:SetHidden(true)
    self.fondBarre, self.barre = fondBarre, barre

    -- message d'information
    self.statut = CreerLabel("CaracVentesStatut", c, POLICE_STATUT, TEXTE_STATUT_PRET, 12, 0, LARGEUR_TABLEAU - 24, 50)
    self.statut:SetVerticalAlignment(TEXT_ALIGN_TOP)

    -- boutons
    local function Bouton(nom, texte, x, action, info, position)
        local b = WM:CreateControlFromVirtual("CaracVentesBtn" .. nom, c, "ZO_DefaultButton")
        b:SetText(texte)
        b:SetDimensions(150, 28)
        b:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, x, -14)
        b:SetHandler("OnClicked", action)
        -- on ajoute l'infobulle sans remplacer l'effet de survol du bouton
        ZO_PostHookHandler(b, "OnMouseEnter", function() CV:AfficherInfobulle(b, info, position) end)
        ZO_PostHookHandler(b, "OnMouseExit",  function() CV:CacherInfobulle() end)
        return b
    end
    Bouton("Collecter", "Collecter", 12,  function() CV:Collecter() end,
        TEXTE_INFO_COLLECTER, "haut-gauche")
    Bouton("Purger",    "Purger",    175, function() CV:Purger() end,
        TEXTE_INFO_PURGER, "haut-gauche")
    Bouton("Fermer",    "Fermer",    LARGEUR_TABLEAU - 12 - 150, function() CV:FermerTableau() end,
        TEXTE_INFO_FERMER, "haut-droite")

    -- recherche d'un joueur : loupe + zone de texte (vide ou ton nom = tes ventes)
    local loupe = WM:CreateControl("CaracVentesLoupe", c, CT_TEXTURE)
    loupe:SetDimensions(24, 24)
    loupe:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 340, -16)
    loupe:SetTexture(ICONE_LOUPE)

    local fondRech = WM:CreateControl("CaracVentesRechercheFond", c, CT_BACKDROP)
    fondRech:SetDimensions(210, 28)
    fondRech:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 370, -14)
    fondRech:SetCenterColor(0.15, 0.15, 0.15, 1)
    fondRech:SetEdgeColor(0, 0, 0, 0)

    local edit = WM:CreateControl("CaracVentesRecherche", fondRech, CT_EDITBOX)
    edit:SetAnchor(TOPLEFT, fondRech, TOPLEFT, 6, 3)
    edit:SetAnchor(BOTTOMRIGHT, fondRech, BOTTOMRIGHT, -6, -3)
    edit:SetFont("ZoFontGame")
    edit:SetColor(ZO_ColorDef:New(COUL_CHAMP_RECHERCHE):UnpackRGBA()) -- ou edit:SetColor(unpack(COUL_CHAMP_RECHERCHE)) si rgbo   
    edit:SetMaxInputChars(40)
    edit:SetMouseEnabled(true)
    edit:SetText((string.gsub(GetDisplayName(), "^@", "")))
    edit:SetHandler("OnMouseDown", function() edit:TakeFocus() end)
    edit:SetHandler("OnTextChanged", function()
        local t = edit:GetText()
        CV:RechercheModifiee(t)
        if Normaliser(t) == CV.texteAuto then return end   -- texte mis par l'addon lui-même
        CV.texteAuto = nil
        CV:MettreAJourPropositions(t)
    end)
    edit:SetHandler("OnEnter", function() edit:LoseFocus() CV:FermerPropositions() end)
    edit:SetHandler("OnFocusLost", function()
        CV:RestaurerNomSiVide()
        zo_callLater(function() CV:FermerPropositions() end, 250)
    end)
    edit:SetHandler("OnEscape", function() edit:LoseFocus() CV:FermerPropositions() end)
    self.nomRecherche = edit:GetText()
    self.editRecherche = edit

    -- aide à la saisie : liste de propositions qui s'ouvre au-dessus de la zone de recherche
    local fondProp = WM:CreateControl("CaracVentesPropositions", c, CT_BACKDROP)
    fondProp:SetCenterColor(0, 0, 0, 1)
    AjouterCadre(fondProp)
    fondProp:SetDrawTier(DT_HIGH)
    fondProp:SetDrawLayer(DL_OVERLAY)
    fondProp:SetDrawLevel(300)
    fondProp:SetAnchor(BOTTOMLEFT, fondRech, TOPLEFT, 0, -2)
    fondProp:SetHidden(true)
    self.fondPropositions = fondProp

    self.lignesPropositions = {}
    for k = 1, NB_PROPOSITIONS do
        local l = WM:CreateControl("CaracVentesProposition" .. k, fondProp, CT_LABEL)
        l:SetFont("ZoFontGame")
        l:SetColor(COUL_MENU:UnpackRGBA())
        l:SetDimensions(LARGEUR_PROPOSITIONS - 12, 24)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        l:SetAnchor(TOPLEFT, fondProp, TOPLEFT, 6, 4 + (k - 1) * 24)
        l:SetDrawTier(DT_HIGH)
        l:SetDrawLayer(DL_OVERLAY)
        l:SetDrawLevel(301)
        l:SetMouseEnabled(true)
        l:SetHandler("OnMouseEnter", function() l:SetColor(1, 1, 1, 1) end)
        l:SetHandler("OnMouseExit",  function() l:SetColor(COUL_MENU:UnpackRGBA()) end)
        l:SetHandler("OnMouseDown",  function() CV:ChoisirProposition(l.nomJoueur) end)
        l:SetHidden(true)
        self.lignesPropositions[k] = l
    end

    -- opacité du fond : - / +
    local etiquetteFond = CreerLabel("CaracVentesFondTexte", c, "ZoFontGame", "Fond", 592, 0, 44, 28)
    etiquetteFond:ClearAnchors()
    etiquetteFond:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, 592, -14)
    etiquetteFond:SetColor(COUL_MENU:UnpackRGBA())
    local function BoutonOpacite(nom, texte, x, delta)
        local b = WM:CreateControlFromVirtual("CaracVentesBtn" .. nom, c, "ZO_DefaultButton")
        b:SetText(texte)
        b:SetDimensions(30, 28)
        b:SetAnchor(BOTTOMLEFT, c, BOTTOMLEFT, x, -14)
        b:SetHandler("OnClicked", function() CV:ChangerOpacite(delta) end)
    end
    BoutonOpacite("OpaciteMoins", "-", 640, -0.1)
    BoutonOpacite("OpacitePlus",  "+", 674, 0.1)

    -- infobulle maison de l'historique (créée en dernier pour s'afficher au-dessus du reste)
    local fondInfo = WM:CreateControl("CaracVentesInfobulle", c, CT_BACKDROP)
    fondInfo:SetCenterColor(0, 0, 0, 1)
    AjouterCadre(fondInfo)
    fondInfo:SetDrawTier(DT_HIGH)
    fondInfo:SetDrawLayer(DL_OVERLAY)
    fondInfo:SetDrawLevel(200)
    fondInfo:SetHidden(true)

    local texteInfo = WM:CreateControl("CaracVentesInfobulleTexte", fondInfo, CT_LABEL)
    texteInfo:SetFont("ZoFontGameBold")
    texteInfo:SetDimensionConstraints(0, 0, LARGEUR_INFOBULLE_HISTO - 20, 0)
    texteInfo:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    texteInfo:SetColor(COUL_MENU:UnpackRGBA())
    texteInfo:SetAnchor(CENTER, fondInfo, CENTER, 0, 0)
    texteInfo:SetDrawLevel(201)
    texteInfo:SetDrawTier(DT_HIGH)
    texteInfo:SetDrawLayer(DL_OVERLAY)

    self.infobulle, self.infobulleTexte = fondInfo, texteInfo

    AfficherSurHUD(c, function() return CV.tableauOuvert end)
end

-- position : nil = à gauche de la cible ; "haut-gauche" / "haut-droite" = au-dessus de la cible
function CV:AfficherInfobulle(cible, texte, position)
    if not texte then return end
    local t = self.infobulleTexte
    t:SetText(texte)
    local largeur, hauteur = t:GetTextDimensions()
    self.infobulle:SetDimensions(largeur + 20, hauteur + 14)
    self.infobulle:ClearAnchors()
    if position == "haut-gauche" then
        self.infobulle:SetAnchor(BOTTOMLEFT, cible, TOPLEFT, 0, -6)
    elseif position == "haut-droite" then
        self.infobulle:SetAnchor(BOTTOMRIGHT, cible, TOPRIGHT, 0, -6)
    else
        self.infobulle:SetAnchor(RIGHT, cible, LEFT, -8, 0)
    end
    self.infobulle:SetHidden(false)
end

function CV:CacherInfobulle()
    if self.infobulle then self.infobulle:SetHidden(true) end
end

function CV:DefinirProgression(fraction)
    if fraction == nil then
        self.fondBarre:SetHidden(true)
        self.barre:SetHidden(true)
        return
    end
    fraction = math.max(0, math.min(1, fraction))
    self.fondBarre:SetHidden(false)
    self.barre:SetHidden(false)
    self.barre:SetDimensions(math.max(1, LARGEUR_BARRE * fraction), 10)
end

---------------------------------------------------------------
-- Calculs à partir des totaux sauvegardés
---------------------------------------------------------------
function CV:Stats(guildId)
    local rec = self.sv.ventes[guildId]
    if not rec or not rec.sem then return nil end
    local cur, pas = DebutsDePeriode()
    local cible = self:JoueurCible()

    local s = {}
    for code, debut in pairs({ Cur = cur, Pas = pas }) do
        local p = { moiBrut = 0, moiTaxe = 0, guiBrut = 0, guiTaxe = 0 }
        local semaine = rec.sem[debut]
        if semaine then
            for _, e in pairs(semaine) do
                p.guiBrut = p.guiBrut + e.b
                p.guiTaxe = p.guiTaxe + e.t
            end
            local moi = semaine[cible]
            if moi then
                p.moiBrut, p.moiTaxe = moi.b, moi.t
            end
        end
        s[code] = p
    end
    return s
end

-- Classement des vendeurs d'une guilde pour la semaine affichée
function CV:Classement(guildId)
    local rec = self.sv.ventes[guildId]
    if not rec or not rec.sem then return nil end
    local cur, pas = DebutsDePeriode()
    local semaine = rec.sem[(self.semaine == "Cur") and cur or pas]
    local deduite = self.sv.options.taxeDeduite

    local liste = {}
    if semaine then
        for _, e in pairs(semaine) do
            liste[#liste + 1] = { nom = e.n, total = deduite and (e.b - e.t) or e.b }
        end
    end
    table.sort(liste, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.nom < b.nom
    end)
    return liste
end

-- texte de l'infobulle et état du voyant pour une guilde
function CV:EtatHistorique(guildId)
    local rec = self.sv.ventes[guildId]
    if not rec or not rec.collecte then return nil end   -- jamais collecté
    local cur, pas = DebutsDePeriode()
    local debut = (self.semaine == "Cur") and cur or pas

    if rec.couvertDepuis and rec.couvertDepuis <= debut then
        return true, "Historique complet."
    end
    local depuis = rec.couvertDepuis and DateLisible(rec.couvertDepuis) or "une date inconnue"
    return false, string.format(TEXTE_HISTO_INCOMPLET, depuis) .. "\n\n" .. TEXTE_HISTO_AIDE
end

-- joueur dont on affiche les ventes (zone de recherche ; vide = toi)
function CV:JoueurCible()
    local t = self.nomRecherche
    if t and Normaliser(t) ~= "" then return Normaliser(t) end
    return Normaliser(GetDisplayName())
end

function CV:RechercheModifiee(texte)
    self.nomRecherche = texte
    self:FermerVentes()
    if self.lignes then self:RafraichirGuildes() end
end

function CV:RestaurerNomSiVide()
    if Normaliser(self.editRecherche:GetText()) == "" then
        self:ReinitialiserRecherche()
    end
end

-- remet ton propre nom dans la zone de recherche
function CV:ReinitialiserRecherche()
    local nom = (string.gsub(GetDisplayName(), "^@", ""))
    self.texteAuto = Normaliser(nom)
    self.editRecherche:SetText(nom)
    self.nomRecherche = nom
    self:FermerPropositions()
    if self.lignes then self:RafraichirGuildes() end
end

function CV:FermerPropositions()
    if self.fondPropositions then self.fondPropositions:SetHidden(true) end
end

-- propose les vendeurs dont le nom contient le texte tapé (du plus gros vendeur au plus petit)
function CV:MettreAJourPropositions(texte)
    local motif = Normaliser(texte)
    if string.len(motif) < NB_LETTRES_AIDE then
        self:FermerPropositions()
        return
    end

    local cumul, liste = {}, {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if not self.sv.guildesDesactivees[guildId] then
            for _, v in ipairs(self:Classement(guildId) or {}) do
                local cle = Normaliser(v.nom)
                if string.find(cle, motif, 1, true) then
                    local t = cumul[cle]
                    if not t then
                        t = { nom = v.nom, total = 0 }
                        cumul[cle] = t
                        liste[#liste + 1] = t
                    end
                    t.total = t.total + v.total
                end
            end
        end
    end

    table.sort(liste, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return a.nom < b.nom
    end)

    local n = math.min(#liste, NB_PROPOSITIONS)
    if n == 0 then
        self:FermerPropositions()
        return
    end
    for k = 1, NB_PROPOSITIONS do
        local l = self.lignesPropositions[k]
        if k <= n then
            l.nomJoueur = liste[k].nom
            l:SetText(liste[k].nom .. " (" .. FormaterOr(liste[k].total) .. ")")
            l:SetHidden(false)
        else
            l:SetHidden(true)
        end
    end
    self.fondPropositions:SetDimensions(LARGEUR_PROPOSITIONS, 8 + n * 24)
    self.fondPropositions:SetHidden(false)
end

function CV:ChoisirProposition(nom)
    if not nom then return end
    self.texteAuto = Normaliser(nom)
    self.editRecherche:SetText(nom)
    self:RechercheModifiee(nom)
    self:FermerPropositions()
    self.editRecherche:LoseFocus()
end

function CV:ChangerOpacite(delta)
    local o = (self.sv.options.opacite or OPACITE_FOND) + delta
    o = math.floor(math.max(0.2, math.min(1, o)) * 10 + 0.5) / 10
    self.sv.options.opacite = o
    for _, f in ipairs(self.fonds) do f:SetCenterColor(0, 0, 0, o) end
end

function CV:BasculerGuilde(i)
    local guildId = self.lignes[i].guildId
    if not guildId then return end
    self.sv.guildesDesactivees[guildId] = (not self.sv.guildesDesactivees[guildId]) or nil
    self:FermerVentes()
    self:RafraichirGuildes()
end

---------------------------------------------------------------
-- Affichage du tableau des guildes
---------------------------------------------------------------
function CV:RafraichirGuildes()
    local nb = GetNumGuilds()
    self.nbRows = math.min(nb, self.MAX_GUILDES)
    local deduite = self.sv.options.taxeDeduite
    local somme, aDesDonnees = 0, false

    for i = 1, self.MAX_GUILDES do
        local ligne = self.lignes[i]
        local guildId = (i <= nb) and GetGuildId(i) or nil
        ligne.guildId = guildId
        ligne.texteHisto = nil

        if guildId then
            local actif = not self.sv.guildesDesactivees[guildId]
            local v = actif and 1 or 0.45
            ligne.case:SetHidden(false)
            ligne.case:SetNormalTexture(actif and CASE_COCHEE or CASE_VIDE)
            ligne.nom:SetText(GetGuildName(guildId))
            ligne.nom:SetColor(v, v, v, 1)

            -- une guilde décochée n'affiche plus rien (ses données restent sauvegardées)
            local stats = actif and self:Stats(guildId) or nil
            local p = stats and stats[self.semaine]
            local textes = { moi = "", gui = "", gains = "" }
            if p then
                textes.moi   = FormaterOr(deduite and (p.moiBrut - p.moiTaxe) or p.moiBrut)
                somme = somme + (deduite and (p.moiBrut - p.moiTaxe) or p.moiBrut)
                aDesDonnees = true
                textes.gui   = FormaterOr(deduite and (p.guiBrut - p.guiTaxe) or p.guiBrut)
                textes.gains = FormaterOr(p.guiTaxe)
            end
            for _, cle in ipairs(CLES_CHIFFRES) do
                ligne[cle]:SetText(textes[cle])
                ligne[cle]:SetColor(v, v, v, 1)
            end

            local ok, texte = nil, nil
            if actif then ok, texte = self:EtatHistorique(guildId) end
            if ok == nil then
                ligne.voyant:SetHidden(true)
            else
                local icone = ok and ICONE_VOYANT_OK or ICONE_VOYANT_KO
                ligne.voyant:SetNormalTexture(icone)
                ligne.voyant:SetMouseOverTexture(icone)
                ligne.voyant:SetHidden(false)
                ligne.texteHisto = texte
            end
        else
            ligne.case:SetHidden(true)
            ligne.nom:SetText("")
            for _, cle in ipairs(CLES_CHIFFRES) do ligne[cle]:SetText("") end
            ligne.voyant:SetHidden(true)
        end
    end

    self.totalTrait:SetHidden(not aDesDonnees)
    self.totalNom:SetHidden(not aDesDonnees)
    self.totalValeur:SetHidden(not aDesDonnees)
    if aDesDonnees then self.totalValeur:SetText(FormaterOr(somme)) end

    self:Disposer()
    if self.ventesOuvertes then self:AfficherLignesVentes() end
end

---------------------------------------------------------------
-- Mise en page verticale (tout ce qui est sous le tableau des guildes)
---------------------------------------------------------------
function CV:Disposer()
    local tab = self.tableau
    local larg = LARGEUR_TABLEAU
    local function Poser(ctrl, x, y)
        ctrl:ClearAnchors()
        ctrl:SetAnchor(TOPLEFT, tab, TOPLEFT, x, y)
    end

    -- ligne Total, juste sous la dernière guilde
    local yTotal = 80 + self.nbRows * 30
    Poser(self.totalTrait, self.xTraitTotal, yTotal)
    Poser(self.totalNom, 44, yTotal + 4)
    Poser(self.totalValeur, self.xMoi, yTotal + 4)

    -- séparateur 1, puis la section "Dernières ventes"
    local y = yTotal + 38
    Poser(self.sep1, math.floor((larg - self.sep1:GetWidth()) / 2), y)
    self.sep1:SetHidden(false)

    y = y + 10
    Poser(self.ventesTitre, 12, y)
    Poser(self.btnVentes, math.floor((larg - 140) / 2), y + 32)
    y = y + 70

    if self.ventesOuvertes then
        for i, col in ipairs(COLONNES_VENTES) do
            Poser(self.entetesVentes[i], col[3], y)
            self.entetesVentes[i]:SetHidden(false)
        end
        y = y + 26
        Poser(self.zoneVentes, 0, y)
        self.zoneVentes:SetHidden(false)
        y = y + NB_LIGNES_VENTES * 30 + 8
    else
        for _, l in ipairs(self.entetesVentes) do l:SetHidden(true) end
        self.zoneVentes:SetHidden(true)
    end

    -- liste des meilleurs vendeurs, puis séparateur 2 (toujours affiché)
    local yM = y + 14
    local hauteurListe = self:PlacerMeilleurs(yM)
    Poser(self.sep2, math.floor((larg - self.sep2:GetWidth()) / 2), y + 2)
    self.sep2:SetHidden(false)

    -- barre de progression, message d'information et hauteur de la fenêtre
    Poser(self.fondBarre, 12, yM + 12 + hauteurListe)
    Poser(self.statut, 12, yM + 30 + hauteurListe)
    tab:SetHeight(yM + 30 + hauteurListe + 104)
end

function CV:ChangerNbMeilleurs(delta)
    local n = self.sv.options.nbMeilleurs + delta
    n = math.max(1, math.min(NB_MEILLEURS_MAX, n))
    self.sv.options.nbMeilleurs = n
    self:Disposer()
end

-- liste des meilleurs vendeurs par guilde ; renvoie la hauteur occupée
function CV:PlacerMeilleurs(yM)
    local nbMax = self.sv.options.nbMeilleurs
    local largeurMax = LARGEUR_TABLEAU - 40
    local moi = Normaliser(GetDisplayName())
    local cible = self:JoueurCible()
    local pool = self.meilleursLignes
    local nbLignes = 0

    local function Largeur(texte)
        self.mesure:SetText(texte)
        return self.mesure:GetTextWidth()
    end

    local function AjouterLigne(texte)
        if nbLignes >= #pool then return end
        nbLignes = nbLignes + 1
        local l = pool[nbLignes]
        l:SetText(texte)
        l:ClearAnchors()
        l:SetAnchor(TOPLEFT, self.tableau, TOPLEFT, 12, yM + 30 + (nbLignes - 1) * 24)
        l:SetHidden(false)
    end

    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if not self.sv.guildesDesactivees[guildId] then
            local classement = self:Classement(guildId)
            if classement then
                local nom = GetGuildName(guildId)
                local ligneBrute = nom .. " : "                  -- sans couleurs, pour mesurer
                local ligneCouleur = "|cFFFFFF" .. nom .. " :|r "
                local vide = true
                local n = math.min(nbMax, #classement)

                if n == 0 then
                    AjouterLigne(ligneCouleur .. "aucune vente.")
                else
                    for k = 1, n do
                        local v = classement[k]
                        local montant = " (" .. FormaterOr(v.total) .. ")"
                        local nomNorm = Normaliser(v.nom)
                        local couleur = COUL_VENDEUR
                        if nomNorm == moi then
                            couleur = COUL_MOI
                        elseif nomNorm == cible then
                            couleur = COUL_RECHERCHE
                        end
                        local brut = v.nom .. montant
                        local colore = couleur .. v.nom .. "|r" .. montant

                        if not vide and Largeur(ligneBrute .. ", " .. brut) > largeurMax then
                            AjouterLigne(ligneCouleur .. ",")
                            ligneBrute = "      " .. brut
                            ligneCouleur = "      " .. colore
                        else
                            local sep = vide and "" or ", "
                            ligneBrute = ligneBrute .. sep .. brut
                            ligneCouleur = ligneCouleur .. sep .. colore
                        end
                        vide = false
                    end
                    AjouterLigne(ligneCouleur .. ".")
                end
            end
        end
    end

    for k = nbLignes + 1, #pool do pool[k]:SetHidden(true) end

    local visible = nbLignes > 0
    self.meilleursTitre:SetHidden(not visible)
    self.meilleursNombre:SetHidden(not visible)
    self.btnMoins:SetHidden(not visible)
    self.btnPlus:SetHidden(not visible)
    if visible then
        local titre, nombre = self.meilleursTitre, self.meilleursNombre
        titre:SetColor(COUL_MENU:UnpackRGBA())
        local debutTitre, finTitre = "Le(s) ", " meilleur(s) vendeur(s)"
        titre:SetText(debutTitre .. nbMax .. finTitre)
        local lt, ln = titre:GetTextWidth(), nombre:GetTextWidth()
        titre:SetDimensions(lt + 4, 26)
        titre:SetText(debutTitre .. COUL_NBRE .. nbMax .. "|r" .. finTitre)
        nombre:SetDimensions(ln + 4, 26)

        -- l'ensemble est centré dans le tableau
        local E1, E2, B = 30, 8, 30   -- écart titre/texte, écart texte/boutons, largeur d'un bouton
        local total = lt + E1 + ln + E2 + B + 6 + B
        local x = math.floor((LARGEUR_TABLEAU - total) / 2)
        local function Placer(ctrl, px)
            ctrl:ClearAnchors()
            ctrl:SetAnchor(TOPLEFT, self.tableau, TOPLEFT, px, yM)
        end
        Placer(titre, x)
        x = x + lt + E1
        Placer(nombre, x)
        x = x + ln + E2
        Placer(self.btnMoins, x)
        Placer(self.btnPlus, x + B + 6)
    end

    return visible and (30 + nbLignes * 24) or 0
end

---------------------------------------------------------------
-- Dernières ventes : lues dans l'historique du jeu, jamais sauvegardées
---------------------------------------------------------------
function CV:FermerVentes()
    self:AnnulerRecherche()
    self.ventes, self.ventesOuvertes, self.defil = nil, false, 0
    if self.btnVentes then self.btnVentes:SetText(TEXTE_BTN_AFFICHER) end
end

function CV:AnnulerRecherche()
    if self.recherche then
        EVENT_MANAGER:UnregisterForUpdate(self.name .. "Recherche")
        self.recherche = nil
        self:DefinirProgression(nil)
    end
end

function CV:BasculerVentes()
    if self.ventesOuvertes then
        self:FermerVentes()
        self:Disposer()
    else
        self:LancerRecherche()
    end
end

function CV:LancerRecherche()
    if self.recherche or self.etat then return end
    local guildes = {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if not self.sv.guildesDesactivees[guildId] then guildes[#guildes + 1] = guildId end
    end
    if #guildes == 0 then
        self.statut:SetText(COUL_ERREUR .. "Aucune guilde sélectionnée.|r")
        return
    end

    local cur, pas = DebutsDePeriode()
    local debut, fin = cur, nil
    if self.semaine == "Pas" then debut, fin = pas, cur end

    self.recherche = { guildes = guildes, g = 1, idx = 1, lignes = {},
                       debut = debut, fin = fin, cible = self:JoueurCible() }
    self.statut:SetText("Recherche des ventes en cours...")
    self:DefinirProgression(0)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Recherche", 0, function() CV:ImageRecherche() end)
end

function CV:ImageRecherche()
    local R = self.recherche
    if not R then return end
    local budget = EVENEMENTS_PAR_IMAGE_RECHERCHE

    while budget > 0 and R.g <= #R.guildes do
        local guildId = R.guildes[R.g]
        if not R.n then R.n = GetNumGuildHistoryEvents(guildId, CATEGORIE) end

        local fini = false
        if R.idx > R.n then
            fini = true
        else
            -- index 1 = vente la plus récente
            local id, ts, redacte, typeEv, vendeur, acheteur, lien, qte, prix, taxe =
                GetGuildHistoryTraderEventInfo(guildId, R.idx)
            if not ts then
                fini = true
            else
                if ts >= R.debut and (not R.fin or ts < R.fin) and typeEv == TYPE_VENTE
                    and not redacte and Normaliser(vendeur) == R.cible then
                    R.lignes[#R.lignes + 1] = {
                        ts = ts, lien = lien, qte = qte or 1,
                        prix = prix or 0, taxe = taxe or 0, acheteur = acheteur,
                    }
                end
                R.idx = R.idx + 1
                budget = budget - 1
            end
        end

        if fini then
            R.g, R.idx, R.n = R.g + 1, 1, nil
        end
    end

    if R.g <= #R.guildes then
        local part = R.n and (R.idx / math.max(1, R.n)) or 0
        self:DefinirProgression(((R.g - 1) + part) / #R.guildes)
        return
    end

    -- terminé : de la plus récente à la plus ancienne
    EVENT_MANAGER:UnregisterForUpdate(self.name .. "Recherche")
    self.recherche = nil
    self:DefinirProgression(nil)
    table.sort(R.lignes, function(a, b) return a.ts > b.ts end)

    self.ventes, self.defil, self.ventesOuvertes = R.lignes, 0, true
    self.btnVentes:SetText(TEXTE_BTN_MASQUER)
    if #R.lignes == 0 then
        self.statut:SetText("Aucune vente trouvée pour ce joueur sur cette période.")
    else
        self.statut:SetText(#R.lignes .. " vente(s) trouvée(s).")
    end
    self:Disposer()
    self:AfficherLignesVentes()
end

function CV:Defiler(delta)
    if not self.ventes then return end
    self.defil = (self.defil or 0) + delta
    self:AfficherLignesVentes()
end

-- position de la souris sur la barre : place le curseur au centre de la souris
function CV:ClicPiste()
    if not self.ventes then return end
    local _, souris = GetUIMousePosition()
    local hauteur = NB_LIGNES_VENTES * 30
    local hCurseur = self.curseurVentes:GetHeight()
    local ratio = (souris - self.pisteVentes:GetTop() - hCurseur / 2) / math.max(1, hauteur - hCurseur)
    ratio = math.max(0, math.min(1, ratio))
    local maxDef = math.max(0, #self.ventes - NB_LIGNES_VENTES)
    self.defil = math.floor(ratio * maxDef + 0.5)
    self:AfficherLignesVentes()
end

-- tant que le bouton de la souris reste enfoncé, le curseur suit la souris
function CV:DebutGlisse()
    if not self.ventes then return end
    self.glisse = true
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Glisse", 0, function()
        if not CV.glisse then
            EVENT_MANAGER:UnregisterForUpdate(CV.name .. "Glisse")
            return
        end
        CV:ClicPiste()
    end)
end

local function InfosObjet(lien)
    local icone = GetItemLinkInfo(lien)
    if not icone or icone == "" then icone = "/esoui/art/icons/icon_missing.dds" end
    local nom = zo_strformat("<<t:1>>", GetItemLinkName(lien))
    local ok, couleur = pcall(function() return GetItemQualityColor(GetItemLinkQuality(lien)) end)
    if ok and couleur then nom = couleur:Colorize(nom) end
    return icone, nom
end

function CV:AfficherLignesVentes()
    local donnees = self.ventes or {}
    local n = #donnees
    local maxDef = math.max(0, n - NB_LIGNES_VENTES)
    self.defil = math.max(0, math.min(self.defil or 0, maxDef))
    local deduite = self.sv.options.taxeDeduite

    for k = 1, NB_LIGNES_VENTES do
        local L = self.lignesVentes[k]
        local d = donnees[self.defil + k]
        if d then
            local icone, nom = InfosObjet(d.lien)
            L.lien = d.lien
            L.survol:SetHidden(false)
            L.icone:SetTexture(icone)
            L.icone:SetHidden(false)
            L.qte:SetText(d.qte > 1 and tostring(d.qte) or "")
            L.nom:SetText(nom)

            local brutTotal = PRIX_EST_POUR_LE_LOT and d.prix or (d.prix * d.qte)
            local total = deduite and (brutTotal - d.taxe) or brutTotal
            L.unite:SetText(FormaterOr(total / math.max(1, d.qte)))
            L.total:SetText(FormaterOr(total))
            L.acheteur:SetText(tostring(d.acheteur or ""))
        else
            L.icone:SetHidden(true)
            L.lien = nil
            L.survol:SetHidden(true)
            L.qte:SetText("")
            L.nom:SetText("")
            L.unite:SetText("")
            L.total:SetText("")
            L.acheteur:SetText("")
        end
    end

    -- barre de défilement : visible seulement s'il y a plus de lignes que de place
    local hauteur = NB_LIGNES_VENTES * 30
    local deborde = n > NB_LIGNES_VENTES
    self.pisteVentes:SetHidden(not deborde)
    self.curseurVentes:SetHidden(not deborde)
    self.priseVentes:SetHidden(not deborde)
    self.flecheHaut:SetHidden(not deborde)
    self.flecheBas:SetHidden(not deborde)
    self.flecheHaut:SetAlpha(self.defil > 0 and 1 or 0.4)       -- grisée quand on est tout en haut
    self.flecheBas:SetAlpha(self.defil < maxDef and 1 or 0.4)   -- grisée quand on est tout en bas

    if deborde then
        local hCurseur = math.max(20, math.floor(hauteur * NB_LIGNES_VENTES / n))
        local y = math.floor((hauteur - hCurseur) * self.defil / maxDef)
        self.curseurVentes:SetDimensions(8, hCurseur)
        self.curseurVentes:ClearAnchors()
        self.curseurVentes:SetAnchor(TOPRIGHT, self.zoneVentes, TOPRIGHT, -14, y)
    end
end

---------------------------------------------------------------
-- Collecte : met à jour les totaux sauvegardés (répartie sur plusieurs images)
---------------------------------------------------------------

-- plage = { h = id le plus récent, b = id le plus ancien, th = date la plus récente, tb = date la plus ancienne }
local function FusionnerPlages(anciennes, nouvelles, debutPas)
    local toutes = {}
    for _, p in ipairs(anciennes or {}) do toutes[#toutes + 1] = p end
    for _, p in ipairs(nouvelles or {}) do toutes[#toutes + 1] = p end
    table.sort(toutes, function(a, b) return a.h > b.h end)

    local res = {}
    for _, p in ipairs(toutes) do
        local dernier = res[#res]
        if dernier and p.h >= dernier.b then      -- chevauchement : on fusionne
            if p.b < dernier.b then dernier.b, dernier.tb = p.b, p.tb end
        else
            res[#res + 1] = { h = p.h, b = p.b, th = p.th, tb = p.tb }
        end
    end

    local gardees = {}   -- on oublie les plages antérieures à la semaine passée
    for _, p in ipairs(res) do
        if p.th >= debutPas then gardees[#gardees + 1] = p end
    end
    return gardees
end

local function DejaCompte(plages, idNum)
    for _, p in ipairs(plages or {}) do
        if idNum <= p.h and idNum >= p.b then return true end
    end
    return false
end


local function RecordGuilde(guildId)
    local rec = CV.sv.ventes[guildId]
    if not rec then
        rec = { dernierId = 0, sem = {} }
        CV.sv.ventes[guildId] = rec
    end
    rec.sem = rec.sem or {}
    rec.dernierId = rec.dernierId or 0
    return rec
end

-- valide les ventes lues pour une guilde
local function TerminerGuilde(E, guildId, C)
    local rec = C.rec
    FusionnerSemaines(rec.sem, C.sem)
    if C.premierTs then rec.dernierTs = C.premierTs end
    rec.nom = GetGuildName(guildId)
    rec.collecte = true

    -- on ne garde que la semaine en cours et la semaine passée
    for debut in pairs(rec.sem) do
        if debut < E.debutPas then rec.sem[debut] = nil end
    end
    E.total = E.total + C.nb

    -- tranches d'historique désormais comptées, et date depuis laquelle il n'y a pas de trou
    rec.plages = FusionnerPlages(rec.plages, C.plagesJeu, E.debutPas)
    rec.couvertDepuis = rec.plages[1] and rec.plages[1].tb or nil
end

local function FinCollecte()
    EVENT_MANAGER:UnregisterForUpdate(CV.name .. "Collecte")
    local E = CV.etat
    CV.etat = nil
    CV:DefinirProgression(nil)
    CV:RafraichirGuildes()
    CV.statut:SetText("Terminé : " .. E.total .. " nouvelle(s) vente(s).")
end

local function ImageCollecte()
    local E = CV.etat
    if not E then return end
    local budget = EVENEMENTS_PAR_IMAGE

    while budget > 0 and E.g <= #E.guildes do
        local guildId = E.guildes[E.g]
        if not E.courant then
            local plagesJeu = {}
            local okP, nbP = pcall(GetNumGuildHistoryEventRanges, guildId, CATEGORIE)
            if okP and type(nbP) == "number" then
                for r = 1, nbP do
                    local okI, th, tb, h, b = pcall(GetGuildHistoryEventRangeInfo, guildId, CATEGORIE, r)
                    if okI and h and b then
                        plagesJeu[#plagesJeu + 1] = { h = tonumber(h) or 0, b = tonumber(b) or 0, th = th, tb = tb }
                    end
                end
            end
            E.courant = {
                n = GetNumGuildHistoryEvents(guildId, CATEGORIE),
                idx = 1, sem = {}, nb = 0, rec = RecordGuilde(guildId),
                plagesJeu = plagesJeu,
            }
        end
        local C = E.courant
        local fini = false

        if C.idx > C.n then
            fini = true
        else
            -- index 1 = vente la plus récente
            local id, ts, redacte, typeEv, vendeur, acheteur, lien, qte, prix, taxe =
                GetGuildHistoryTraderEventInfo(guildId, C.idx)
            local idNum = tonumber(id) or 0
            if not ts then
                fini = true
            else
                if C.idx == 1 then C.premierTs = ts end
                if ts >= E.debutPas and typeEv == TYPE_VENTE and not redacte
                    and not DejaCompte(C.rec.plages, idNum) then
                    Agreger(C.sem, ts, vendeur, prix or 0, taxe or 0)
                    C.nb = C.nb + 1
                end
                C.idx = C.idx + 1
                budget = budget - 1
            end
        end

        if fini then
            TerminerGuilde(E, guildId, C)
            E.courant = nil
            E.g = E.g + 1
        end
    end

    -- progression
    local fraction
    if E.g > #E.guildes then
        fraction = 1
    else
        local part = 0
        if E.courant then part = E.courant.idx / math.max(1, E.courant.n) end
        fraction = ((E.g - 1) + part) / #E.guildes
    end
    CV:DefinirProgression(fraction)

    if E.g > #E.guildes then FinCollecte() end
end

---------------------------------------------------------------
-- Actions
---------------------------------------------------------------
function CV:OuvrirTableau()
    if self.infobulleBouton then self.infobulleBouton:SetHidden(true) end
    self.tableauOuvert = true
    self.bouton:SetHidden(true)
    self:RafraichirGuildes()
    self.statut:SetText(TEXTE_STATUT_PRET)
    self.tableau:SetHidden(false)
end

function CV:FermerTableau()
    self:CacherInfobulle()
    ClearTooltip(ItemTooltip)
    self:FermerVentes()
    self:ReinitialiserRecherche()
    self.tableauOuvert = false
    self.tableau:SetHidden(true)
    self.bouton:SetHidden(false)
end

function CV:Collecter()
    if self.etat or self.recherche then return end
    local guildes = {}
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        if not self.sv.guildesDesactivees[guildId] then
            guildes[#guildes + 1] = guildId
        end
    end
    if #guildes == 0 then
        self.statut:SetText(COUL_ERREUR .. "Aucune guilde sélectionnée.|r")
        return
    end

    local _, debutPas = DebutsDePeriode()
    self.etat = { guildes = guildes, g = 1, total = 0, debutPas = debutPas }
    self.statut:SetText("Collecte en cours...")
    self:DefinirProgression(0)
    EVENT_MANAGER:RegisterForUpdate(self.name .. "Collecte", 0, ImageCollecte)
end

function CV:Purger()
    if self.etat or self.recherche then return end
    self.sv.ventes = {}
    self:RafraichirGuildes()
    self.statut:SetText("Données purgées (effet complet dans le fichier après /reloadui).")
end

---------------------------------------------------------------
-- Initialisation
---------------------------------------------------------------
local function OnAddOnLoaded(_, nomAddon)
    if nomAddon ~= CV.name then return end
    EVENT_MANAGER:UnregisterForEvent(CV.name, EVENT_ADD_ON_LOADED)

    CV.sv = ZO_SavedVars:NewAccountWide("CaracVentes_Data", 1, nil, CV.defaults, GetWorldName())
    
    EVENT_MANAGER:RegisterForEvent(CV.name .. "Souris", EVENT_GLOBAL_MOUSE_UP,
        function() CV.glisse = false end)
    CV:CreerBouton()
    CV:CreerTableau()
    CV:RafraichirGuildes()

    -- Échap (ou toute sortie du mode curseur / ouverture d'un menu) ferme la fenêtre
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, ancienEtat, nouvelEtat)
        if nouvelEtat == SCENE_SHOWING and CV.tableauOuvert and scene ~= HUD_UI_SCENE then
            CV:FermerTableau()
        end
    end)
end

EVENT_MANAGER:RegisterForEvent(CV.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
