local ADDON_NAME = "CaracTracker"
local svc -- réglages du personnage (position, opacité, caractéristiques cochées)
local defaults = { x = 400, y = 300, alpha = 0.5, tracked = {} }

local win
local rows = {}
local timeLabel, bg
local buttons = {}
local configMode = false

local ROW_HEIGHT = 22
local WIDTH = 190
local BLUE = { 0.3, 0.7, 1, 1 }
local BLUELIGHT1 = { 0.8, 1, 1, 1 }
local BLUELIGHT2 = { 0.6, 0.8, 1, 1 }
local GREEN = { 0.3, 1, 0.4, 1 }
local GREENLIGHT = { 0.8, 1, 0.8, 1 }
local RED = { 1, 0.2, 0.2, 1 }
local PINK = { 1, 0.5, 0.8, 1 }
local GOLD = { 1, 0.82, 0.1, 1 }
local PURPLE = { 0.8, 0.6, 1, 1 }
local ORANGE = { 1, 0.6, 0.1, 1 }
local CYAN = { 0, 1, 1, 1 }
local YELLOW = { 1, 1, 0.6, 1 }

local TIME_COLOR = { 1, 0.82, 0.1, 1 } -- couleur de l'heure : mets ici la tienne (ex. GOLD)
local HEADER_Y = 4
local BTN_LEFT = 36   -- taille de la roue dentée

local BTN_OP = 18     -- taille des boutons - et +
local STEP_OP = 20    -- écart entre ces 2 boutons
local HEADER_H = BTN_LEFT + 8

---------------------------------------------------------------
-- Statistiques avancées 
---------------------------------------------------------------
-- Numéros (statType) relevés en jeu avec le script de listage (donc indépendant de la langue). 
-- Si ZOS les renumérote, relancer le script et mettre à jour ce tableau.
-- Script du chat pour faire apparaître les valeurs : /script for c=0,GetNumAdvancedStatCategories() do local ok,cn,n=pcall(GetAdvancedStatCategoryInfo,c) if ok and n then for i=1,n do local ok2,t,nm=pcall(GetAdvancedStatInfo,c,i) if ok2 then d(c.."/"..i.." : "..tostring(t).." = "..tostring(nm)) end end end end
local knownTypes = {
    critDamage   = 23, -- Dégâts critiques
    critHealing  = 22, -- Soins critiques
    healingDone  = 51, -- Soins effectués
    healingTaken = 50, -- Soins reçus
    block        = 7,  -- Absorption de blocage
    blockCost    = 1,  -- Coût du blocage
    bashCost     = 2,  -- Coût de percussion
    bashDamage   = 3,  -- Dégâts de percussion
    sneakSpeed   = 6,  -- Vitesse de discrétion
    sprintSpeed  = 9,  -- Vitesse de sprint
}


local function FindAdvancedStat(key)
    return knownTypes[key]
end

local function LastNumber(...)
    for i = select("#", ...), 1, -1 do
        local v = select(i, ...)
        if type(v) == "number" then return v end
    end
    return nil
end

local function AdvValue(key)
    local statType = FindAdvancedStat(key)
    if not statType then return nil end
    return LastNumber(GetAdvancedStatValue(statType))
end

---------------------------------------------------------------
-- Fonctions de lecture des valeurs
---------------------------------------------------------------
local function Num(n)
    return ZO_CommaDelimitNumber(zo_round(n or 0))
end

local function Pct(n)
    if n == nil then return GetString(CARACTRACKER_UI_NA) end
    return string.format("%.1f%%", n)
end

local function Stat(stat)
    return GetPlayerStat(stat) or 0
end

local function GetShield()
    local value = GetUnitAttributeVisualizerEffectInfo(
        "player",
        ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION,
        ATTRIBUTE_HEALTH,
        COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH
    )
    return value or 0
end

---------------------------------------------------------------
-- DPS / HPS (calculés à partir des événements de combat)
---------------------------------------------------------------
local PAUSE_MS = 5000 -- au-delà de 5 s sans événement, la pause n'est pas comptée
local RESET_DELAY_MS = 3000 -- durée (en ms) pendant laquelle les valeurs restent affichées après la fin du combat

local combat = {
    damage = 0, heal = 0, rawHeal = 0,
    dmgActive = 0, healActive = 0,
    dmgPrev = nil, healPrev = nil,
    inCombat = false, finished = false, endTime = 0,
}

local DAMAGE_RESULTS = {
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
    [ACTION_RESULT_DAMAGE_SHIELDED] = true,
}
local HEAL_RESULTS = {
    [ACTION_RESULT_HEAL] = true,
    [ACTION_RESULT_CRITICAL_HEAL] = true,
    [ACTION_RESULT_HOT_TICK] = true,
    [ACTION_RESULT_HOT_TICK_CRITICAL] = true,
}

local function ResetCombat()
    combat.damage, combat.heal = 0, 0
    combat.rawHeal = 0
    combat.dmgActive, combat.healActive = 0, 0
    combat.dmgPrev, combat.healPrev = nil, nil
end

local function OnCombatEvent(_, result, _, _, _, _, _, _, _, targetType, hitValue, _, _, _, _, _, _, overflow)
    local isDamage = DAMAGE_RESULTS[result]
    local isHeal = HEAL_RESULTS[result]

    if not (isDamage or isHeal) then return end
    if isDamage and targetType == COMBAT_UNIT_TYPE_PLAYER then return end
    if isHeal and not combat.inCombat then return end -- les soins hors combat ne sont pas comptés

    local now = GetGameTimeMilliseconds()

    if combat.finished then
        if combat.inCombat or (now - combat.endTime) >= RESET_DELAY_MS then
            ResetCombat()
            combat.finished = false
        else
            return -- délai pas écoulé : on garde les valeurs du dernier combat
        end
    end

    if isDamage then
        if combat.dmgPrev and (now - combat.dmgPrev) <= PAUSE_MS then
            combat.dmgActive = combat.dmgActive + (now - combat.dmgPrev)
        end
        combat.dmgPrev = now
        combat.damage = combat.damage + hitValue
    else
        if combat.healPrev and (now - combat.healPrev) <= PAUSE_MS then
            combat.healActive = combat.healActive + (now - combat.healPrev)
        end
        combat.healPrev = now
        combat.heal = combat.heal + hitValue

        -- HPS brut : soins effectifs + overheal (on est forcément en combat ici)
        combat.rawHeal = combat.rawHeal + hitValue + (overflow or 0)
    end
end

local function OnCombatState(_, inCombat)
    combat.inCombat = inCombat
    if not inCombat then
        combat.finished = true
        combat.endTime = GetGameTimeMilliseconds()
    end
end

-- Total / temps actif (minimum 1 seconde)
local function Rate(total, activeMs)
    local seconds = math.max(1, activeMs / 1000)
    return total / seconds
end

---------------------------------------------------------------
-- FIN DPS / HPS
---------------------------------------------------------------

-- { identifiant interne (ne jamais changer), libellé affiché (traduit), fonction de valeur, couleur (optionnel, bleu par défaut) }
local lines = {
    { "inCombat", GetString(CARACTRACKER_L_INCOMBAT), function()
        local inCombat = IsUnitInCombat("player")
        return inCombat and GetString(CARACTRACKER_UI_YES) or GetString(CARACTRACKER_UI_NO), inCombat and RED or GREEN
    end },

    { "dps",    GetString(CARACTRACKER_L_DPS),    function() return Num(Rate(combat.damage, combat.dmgActive)) end, GOLD },
    { "hps",    GetString(CARACTRACKER_L_HPS),    function() return Num(Rate(combat.heal, combat.healActive)) end, GOLD },
    { "hpsRaw", GetString(CARACTRACKER_L_HPSRAW), function() return Num(Rate(combat.rawHeal, combat.healActive)) end, GOLD },

    { "powerP",         GetString(CARACTRACKER_L_POWERP),  function() return Num(Stat(STAT_POWER)) end },
    { "powerM",         GetString(CARACTRACKER_L_POWERM),  function() return Num(Stat(STAT_SPELL_POWER)) end },

    { "penetrationP",  GetString(CARACTRACKER_L_PENP), function() return Num(Stat(STAT_PHYSICAL_PENETRATION)) end, BLUELIGHT1 },
    { "penetrationM",  GetString(CARACTRACKER_L_PENM), function() return Num(Stat(STAT_SPELL_PENETRATION)) end, BLUELIGHT1 },

    { "critChanceP",    GetString(CARACTRACKER_L_CRITP),   function() return Pct(GetCriticalStrikeChance(Stat(STAT_CRITICAL_STRIKE))) end, BLUELIGHT2 },
    { "critChanceM",    GetString(CARACTRACKER_L_CRITM),   function() return Pct(GetCriticalStrikeChance(Stat(STAT_SPELL_CRITICAL))) end, BLUELIGHT2 },
    { "critDamage",    GetString(CARACTRACKER_L_CRITDMG),  function() return Pct(AdvValue("critDamage")) end, BLUELIGHT2 },

    { "magickaRegen",  GetString(CARACTRACKER_L_MAGREGEN),    function() return Num(Stat(STAT_MAGICKA_REGEN_COMBAT)) end, ORANGE },
    { "healthRegen",   GetString(CARACTRACKER_L_HEALTHREGEN), function() return Num(Stat(STAT_HEALTH_REGEN_COMBAT)) end, ORANGE },
    { "staminaRegen",  GetString(CARACTRACKER_L_STAMREGEN),   function() return Num(Stat(STAT_STAMINA_REGEN_COMBAT)) end, ORANGE },

    { "critHealing",   GetString(CARACTRACKER_L_CRITHEAL),  function() return Pct(AdvValue("critHealing")) end, PINK },
    { "healingDone",   GetString(CARACTRACKER_L_HEALDONE),  function() return Pct(AdvValue("healingDone")) end, PINK },
    { "healingTaken",  GetString(CARACTRACKER_L_HEALTAKEN), function() return Pct(AdvValue("healingTaken")) end, PINK },

    { "block",         GetString(CARACTRACKER_L_BLOCK),     function() return Pct(AdvValue("block")) end, YELLOW },
    { "blockCost",     GetString(CARACTRACKER_L_BLOCKCOST), function() return Num(AdvValue("blockCost")) end, YELLOW },

    { "bashDamage",    GetString(CARACTRACKER_L_BASHDMG),   function() return Num(AdvValue("bashDamage")) end, YELLOW },
    { "bashCost",      GetString(CARACTRACKER_L_BASHCOST),  function() return Num(AdvValue("bashCost")) end, YELLOW },

    { "spellResist",   GetString(CARACTRACKER_L_SPELLRES),  function() return Num(Stat(STAT_SPELL_RESIST)) end, GREEN },
    { "spellAbsorb",   GetString(CARACTRACKER_L_SPELLABS),  function()
        local r = Stat(STAT_SPELL_RESIST)
        local pct = math.max(0, math.min(50, (r - 100) / 660))
        return string.format("%.1f%%", pct)
    end, GREENLIGHT },
    { "physResist",    GetString(CARACTRACKER_L_PHYSRES),   function() return Num(Stat(STAT_PHYSICAL_RESIST)) end, GREEN },
    { "physAbsorb",    GetString(CARACTRACKER_L_PHYSABS),   function()
        local r = Stat(STAT_PHYSICAL_RESIST)
        local pct = math.max(0, math.min(50, (r - 100) / 660))
        return string.format("%.1f%%", pct)
    end, GREENLIGHT },
    { "critResist",    GetString(CARACTRACKER_L_CRITRES),   function() return Num(Stat(STAT_CRITICAL_RESISTANCE)) end, GREEN },
    { "critAbsorb",    GetString(CARACTRACKER_L_CRITABS),   function()
        local r = Stat(STAT_CRITICAL_RESISTANCE)
        return string.format("%.1f%%", math.max(0, r / 66))
    end, GREENLIGHT },

    { "shield",        GetString(CARACTRACKER_L_SHIELD),    function() return Num(GetShield()) end, PURPLE },

    { "sprintSpeed", GetString(CARACTRACKER_L_SPRINT), function() return Pct(AdvValue("sprintSpeed")) end, CYAN },
    { "sneakSpeed",  GetString(CARACTRACKER_L_SNEAK),  function() return Pct(AdvValue("sneakSpeed")) end, CYAN },

}
local function TimeText()
    local ok, t = pcall(os.date, GetString(CARACTRACKER_UI_TIMEFMT))
    return ok and t or ("[" .. GetTimeString() .. "]")
end

local function Refresh()
    if timeLabel then timeLabel:SetText(TimeText()) end
    for _, row in ipairs(rows) do
        if row.visible then
            local ok, text, color = pcall(row.getter)
            row.value:SetText(ok and text or GetString(CARACTRACKER_UI_NA))
            local c = (ok and color) or row.color
            row.value:SetColor(c[1], c[2], c[3], c[4]) 
        end
    end
end

-- Place les lignes visibles, ajuste la taille de la fenêtre et l'état des boutons
local function Layout()
    local y = HEADER_Y + HEADER_H
    local nameX = configMode and 34 or 12
    for _, row in ipairs(rows) do
        local show = not not (configMode or svc.tracked[row.key])
        row.visible = show
        row.name:SetHidden(not show)
        row.value:SetHidden(not show)
        row.check:SetHidden(not (show and configMode))
        if show then
            row.name:ClearAnchors()
            row.name:SetAnchor(TOPLEFT, win, TOPLEFT, nameX, y)
            row.value:ClearAnchors()
            row.value:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, y)
            row.check:ClearAnchors()
            row.check:SetAnchor(TOPLEFT, win, TOPLEFT, 10, y + 2)
            y = y + ROW_HEIGHT
        end
    end
    win:SetDimensions(configMode and (WIDTH + 22) or WIDTH, y + 8)

    -- Mode configuration : la fenêtre passe au-dessus du chat et des autres addons
    if configMode then
        win:SetDrawTier(DT_HIGH)
        win:SetDrawLevel(100)
    else
        win:SetDrawTier(DT_MEDIUM)
        win:SetDrawLevel(0)
    end

    Refresh()
end

local function ChangeAlpha(delta)
    svc.alpha = math.max(0, math.min(1, zo_round((svc.alpha + delta) * 10) / 10))
    bg:SetColor(0, 0, 0, svc.alpha)
end

-- Vrai bouton ESO : le clic est géré par le bouton, l'image est posée dessus
-- texOver est facultatif ; crop (facultatif) ne garde qu'une partie de l'image
local function MakeButton(fromRight, x, size, tex, texOver, tooltip, onClick)
    local b = WINDOW_MANAGER:CreateControl(nil, win, CT_BUTTON)
    b:SetDimensions(size, size)
    b:SetMouseEnabled(true)
    b:ClearAnchors()
    local y = HEADER_Y + (BTN_LEFT - size) / 2 -- centré verticalement dans l'en-tête
    if fromRight then
        b:SetAnchor(TOPRIGHT, win, TOPRIGHT, -x, y)
    else
        b:SetAnchor(TOPLEFT, win, TOPLEFT, x, y)
    end

    local icon = WINDOW_MANAGER:CreateControl(nil, b, CT_TEXTURE)
    icon:SetAnchorFill(b)

    local function Apply(path, shade)
        icon:SetTexture(path)
        icon:SetColor(shade, shade, shade, 1)
    end
    Apply(tex, 1)

    b:SetHandler("OnMouseEnter", function(self)
        Apply(texOver or tex, 1)
        ZO_Tooltips_ShowTextTooltip(self, BOTTOM, tooltip)
    end)
    b:SetHandler("OnMouseExit", function()
        Apply(tex, 1)
        ZO_Tooltips_HideTextTooltip()
    end)
    b:SetHandler("OnClicked", function() onClick() end)
    return b
end

---------------------------------------------------------------
-- Interface
---------------------------------------------------------------

-- Texte de l'infobulle de chaque ligne (clé = identifiant interne)
local tooltips = {
    inCombat     = GetString(CARACTRACKER_T_INCOMBAT),

    dps          = GetString(CARACTRACKER_T_DPS),
    hps          = GetString(CARACTRACKER_T_HPS),
    hpsRaw       = GetString(CARACTRACKER_T_HPSRAW),

    powerP       = GetString(CARACTRACKER_T_POWERP),
    powerM       = GetString(CARACTRACKER_T_POWERM),
    penetrationP = GetString(CARACTRACKER_T_PENP),
    penetrationM = GetString(CARACTRACKER_T_PENM),

    critChanceP  = GetString(CARACTRACKER_T_CRITP),
    critChanceM  = GetString(CARACTRACKER_T_CRITM),
    critDamage   = GetString(CARACTRACKER_T_CRITDMG),

    magickaRegen = GetString(CARACTRACKER_T_MAGREGEN),
    healthRegen  = GetString(CARACTRACKER_T_HEALTHREGEN),
    staminaRegen = GetString(CARACTRACKER_T_STAMREGEN),

    critHealing  = GetString(CARACTRACKER_T_CRITHEAL),
    healingDone  = GetString(CARACTRACKER_T_HEALDONE),
    healingTaken = GetString(CARACTRACKER_T_HEALTAKEN),

    block        = GetString(CARACTRACKER_T_BLOCK),
    blockCost    = GetString(CARACTRACKER_T_BLOCKCOST),
    bashDamage   = GetString(CARACTRACKER_T_BASHDMG),
    bashCost     = GetString(CARACTRACKER_T_BASHCOST),

    spellResist  = GetString(CARACTRACKER_T_SPELLRES),
    physResist   = GetString(CARACTRACKER_T_PHYSRES),
    critResist   = GetString(CARACTRACKER_T_CRITRES),

    spellAbsorb  = GetString(CARACTRACKER_T_SPELLABS),
    physAbsorb   = GetString(CARACTRACKER_T_PHYSABS),
    critAbsorb   = GetString(CARACTRACKER_T_CRITABS),

    shield       = GetString(CARACTRACKER_T_SHIELD),

    sprintSpeed  = GetString(CARACTRACKER_T_SPRINT),
    sneakSpeed   = GetString(CARACTRACKER_T_SNEAK),
}

local function CreateUI()
    win = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "Window")
    win:SetDimensions(WIDTH, 100)
    win:SetClampedToScreen(true)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, svc.x, svc.y)
    win:SetHandler("OnMoveStop", function()
        svc.x, svc.y = win:GetLeft(), win:GetTop()
    end)

    bg = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    bg:SetAnchorFill(win)
    bg:SetColor(0, 0, 0, svc.alpha)

    -- Heure : première ligne, centrée
    timeLabel = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
    timeLabel:SetAnchor(TOP, win, TOP, 0, HEADER_Y + (BTN_LEFT - 18) / 2)
    timeLabel:SetFont("ZoFontGameBold")
    timeLabel:SetColor(unpack(TIME_COLOR))

    -- Roue dentée : ouvre / ferme le choix des caractéristiques
    buttons.gear = MakeButton(false, 6, BTN_LEFT,
        "EsoUI/Art/ChatWindow/chat_options_up.dds", "EsoUI/Art/ChatWindow/chat_options_over.dds",
        GetString(CARACTRACKER_UI_GEAR),
        function()
            configMode = not configMode
            Layout()
        end)

    -- Boutons à droite : opacité
    buttons.plus = MakeButton(true, 6, BTN_OP,
        "EsoUI/Art/Buttons/pointsplus_up.dds", "EsoUI/Art/Buttons/pointsplus_over.dds",
        GetString(CARACTRACKER_UI_OPAC_UP), function() ChangeAlpha(0.1) end)
    buttons.minus = MakeButton(true, 6 + STEP_OP, BTN_OP,
        "EsoUI/Art/Buttons/pointsminus_up.dds", "EsoUI/Art/Buttons/pointsminus_over.dds",
        GetString(CARACTRACKER_UI_OPAC_DOWN), function() ChangeAlpha(-0.1) end)

    -- Lignes de caractéristiques (position gérée par Layout)
    for i, line in ipairs(lines) do
        local name = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
        name:SetFont("ZoFontGameBold")
        name:SetColor(1, 1, 1, 1)
        name:SetText(line[2] .. GetString(CARACTRACKER_UI_COLON))

    local tip = tooltips[line[1]]
        if tip then
            name:SetMouseEnabled(true)
            name:SetHandler("OnMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, RIGHT, tip) end)
            name:SetHandler("OnMouseExit", function() ZO_Tooltips_HideTextTooltip() end)
        end

        local value = WINDOW_MANAGER:CreateControl(nil, win, CT_LABEL)
        value:SetFont("ZoFontGameBold")
        local c = line[4] or BLUE
        value:SetColor(c[1], c[2], c[3], c[4])

        -- Case à cocher : un bouton dont l'état est lu et écrit directement dans svc.tracked
        local key = line[1]
        local check = WINDOW_MANAGER:CreateControl(nil, win, CT_BUTTON)
        check:SetDimensions(16, 16)
        local box = WINDOW_MANAGER:CreateControl(nil, check, CT_TEXTURE)
        box:SetAnchorFill(check)
        local function DrawBox()
            box:SetTexture(svc.tracked[key]
                and "EsoUI/Art/Buttons/checkbox_checked.dds"
                or "EsoUI/Art/Buttons/checkbox_unchecked.dds")
        end
        DrawBox()
        check:SetHandler("OnClicked", function()
            -- "or nil" : une case décochée supprime la clef du fichier de sauvegarde au lieu d'y stocker "false", ce qui le rend plus léger, car seules les clefs cochées y figurent). 
            svc.tracked[key] = (not svc.tracked[key]) or nil
            DrawBox()
        end)

        rows[i] = { key = line[1], name = name, value = value, check = check,
                    getter = line[3], color = c, visible = true }
    end

    local fragment = ZO_SimpleSceneFragment:New(win)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    Layout()
end

local function OnPlayerActivated()
       Refresh()
end

local function OnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    
-- Sélection des caractéristiques : propre à chaque personnage
    svc = ZO_SavedVars:NewCharacterIdSettings("CaracTrackerSV", 1, "Perso", defaults)

    -- Migration : anciens choix enregistrés sous le libellé → identifiant interne
    if not svc.keysMigrated then
        for _, line in ipairs(lines) do
            local id, label = line[1], line[2]
            if svc.tracked[label] ~= nil then
                svc.tracked[id] = svc.tracked[label]
                svc.tracked[label] = nil
            end
        end
        svc.keysMigrated = true
    end

    CreateUI()
    Refresh()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

-- Événements de combat : joueur + familiers
    for i, unitType in ipairs({ COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET }) do
        local ns = ADDON_NAME .. "Combat" .. i
        EVENT_MANAGER:RegisterForEvent(ns, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(ns, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, unitType)
    end
-- Fin Événements de combat : joueur + familiers 

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", 100, Refresh)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnLoaded)
