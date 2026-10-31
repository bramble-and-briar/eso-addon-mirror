-- CaracBuffDebuff : tes buffs, les debuffs de ta cible et tes propres debuffs, en trois blocs déplaçables
local ADDON = "CaracBuffDebuff"

------------------------------------------------------------
-- RÉGLAGES (modifie ici)
------------------------------------------------------------
local CFG = {
    iconSize       = 34,    -- taille des icônes
    rowGap         = 2,     -- espace vertical entre deux lignes
    nameWidth      = 190,   -- largeur réservée au nom du buff/debuff
    maxRows        = 12,    -- nombre maximal de lignes par bloc
    minSeconds     = 1,     -- un effet n'est affiché que s'il lui reste plus de X secondes
    foodMinSeconds = 900,   -- buffs : au-delà de cette durée restante, c'est de la nourriture et on ne l'affiche pas
    onlyMine       = false, -- true : seulement les effets que TU as lancés ; false : tous (concerne CaracBuff et CaracDebuff)
    updateMs       = 100,   -- fréquence de mise à jour
    otherColor     = { 0.45, 0.85, 1 }, -- couleur du nom des buffs reçus d'un autre joueur (bleu clair)
}

local wm = WINDOW_MANAGER
local BLOCK_W = CFG.iconSize + 6 + CFG.nameWidth
local ROW_STEP = CFG.iconSize + CFG.rowGap
local MIN_H = CFG.iconSize * 2

-- Position de départ : buffs à gauche de ton personnage, debuffs à droite
local screenW, screenH = GuiRoot:GetDimensions()
local DEFAULTS = {
    buffX   = screenW / 2 - 170 - BLOCK_W,
    buffY   = screenH / 2 - 150,
    debuffX = screenW / 2 + 170,
    debuffY = screenH / 2 - 150,
    selfX   = screenW / 2 - 170 - 2 * BLOCK_W - 20,
    selfY   = screenH / 2 - 150,
}
local sv = {}

------------------------------------------------------------
-- OUTILS
------------------------------------------------------------
-- Durée restante : "6,3" (secondes), "2m" au-delà d'une minute
local function FormatDuration(r)
    if r <= 0 then return "" end
    if r >= 60 then return zo_floor(r / 60) .. "m" end
    return (string.format("%.1f", r):gsub("%.", ","))
end

------------------------------------------------------------
-- BLOCS
------------------------------------------------------------
local function CreateBlock(prefix, labelText, keyX, keyY, colorOthers)
    local top = wm:CreateTopLevelWindow(ADDON .. prefix .. "Top")
    top:SetDimensions(BLOCK_W, MIN_H)
    top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, DEFAULTS[keyX], DEFAULTS[keyY])
    top:SetClampedToScreen(true)
    top:SetMovable(true)
    top:SetMouseEnabled(true)

    -- Cadre rouge transparent visible quand le curseur de la souris est libre
    local outline = wm:CreateControl(ADDON .. prefix .. "Outline", top, CT_BACKDROP)
    outline:SetAnchorFill(top)
    outline:SetCenterColor(0.8, 0.1, 0.1, 0.25)
    outline:SetEdgeColor(1, 0.3, 0.3, 0.9)
    outline:SetEdgeTexture("", 1, 1, 1)
    outline:SetHidden(true)

    local placeholder = wm:CreateControl(ADDON .. prefix .. "Placeholder", top, CT_LABEL)
    placeholder:SetFont("ZoFontGameBold")
    placeholder:SetColor(1, 1, 1, 1)
    placeholder:SetText(labelText)
    placeholder:SetAnchor(CENTER, top, CENTER, 0, 0)
    placeholder:SetHidden(true)

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

    -- Le bloc disparaît dans les menus, comme le reste de l'interface de jeu
    local fragment = ZO_SimpleSceneFragment:New(top)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    top:SetHandler("OnMoveStop", function()
        sv[keyX] = top:GetLeft()
        sv[keyY] = top:GetTop()
    end)

    return { top = top, outline = outline, placeholder = placeholder, slots = slots, count = -1,
             keyX = keyX, keyY = keyY, colorOthers = colorOthers }
end

local buffBlock = CreateBlock("Buff", "CaracBuff", "buffX", "buffY", true)
local debuffBlock = CreateBlock("Debuff", "CaracDebuff", "debuffX", "debuffY")
local selfDebuffBlock = CreateBlock("SelfDebuff", "CaracDebuffMoi", "selfX", "selfY")

------------------------------------------------------------
-- LECTURE DES EFFETS
------------------------------------------------------------
-- wantDebuff : true pour les debuffs, false pour les buffs ; mineOnly : ne garder que les effets lancés par toi
local function Collect(unitTag, wantDebuff, mineOnly)
    local list = {}
    local now = GetFrameTimeSeconds()

    for i = 1, GetNumBuffs(unitTag) do
        local buffName, _, timeEnding, _, stackCount, iconFile, _, effectType, _, _, _, _, castByPlayer =
            GetUnitBuffInfo(unitTag, i)
        local isDebuff = (effectType == BUFF_EFFECT_TYPE_DEBUFF)

        if iconFile and iconFile ~= "" and isDebuff == wantDebuff and (castByPlayer or not mineOnly) then
            local remaining = (timeEnding and timeEnding > 0) and (timeEnding - now) or 0
            local keep = remaining > CFG.minSeconds
            -- Buffs : on écarte la nourriture (durée très longue) et la pierre de mundus (permanente)
            if keep and not wantDebuff and remaining >= CFG.foodMinSeconds then keep = false end

            if keep then
                local text = zo_strformat(SI_ABILITY_NAME, buffName)
                if stackCount and stackCount > 1 then
                    text = text .. " x" .. stackCount
                end
                list[#list + 1] = { icon = iconFile, name = text, remaining = remaining, mine = castByPlayer and true or false }
            end
        end
    end

    -- Le plus proche de la fin en premier
    table.sort(list, function(a, b)
        if a.remaining ~= b.remaining then return a.remaining < b.remaining end
        return a.name < b.name
    end)
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
            if block.colorOthers and not e.mine then
                slot.name:SetColor(CFG.otherColor[1], CFG.otherColor[2], CFG.otherColor[3], 1)
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
    block.placeholder:SetHidden(not (cursorMode and count == 0))

    if count ~= block.count then
        block.count = count
        block.top:SetDimensions(BLOCK_W, math.max(MIN_H, count * ROW_STEP - CFG.rowGap))
    end
end

------------------------------------------------------------
-- MISE À JOUR
------------------------------------------------------------
local function Update()
    -- Curseur libre (mode interface) : cadres rouges et noms des blocs pour pouvoir les déplacer
    local cursorMode = SCENE_MANAGER:IsShowing("hudui")

    FillBlock(buffBlock, Collect("player", false, CFG.onlyMine), cursorMode)

    local debuffs = {}
    if DoesUnitExist("reticleover") then
        debuffs = Collect("reticleover", true, CFG.onlyMine)
    end
    FillBlock(debuffBlock, debuffs, cursorMode)

    -- Debuffs subis par toi (lancés par d'autres, donc sans filtre « mes effets »)
    FillBlock(selfDebuffBlock, Collect("player", true, false), cursorMode)
end

------------------------------------------------------------
-- POSITIONS SAUVEGARDÉES
------------------------------------------------------------
EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    sv = ZO_SavedVars:NewAccountWide("CaracBuffDebuffSV", 1, nil, DEFAULTS)

    for _, block in ipairs({ buffBlock, debuffBlock, selfDebuffBlock }) do
        block.top:ClearAnchors()
        block.top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
            sv[block.keyX] or DEFAULTS[block.keyX], sv[block.keyY] or DEFAULTS[block.keyY])
    end

EVENT_MANAGER:RegisterForUpdate(ADDON .. "Update", CFG.updateMs, Update)

end)
