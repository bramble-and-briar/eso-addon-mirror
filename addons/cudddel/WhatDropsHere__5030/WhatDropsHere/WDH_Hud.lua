-- WDH_Hud.lua
-- Anzeige am Fadenkreuz (Phase 2)
--
-- Zwei Anzeigen mit demselben Inhalt:
--   1. Interaktion (Vorkommen, Behaelter, Leichen, Kleintiere)
--      SecurePostHook auf RETICLE:TryHandlingInteraction. Das Spiel ruft die Funktion jedes Bild auf,
--      solange kein Lootfenster offen ist (siehe ZO_Reticle:UpdateInteractText im UI-Quellcode).
--      Das Label haengt an RETICLE.interact und verschwindet automatisch mit der Interaktionsanzeige.
--   2. Lebende Ziele (Gegner, Tiere, NPCs unter dem Fadenkreuz, "reticleover")
--      SecurePostHook auf RETICLE:UpdateInteractText, danach ist klar, ob die Interaktionsanzeige
--      sichtbar ist. Nur wenn sie es nicht ist, erscheint die Anzeige fuer das lebende Ziel.
--      Gezeigt wird nur die eindeutige Zuordnung (Name + Zone), keine Sammelpluenderungen (#aoe).
--
-- Beide Anzeigen werden im Kampf ausgeblendet. Der Text wird nur neu aufgebaut,
-- wenn sich das Ziel oder die Daten aendern.
--
-- Sortierung: hoechste Qualitaet zuerst, bei gleicher Qualitaet die groesste Anzahl.
-- Prozent = Anteil der Pluenderungen, in denen der Eintrag mindestens einmal dabei war.

local WDH = WhatDropsHere
local CAT = WDH_Categories
local Hud = {}
WDH.Hud = Hud

-- Anzeige-Zustand: Label + Ziel, fuer das der Text gerade gilt
local function NewView()
    return {
        label     = nil,
        shownKey  = nil,   -- Schluessel des Ziels, fuer das der Text gerade gilt
        hasText   = false, -- ob es fuer dieses Ziel Daten gibt
        dirty     = true,  -- Daten haben sich geaendert, Text neu aufbauen
    }
end

local interactView = NewView()
local unitView     = NewView()

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------

local function Settings()
    return WDH.Settings()
end

local function Percent(hits, loots)
    if loots <= 0 then return 0 end
    return zo_round(hits / loots * 100)
end

local function ApplyFont(label)
    label:SetFont(IsInGamepadPreferredMode() and "ZoFontGamepad22" or "ZoFontWinH5")
end

local function AddEntry(entries, quality, text, n)
    entries[#entries + 1] = { quality = quality, text = text, n = n }
end

local function SortEntries(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    return a.n > b.n
end

local function CreateLabel(name, parent)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetColor(ZO_NORMAL_TEXT:UnpackRGBA())
    label:SetHidden(true)
    ApplyFont(label)
    return label
end

-- -----------------------------------------------------------------------------
-- Text aufbauen
-- -----------------------------------------------------------------------------

local function BuildText(rec, minQuality)
    local maxLines   = Settings().hudMaxLines
    local entries    = {}

    for setId, s in pairs(rec.sets) do
        local quality = WDH.BestQuality(s.q)
        if quality >= minQuality then
            local slots = {}
            for slot in pairs(s.slots or {}) do
                slots[#slots + 1] = WDH_SLOT_NAMES[slot] or slot
            end
            table.sort(slots)
            AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_SET,
                WDH.ColorByQuality(quality, WDH.SetName(setId)), table.concat(slots, ", "),
                s.n, Percent(s.hits, rec.loots)), s.n)
        end
    end

    -- Items mit Namen: Kategorie-Modus DETAIL immer, DETAIL_Q ab "Mit Namen anzeigen ab".
    -- Was nicht mit Namen erscheint, wird unten in seiner Kategorie gezeigt.
    local nameQuality = Settings().nameQuality
    local catHasItems = {}  -- Kategorie hat gespeicherte Items
    local hiddenBest  = {}  -- beste Qualitaet der Items, die nicht mit Namen erscheinen
    for id, s in pairs(rec.items) do
        local cat = s.cat
        if cat ~= "SET" then
            local quality = WDH.BestQuality(s.q)
            -- Aeltere Items ohne Kategorie wurden nur einzeln gespeichert, also mit Namen zeigen
            local mode   = cat and CAT.ModeOf(cat) or CAT.MODE_DETAIL
            local byName = mode == CAT.MODE_DETAIL or (mode == CAT.MODE_DETAIL_Q and quality >= nameQuality)
            if cat then catHasItems[cat] = true end
            if byName then
                if quality >= minQuality then
                    AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_ITEM,
                        WDH.ColorByQuality(quality, WDH.ItemName(id)), s.n, Percent(s.hits, rec.loots)), s.n)
                end
            elseif cat then
                hiddenBest[cat] = math.max(hiddenBest[cat] or quality, quality)
            end
        end
    end

    -- Kategorien: COUNT immer, sonst nur, wenn ein Teil nicht mit Namen erscheint
    -- (oder es aus aelteren Versionen keine Items dazu gibt)
    for key, s in pairs(rec.cats) do
        local mode = CAT.ModeOf(key)
        local show = mode ~= CAT.MODE_SET
            and (mode == CAT.MODE_COUNT or hiddenBest[key] ~= nil or not catHasItems[key])
        if show then
            local quality = hiddenBest[key] or WDH.BestQuality(s.q)
            if quality >= minQuality then
                AddEntry(entries, quality, string.format(WDH_STRINGS.HUD_ITEM,
                    WDH.ColorByQuality(quality, WDH.CatName(key)), s.n, Percent(s.hits, rec.loots)), s.n)
            end
        end
    end

    table.sort(entries, SortEntries)

    local header = string.format(WDH_STRINGS.HUD_HEADER, rec.loots)
    if rec.gold > 0 then
        header = header .. string.format(WDH_STRINGS.HUD_GOLD, zo_round(rec.gold / rec.loots))
    end

    local lines = { header }
    for i = 1, math.min(#entries, maxLines) do
        lines[#lines + 1] = entries[i].text
    end
    if #entries > maxLines then
        lines[#lines + 1] = string.format(WDH_STRINGS.HUD_MORE, #entries - maxLines, zo_strlower(rec.name))
    end
    return table.concat(lines, "\n")
end

-- -----------------------------------------------------------------------------
-- Aktualisierung
-- -----------------------------------------------------------------------------

-- Anzeige-Schwelle je Art der Quelle (rec.type, siehe DetermineSourceType in WhatDropsHere.lua)
local TYPE_SETTING = {
    enemy     = "showEnemy",
    container = "showContainer",
    resource  = "showResource",
    other     = "showOther",
    theft     = "showTheft",
}

-- Mindestqualitaet fuer die Anzeige dieser Quelle, nil = fuer diese Art ausgeschaltet.
-- Aeltere Eintraege ohne Art: niedrigste eingeschaltete Schwelle.
local function MinQuality(rec)
    local settings = Settings()
    local key = TYPE_SETTING[rec.type]
    if key then
        local quality = settings[key]
        if quality == WDH.SHOW_OFF then return nil end
        return quality
    end
    local lowest
    for _, k in pairs(TYPE_SETTING) do
        local quality = settings[k]
        if quality ~= WDH.SHOW_OFF and (lowest == nil or quality < lowest) then lowest = quality end
    end
    return lowest
end

-- Zeigt die Statistik fuer name (oder blendet aus, wenn name nil ist bzw. keine Daten vorliegen).
-- isOwned: Ziel gehoert jemandem -> Diebstahl-Eintrag statt des normalen
local function ShowFor(view, name, isOwned)
    if not name or name == "" then
        view.label:SetHidden(true)
        return
    end
    name = zo_strformat("<<C:1>>", name)
    local key = WDH.RecordKey(name, isOwned)
    if view.dirty or key ~= view.shownKey then
        view.shownKey, view.dirty = key, false
        local rec = WDH.FindRecord(WDH.CurrentZoneId(), key)
        local minQuality = rec and MinQuality(rec)
        view.hasText = minQuality ~= nil
        if view.hasText then
            ApplyFont(view.label)
            view.label:SetText(BuildText(rec, minQuality))
        end
    end
    view.label:SetHidden(not view.hasText)
end

local function HudAllowed()
    return Settings().hud and not IsUnitInCombat("player")
end

-- Nachlauf zu ZO_Reticle:TryHandlingInteraction(interactionPossible, currentFrameTimeSeconds)
local function OnTryHandlingInteraction(_, interactionPossible)
    if not HudAllowed() or not interactionPossible then
        interactView.label:SetHidden(true)
        return
    end
    local _, name, _, isOwned = GetGameCameraInteractableActionInfo()
    ShowFor(interactView, name, isOwned)
end

-- Lebendes Ziel unter dem Fadenkreuz (kein Spieler, nicht tot)
local function LivingTargetName()
    if not DoesUnitExist("reticleover") then return nil end
    if IsUnitPlayer("reticleover") or IsUnitDead("reticleover") then return nil end
    return GetUnitName("reticleover")
end

-- Nachlauf zu ZO_Reticle:UpdateInteractText(currentFrameTimeSeconds)
local function OnUpdateInteractText()
    -- Lebende Ziele sind immer Feinde (bzw. Tiere/NPCs): beide Schalter muessen an sein
    if not HudAllowed() or Settings().showEnemy == WDH.SHOW_OFF or not Settings().hudUnits
       or not RETICLE.interact:IsHidden() then
        unitView.label:SetHidden(true)
        return
    end
    ShowFor(unitView, LivingTargetName())
end

-- -----------------------------------------------------------------------------
-- Schnittstelle
-- -----------------------------------------------------------------------------

function Hud:Invalidate()
    interactView.dirty = true
    unitView.dirty     = true
end

function Hud:Init()
    -- Unter der Zusatzinfo (z. B. Schlossstufe), die selbst unter dem Tastentext steht
    interactView.label = CreateLabel("WhatDropsHereHud", RETICLE.interact)
    interactView.label:SetAnchor(TOPLEFT, RETICLE.additionalInfo, BOTTOMLEFT, 0, 6)

    -- Lebende Ziele: an derselben Stelle, an der sonst der Interaktionstext steht.
    -- Elternteil ist der Fadenkreuz-Container, weil RETICLE.interact dann ausgeblendet ist.
    unitView.label = CreateLabel("WhatDropsHereHudUnit", RETICLE.control)
    unitView.label:SetAnchor(TOPLEFT, RETICLE.interact, BOTTOMLEFT, 0, 4)

    SecurePostHook(RETICLE, "TryHandlingInteraction", OnTryHandlingInteraction)
    SecurePostHook(RETICLE, "UpdateInteractText", OnUpdateInteractText)
end
