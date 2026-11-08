-- WhatDropsHere.lua
-- Hauptlogik des Addons (Phase 1: Erfassung, Kategorien, Debug-Ausgabe)
--
-- Ablauf einer Pluender-Sitzung:
--   1. EVENT_LOOT_UPDATED (erstes)  -> Quelle sichern (GetLootTargetInfo), Liste lesen
--   2. EVENT_LOOT_UPDATED (weitere) -> nur neue lootIds ergaenzen
--      (Auto-Loot-Addons nehmen Items, die Liste wird kuerzer, das Event feuert erneut)
--   3. EVENT_LOOT_CLOSED            -> Sitzung in WDH_Saved schreiben
--   4. EVENT_LOOT_RECEIVED          -> Spuren (Antiquitaeten), Taschendiebstahl und
--                                      Beute ohne Lootfenster (siehe unten)
--
-- Beute ohne Lootfenster: Kleintiere (Schmetterlinge, Quallen, Motten ...) und einzelne
-- Gegenstaende werden mit "Nehmen" direkt ins Inventar gelegt. Die Quelle merken wir uns
-- beim Druecken der Interaktionstaste (Hook auf INTERACTIVE_WHEEL_MANAGER:StartInteraction,
-- den Tastatur und Gamepad laut bindings.xml vor GameCameraInteractStart aufrufen).
-- Alle Items, die kurz danach ankommen, bilden eine Sitzung.
--
-- Erfasst wird, was die Quelle ANGEBOTEN hat, nicht was genommen wurde.
-- So verfaelschen die Filter von Auto-Loot-Addons (MSAL, Smarter AutoLoot) die Statistik nicht.
--
-- Ausnahme Spuren: Im Lootfenster gibt es fuer Spuren keine Antiquitaeten-ID.
-- Die kommt erst mit EVENT_LOOT_RECEIVED (itemId = antiquityId). Spuren werden deshalb
-- im Lootfenster uebersprungen und beim Empfang der laufenden bzw. letzten Sitzung zugeordnet.
--
-- Datenmodell (accountweit):
--   WDH_Saved.zones[zoneId][key] = Quelle
--     zoneId 0      = Behaelter aus dem Inventar (ueberall gleich)
--     key           = Name in Kleinbuchstaben, "#aoe" fuer Sammelpluenderung,
--                     "pickpocket:" fuer Taschendiebstahl
--   Quelle = { name, kind, loots, gold, targetType, last, sets = {}, items = {}, cats = {} }
--     items[itemId] = Stat + cat (jeder Fund; "lead:<antiquityId>" bzw. "n:<Name>" fuer Nicht-Items)
--     cats[key]     = Stat (Kategorie-Schluessel aus WDH_Categories.lua, alle Funde der Kategorie)
--     sets[setId]   = Stat + slots[slot] = Anzahl (Set-Ausruestung zusaetzlich pro Set)
--   Was davon mit Namen oder als Kategorie angezeigt wird, entscheidet erst die Anzeige.
--   Stat = { n = Anzahl gesamt, hits = Pluenderungen mit Treffer, min, max, q = { [Qualitaet] = Anzahl } }

local ADDON_NAME         = "WhatDropsHere"
local SAVED_VERSION      = 2  -- 2: jeder Fund mit Item-ID, Schwelle nur noch fuer die Anzeige
local RECEIVED_GRACE_MS  = 2000  -- ms nach LOOT_CLOSED, in denen LOOT_RECEIVED noch zur Sitzung gehoert
local SESSION_TIMEOUT_MS = 5000  -- ms ohne LOOT_UPDATED, nach denen eine Sitzung ohne LOOT_CLOSED gespeichert wird
local INTERACT_VALID_MS  = 3000  -- ms nach der Interaktion, in denen Beute ohne Lootfenster ihr zugeordnet wird
local DIRECT_COMMIT_MS   = 1000  -- ms nach dem letzten Item, nach denen eine Sitzung ohne Lootfenster gespeichert wird
local INTERACT_POLL_MS   = 100   -- Abfrage-Intervall fuer die Art der Interaktion nach Druck auf E

-- -----------------------------------------------------------------------------
-- Addon-Objekt
-- -----------------------------------------------------------------------------
WhatDropsHere = {
    VERSION = "0.3.0-beta",  -- wie "## Version" im Manifest
}
local WDH = WhatDropsHere
local CAT = WDH_Categories

-- Schwelle je Art der Quelle: Anzeige fuer diese Art aus
local SHOW_OFF = -1

-- Einstellungen fuer den ganzen Account
local DEFAULT_ACCOUNT = {
    debug         = false,                        -- Debug-Ausgabe im Chat (/wdh_debug, Menue)
}

-- Anzeige-Einstellungen, je Charakter gespeichert (gespeichert wird immer alles)
local DEFAULT_DISPLAY = {
    hud           = true,                         -- Anzeige am Fadenkreuz
    hudUnits      = true,                         -- auch fuer lebende Ziele (Gegner, Tiere, NPCs)
    nameQuality   = ITEM_DISPLAY_QUALITY_ARCANE,  -- am Fadenkreuz mit Namen ab blau, darunter als Kategorie
    hudMaxLines   = 6,                            -- Eintraege am Fadenkreuz, Rest als "+N weitere"
    -- Anzeige-Schwelle je Art der Quelle (Qualitaet oder SHOW_OFF); ab weiss = Trash ausgeblendet
    showEnemy     = ITEM_DISPLAY_QUALITY_NORMAL,  -- Feinde: Leichen und lebende Ziele
    showContainer = ITEM_DISPLAY_QUALITY_NORMAL,  -- Truhen und Behaelter
    showResource  = ITEM_DISPLAY_QUALITY_NORMAL,  -- Rohstoffvorkommen
    showOther     = ITEM_DISPLAY_QUALITY_NORMAL,  -- Kleintiere, einzelne Gegenstaende, Sonstiges
    showTheft     = ITEM_DISPLAY_QUALITY_NORMAL,  -- Diebstahl aus fremdem Besitz
}

-- Bis 0.2: Schalter je Art + eine gemeinsame Schwelle (Account-weit)
local LEGACY_TYPE_SWITCH = {
    showEnemy     = "hudEnemies",
    showContainer = "hudContainers",
    showResource  = "hudResources",
    showOther     = "hudOther",
    showTheft     = "hudTheft",
}

local function FillDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then target[k] = v end
    end
end

local function CopyDisplay(source)
    local copy = {}
    for k in pairs(DEFAULT_DISPLAY) do copy[k] = source[k] end
    FillDefaults(copy, DEFAULT_DISPLAY)
    return copy
end

-- -----------------------------------------------------------------------------
-- Interne Zustaende
-- -----------------------------------------------------------------------------

-- Laufende Pluender-Sitzung (nil, wenn kein Lootfenster offen)
local WDH_Session = nil

-- Abgeschlossenes Lootfenster, das schon leer war, als wir es lesen konnten:
-- Ein Auto-Loot-Addon (z. B. Much Smarter AutoLoot) war schneller, hat alles genommen und das
-- Fenster geschlossen. Die Beute kommt danach noch ueber LOOT_RECEIVED bzw. CURRENCY_UPDATE an
-- und wird hier gesammelt, bevor die Sitzung gespeichert wird.
local WDH_Pending = nil

-- Zuletzt gespeicherte Quelle, fuer verspaetete Spuren und /wdh ohne Argument
local WDH_Last = {
    zoneId   = nil,
    key      = nil,
    closedAt = 0,
    itemIds  = {},  -- Item-IDs der letzten Lootliste, zum Abgleich mit spaeterem LOOT_RECEIVED
    lootKey  = nil, -- Schluessel und lootIds der letzten Sitzung, um erneutes Oeffnen
    lootSeen = nil, -- derselben Quelle zu erkennen (Reste, die ein Auto-Loot-Addon liegen laesst)
}

-- Letzte Interaktion (Taste E / Gamepad), Quelle fuer Beute ohne Lootfenster
-- Dazu, woran die Art der Quelle erkannt wird (siehe DetermineSourceType)
local WDH_Interact = {
    name    = nil,
    action  = nil,
    at      = 0,
    monster = false,  -- IsGameCameraInteractableUnitMonster(): Leiche einer Kreatur/eines NPC
    owned   = false,  -- gehoert jemandem (Diebstahl), aus GetGameCameraInteractableActionInfo()
    itype   = nil,    -- erster GetInteractionType() nach der Interaktion (z. B. INTERACTION_HARVEST)
}

-- Laufende Sitzung ohne Lootfenster (Kleintiere, einzelne Gegenstaende)
local WDH_Direct = nil

local WDH_Initialized = false

-- -----------------------------------------------------------------------------
-- Hilfsfunktionen
-- -----------------------------------------------------------------------------

local function dbg(msg)
    if not WDH_Saved or not WDH_Saved.settings.debug then return end
    d(WDH_STRINGS.DEBUG_PREFIX .. msg)
end

local function Now()
    return GetGameTimeMilliseconds()
end

local function CurrentZoneId()
    return GetZoneId(GetUnitZoneIndex("player"))
end

local function ZoneName(zoneId)
    if zoneId == 0 then return WDH_STRINGS.ZONE_ANYWHERE end
    return zo_strformat("<<C:1>>", GetZoneNameById(zoneId))
end

-- Name der Quelle wie im Lootfenster formatieren (entfernt u. a. Geschlechts-Endungen wie ^n)
local function FormatTargetName(name, targetType)
    if name == nil or name == "" then return "" end
    if targetType == INTERACT_TARGET_TYPE_ITEM then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
    elseif targetType == INTERACT_TARGET_TYPE_OBJECT then
        return zo_strformat(SI_LOOT_OBJECT_NAME, name)
    elseif targetType == INTERACT_TARGET_TYPE_FIXTURE then
        return zo_strformat(SI_TOOLTIP_FIXTURE_INSTANCE, name)
    end
    return zo_strformat("<<C:1>>", name)
end

local function MakeKey(name)
    return zo_strlower(name)
end

-- Ob das Lootfenster mehrere Leichen zusammenfasst (Flaechenpluendern).
-- INTERACT_TARGET_TYPE_AOE_LOOT ist eine Vermutung; gibt es die Konstante nicht,
-- bleibt das Ergebnis false. Die Debug-Ausgabe zeigt targetType zum Pruefen im Spiel.
local function IsAoeTarget(targetType)
    return INTERACT_TARGET_TYPE_AOE_LOOT ~= nil and targetType == INTERACT_TARGET_TYPE_AOE_LOOT
end

local function IsAoeSettingOn()
    return GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AOE_LOOT) == "1"
end

local function QualityName(quality)
    return GetString("SI_ITEMDISPLAYQUALITY", quality)
end

local function ColorByQuality(quality, text)
    return GetItemQualityColor(quality):Colorize(text)
end

local function CatName(key)
    return (WDH_CAT_NAMES and WDH_CAT_NAMES[key]) or key
end

local function SetName(setId)
    local name = GetItemSetName and GetItemSetName(setId) or ""
    if name == "" then return string.format(WDH_STRINGS.SET_UNKNOWN, setId) end
    return zo_strformat("<<C:1>>", name)
end

-- Anzeigename fuer einen items-Schluessel (Item-ID, "lead:<id>" oder "n:<Name>")
local function ItemName(id)
    if type(id) == "number" then
        local link = string.format("|H1:item:%d:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", id)
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
    end
    local leadId = id:match("^lead:(%d+)$")
    if leadId then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetAntiquityName(tonumber(leadId)))
    end
    return (id:gsub("^n:", ""))
end

-- -----------------------------------------------------------------------------
-- Statistik-Bausteine
-- -----------------------------------------------------------------------------

-- Zaehlt eine Menge in eine Sitzungs-Statistik. cat = Kategorie (nur bei items)
local function AddStat(t, id, quantity, quality, cat)
    local s = t[id]
    if not s then
        s = { n = 0, q = {}, cat = cat }
        t[id] = s
    end
    s.n = s.n + quantity
    s.q[quality] = (s.q[quality] or 0) + quantity
    return s
end

-- Fuehrt eine Sitzungs-Statistik in die gespeicherte Statistik zusammen
local function MergeStat(dst, id, src)
    local s = dst[id]
    if not s then
        s = { n = 0, hits = 0, max = 0, q = {} }
        dst[id] = s
    end
    s.n    = s.n + src.n
    s.hits = s.hits + 1
    s.cat  = src.cat or s.cat
    s.min  = s.min and math.min(s.min, src.n) or src.n
    s.max  = math.max(s.max, src.n)
    for quality, count in pairs(src.q) do
        s.q[quality] = (s.q[quality] or 0) + count
    end
    if src.slots then
        s.slots = s.slots or {}
        for slot, count in pairs(src.slots) do
            s.slots[slot] = (s.slots[slot] or 0) + count
        end
    end
end

-- -----------------------------------------------------------------------------
-- Speicher
-- -----------------------------------------------------------------------------

local function GetRecord(zoneId, key, name, kind)
    local zones = WDH_Saved.zones
    zones[zoneId] = zones[zoneId] or {}
    local rec = zones[zoneId][key]
    if not rec then
        rec = { name = name, kind = kind, loots = 0, gold = 0, sets = {}, items = {}, cats = {} }
        zones[zoneId][key] = rec
    end
    return rec
end

local function FindRecord(zoneId, key)
    local zone = WDH_Saved.zones[zoneId]
    return zone and zone[key]
end

-- -----------------------------------------------------------------------------
-- Art der Quelle (nur fuer die Anzeige-Filter, gespeichert wird immer alles)
-- -----------------------------------------------------------------------------
--   enemy     -> Leiche einer Kreatur/eines NPC (IsGameCameraInteractableUnitMonster, wie ZO_PlayLootWindowSound)
--   resource  -> Rohstoffvorkommen (GetInteractionType() == INTERACTION_HARVEST kurz nach der Interaktion,
--                wie HarvestMap)
--   container -> Truhen, Saecke, Faesser, Kisten, Rucksaecke ... (alle uebrigen Lootfenster)
--   theft     -> Diebstahl aus fremdem Besitz (isOwned): Behaelter, Tresore, einzelne Gegenstaende
--   other     -> Taschendiebstahl und "Nehmen" ohne Lootfenster (Kleintiere, einzelne Gegenstaende)

local function IsRecentInteraction(name)
    return WDH_Interact.name == name and Now() - WDH_Interact.at <= INTERACT_VALID_MS
end

local function DetermineSourceType(name, kind)
    local recent = IsRecentInteraction(name)
    if recent and WDH_Interact.itype == INTERACTION_HARVEST then return "resource" end
    if kind == "pickpocket" then return "other" end
    if kind == "theft" then return "theft" end
    -- Bei Lootfenstern ist die Leiche noch das Kamera-Ziel (so nutzt es auch das Spiel fuer den Pluendersound)
    if (kind == "loot" and IsGameCameraInteractableUnitMonster()) or (recent and WDH_Interact.monster) then
        return "enemy"
    end
    if kind == "take" then return "other" end
    return "container"
end

-- -----------------------------------------------------------------------------
-- Sitzung
-- -----------------------------------------------------------------------------

-- Schluessel einer Quelle: Name in Kleinbuchstaben, Diebstahl aus fremdem Besitz getrennt.
-- Auch von der Anzeige genutzt (Ziel am Fadenkreuz mit isOwned).
local function RecordKey(name, isOwned)
    local key = MakeKey(name)
    if isOwned then key = key .. "#theft" end
    return key
end

-- kind: "loot" (Lootfenster), "take" ("Nehmen" ohne Fenster), "pickpocket"
-- isOwned: Quelle gehoert jemandem (Diebstahl) -> eigener Eintrag
local function NewSession(name, targetType, kind, isOwned)
    local fromWindow = kind == "loot"
    if isOwned and kind ~= "pickpocket" then kind = "theft" end
    local sourceType = DetermineSourceType(name, kind)
    local zoneId = (targetType == INTERACT_TARGET_TYPE_ITEM) and 0 or CurrentZoneId()
    local aoe    = IsAoeTarget(targetType)
    local key    = RecordKey(name, kind == "theft")
    if kind == "pickpocket" then
        key = "pickpocket:" .. key
    elseif aoe then
        kind = "aoe"
        key  = key .. "#aoe"
    end
    return {
        name       = name,
        key        = key,
        kind       = kind,
        fromWindow = fromWindow,
        sourceType = sourceType,
        zoneId     = zoneId,
        targetType = targetType,
        aoe        = aoe,
        startedAt  = Now(),
        gold       = 0,
        seen       = {},
        itemIds    = {},  -- angebotene Item-IDs (fuer den Abgleich mit LOOT_RECEIVED)
        sets       = {},
        items      = {},
        cats       = {},
        lines      = {},  -- Debug-Zeilen, ausgegeben beim Abschluss
    }
end

-- Ordnet ein Item der Sitzung zu. Gespeichert wird immer das Item (Item-ID)
-- und seine Kategorie, bei Set-Ausruestung zusaetzlich das Set.
-- Was davon mit Namen angezeigt wird, entscheidet erst die Anzeige.
local function AddItem(session, itemLink, quantity)
    local entry = CAT.Classify(itemLink)
    session.itemIds[entry.itemId] = true

    AddStat(session.items, entry.itemId, quantity, entry.quality, entry.key)
    AddStat(session.cats, entry.key, quantity, entry.quality)
    if entry.setId then
        local s = AddStat(session.sets, entry.setId, quantity, entry.quality)
        s.slots = s.slots or {}
        s.slots[entry.slot] = (s.slots[entry.slot] or 0) + quantity
    end

    session.lines[#session.lines + 1] = string.format(WDH_STRINGS.DEBUG_ITEM,
        itemLink, quantity, CatName(entry.key))
end

-- Eintrag ohne Item-ID (Spur, Sammlungsstueck): id = "lead:<id>" bzw. "n:<Name>"
local function AddNonItem(session, id, quantity, quality, cat)
    AddStat(session.items, id, quantity, quality, cat)
    AddStat(session.cats, cat, quantity, quality)
    session.lines[#session.lines + 1] = string.format(WDH_STRINGS.DEBUG_ITEM,
        ItemName(id), quantity, CatName(cat))
end

local function AddLead(session, antiquityId)
    AddNonItem(session, "lead:" .. antiquityId, 1, GetAntiquityQuality(antiquityId), "LEAD")
end

-- Gold im Lootfenster, eigenes und gestohlenes zusammen.
-- Gleiche Quelle wie Much Smarter AutoLoot (LOOT_SHARED), GetLootCurrency nur als Rueckfall.
local function ReadLootGold()
    if LOOT_SHARED and LOOT_SHARED.GetLootCurrencyInformation then
        local info = LOOT_SHARED:GetLootCurrencyInformation()[CURT_MONEY]
        if not info then return 0 end
        return (info.currencyAmount or 0) + (info.stolenCurrencyAmount or 0)
    end
    local unowned, owned = GetLootCurrency(CURT_MONEY)
    return (unowned or 0) + (owned or 0)
end

local function ReadLootList(session)
    for i = 1, GetNumLootItems() do
        local lootId, name, _, count, _, _, isQuest, _, lootType = GetLootItemInfo(i)
        if lootId and session.prevSeen and session.prevSeen[lootId] then
            -- Schon beim letzten Oeffnen dieser Quelle angeboten (Reste, die liegen geblieben sind)
            session.seen[lootId] = true
            session.reopened     = true
        elseif lootId and not session.seen[lootId] then
            session.seen[lootId] = true
            -- Questitems gehoeren zur Quest, nicht zur Quelle.
            -- Spuren kommen mit Antiquitaeten-ID ueber EVENT_LOOT_RECEIVED.
            local skip = isQuest or lootType == LOOT_TYPE_QUEST_ITEM or lootType == LOOT_TYPE_ANTIQUITY_LEAD
            if not skip then
                local itemLink = GetLootItemLink(lootId, LINK_STYLE_DEFAULT)
                if itemLink and itemLink ~= "" then
                    AddItem(session, itemLink, count)
                else
                    -- Kein Item (z. B. Sammlungsstueck): nach Namen speichern
                    AddNonItem(session, "n:" .. zo_strformat("<<C:1>>", name), count,
                        ITEM_DISPLAY_QUALITY_NORMAL, "NO_ITEM")
                end
            end
        end
    end

    -- Gold: hoechsten gesehenen Wert merken (nach dem Pluendern steht hier 0).
    -- Bei erneut geoeffneter Quelle ist liegen gebliebenes Gold schon gezaehlt.
    if not session.reopened then
        local gold = ReadLootGold()
        if gold > session.gold then session.gold = gold end
    end
end

-- Hat eine erneut geoeffnete Quelle nichts Neues angeboten?
local function IsPureReopen(session)
    return session.reopened and next(session.itemIds) == nil and next(session.items) == nil
        and next(session.cats) == nil and next(session.sets) == nil
end

local function CommitSession(session)
    if session.name == "" then
        dbg(WDH_STRINGS.DEBUG_NO_NAME)
        for _, line in ipairs(session.lines) do dbg(line) end
        return
    end

    -- Gesehene lootIds merken, damit ein erneutes Oeffnen derselben Quelle erkannt wird
    -- (nur Lootfenster; Taschendiebstahl und "Nehmen" ohne Fenster haben keine lootIds)
    if session.fromWindow then
        WDH_Last.lootKey  = session.key
        WDH_Last.lootSeen = session.seen
    end

    if IsPureReopen(session) then
        WDH_Last.closedAt = Now()
        dbg(string.format(WDH_STRINGS.DEBUG_REOPEN, session.name))
        return
    end

    local rec = GetRecord(session.zoneId, session.key, session.name, session.kind)
    rec.loots      = rec.loots + 1
    rec.gold       = rec.gold + session.gold
    rec.targetType = session.targetType
    -- "container" ist der Rueckfall, wenn nichts Genaueres erkannt wurde:
    -- eine einmal erkannte Art (Feind, Rohstoff) wird davon nicht ueberschrieben
    if session.sourceType ~= "container" or rec.type == nil then
        rec.type = session.sourceType
    end
    rec.last       = GetTimeStamp()

    for id, s in pairs(session.sets)  do MergeStat(rec.sets,  id, s) end
    for id, s in pairs(session.items) do MergeStat(rec.items, id, s) end
    for id, s in pairs(session.cats)  do MergeStat(rec.cats,  id, s) end

    WDH_Last.zoneId   = session.zoneId
    WDH_Last.key      = session.key
    WDH_Last.closedAt = Now()
    WDH_Last.itemIds  = session.itemIds
    -- Fuer /wdh ohne Argument auch nach Neustart merken
    WDH_Saved.last = { zoneId = session.zoneId, key = session.key }

    dbg(string.format(WDH_STRINGS.DEBUG_SESSION,
        session.name, ZoneName(session.zoneId), tostring(session.targetType),
        tostring(session.aoe), tostring(IsAoeSettingOn()), session.gold, tostring(session.sourceType)))
    for _, line in ipairs(session.lines) do dbg(line) end

    -- Anzeige am Fadenkreuz beim naechsten Bild neu aufbauen
    if WDH.Hud then WDH.Hud:Invalidate() end
end

-- Spur, die nach dem Schliessen des Lootfensters ankommt, nachtraeglich zuordnen
local function AddLeadToLastRecord(antiquityId)
    local rec = WDH_Last.key and FindRecord(WDH_Last.zoneId, WDH_Last.key)
    if not rec then return false end
    local quality = GetAntiquityQuality(antiquityId)
    MergeStat(rec.items, "lead:" .. antiquityId, { n = 1, q = { [quality] = 1 }, cat = "LEAD" })
    MergeStat(rec.cats, "LEAD", { n = 1, q = { [quality] = 1 } })
    dbg(string.format(WDH_STRINGS.DEBUG_ITEM, ItemName("lead:" .. antiquityId), 1, "Spur -> " .. rec.name))
    return true
end

-- -----------------------------------------------------------------------------
-- Event-Handler
-- -----------------------------------------------------------------------------

-- Laufende Sitzung speichern (LOOT_CLOSED, Zeitueberschreitung, Ladebildschirm)
local function FinishPending()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_Pending")
    if not WDH_Pending then return end
    local session = WDH_Pending
    WDH_Pending = nil
    CommitSession(session)
end

local function FinishSession()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_SessionTimeout")
    if not WDH_Session then return end
    local session = WDH_Session
    WDH_Session = nil
    if session.emptyWindow then
        -- Beute ist noch unterwegs: kurz sammeln, dann speichern
        FinishPending()
        WDH_Pending = session
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Pending", RECEIVED_GRACE_MS, FinishPending)
    else
        CommitSession(session)
    end
end

-- Sitzung, die Beute aus LOOT_RECEIVED/CURRENCY_UPDATE uebernimmt (nur bei leer vorgefundenem Fenster)
local function LateTarget()
    if WDH_Session then
        return WDH_Session.emptyWindow and WDH_Session or nil
    end
    return WDH_Pending
end

-- Im Test kam LOOT_CLOSED nicht immer (vermutlich wenn ein Auto-Loot-Addon das Fenster schliesst).
-- Ohne diese Sicherung bliebe die Sitzung bis zur naechsten Pluenderung offen
-- und ginge bei /reloadui verloren.
-- Ist das Lootfenster noch sichtbar, laeuft die Sitzung weiter (sonst doppelte Zaehlung,
-- wenn danach noch ein LOOT_UPDATED fuer dieselbe Quelle kommt).
local function IsLootWindowShowing()
    return SCENE_MANAGER:IsShowing("loot") or SCENE_MANAGER:IsShowing("lootGamepad")
end

local function ArmSessionTimeout()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_SessionTimeout")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_SessionTimeout", SESSION_TIMEOUT_MS, function()
        if IsLootWindowShowing() then return end
        dbg(WDH_STRINGS.DEBUG_TIMEOUT)
        FinishSession()
    end)
end

local function OnLootUpdated()
    local rawName, targetType, _, isOwned = GetLootTargetInfo()
    local name = FormatTargetName(rawName, targetType)

    -- Manche Behaelter liefern im Lootfenster keinen Namen (z. B. die Truhe am Dunklen Anker).
    -- Gibt es seit Beginn der offenen Sitzung keine neue Interaktion, ist es dasselbe Fenster
    -- (z. B. Update nach dem Nehmen eines Items); sonst die letzte Interaktion nehmen.
    if name == "" then
        local recent = WDH_Interact.name and Now() - WDH_Interact.at <= INTERACT_VALID_MS
        if WDH_Session and not (recent and WDH_Interact.at > WDH_Session.startedAt) then
            name = WDH_Session.name
        elseif recent then
            name = WDH_Interact.name
        end
    end

    if WDH_Session and WDH_Session.name ~= name then
        dbg(WDH_STRINGS.DEBUG_NEW_TARGET)
        FinishSession()
    end
    if not WDH_Session then
        FinishPending()
        WDH_Session = NewSession(name, targetType, "loot", isOwned)
        -- Fenster ohne Ziel und ohne Inhalt: ein Auto-Loot-Addon hat es vor uns geleert und geschlossen
        if rawName == "" and GetNumLootItems() == 0 then
            WDH_Session.emptyWindow = true
            WDH_Session.lines[#WDH_Session.lines + 1] = WDH_STRINGS.DEBUG_LATE
        end
        -- Gleiche Quelle wie zuletzt: liegen gebliebene Reste nicht erneut zaehlen
        if WDH_Last.lootKey == WDH_Session.key then
            WDH_Session.prevSeen = WDH_Last.lootSeen
        end
    end
    ReadLootList(WDH_Session)
    if WDH_Session.emptyWindow and (next(WDH_Session.seen) or WDH_Session.gold > 0) then
        WDH_Session.emptyWindow = false
    end
    ArmSessionTimeout()
end

local function OnLootClosed()
    FinishSession()
end

local function FinishDirectSession()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DirectCommit")
    if not WDH_Direct then return end
    CommitSession(WDH_Direct)
    WDH_Direct = nil
end

-- Beute ohne Lootfenster der letzten Interaktion zuordnen.
-- Rueckgabe false, wenn es keine passende Interaktion gibt.
local function AddDirectLoot(itemLink, quantity)
    if not WDH_Interact.name or Now() - WDH_Interact.at > INTERACT_VALID_MS then
        return false
    end
    -- Neue Interaktion seit der laufenden Sitzung: alte zuerst speichern
    if WDH_Direct and WDH_Direct.interactAt ~= WDH_Interact.at then
        FinishDirectSession()
    end
    if not WDH_Direct then
        WDH_Direct = NewSession(WDH_Interact.name, nil, "take", WDH_Interact.owned)
        WDH_Direct.interactAt = WDH_Interact.at
    end
    AddItem(WDH_Direct, itemLink, quantity)

    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DirectCommit")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_DirectCommit", DIRECT_COMMIT_MS, FinishDirectSession)
    return true
end

-- Nach der Interaktion kurz beobachten, welche Art Interaktion das Spiel startet
-- (Ernten, Schlossknacken ...). Das Lootfenster selbst (INTERACTION_LOOT) zaehlt nicht.
local function PollInteractionType()
    local itype = GetInteractionType()
    if itype ~= INTERACTION_NONE and itype ~= INTERACTION_LOOT and not WDH_Interact.itype then
        WDH_Interact.itype = itype
    end
    if WDH_Interact.itype or Now() - WDH_Interact.at > INTERACT_VALID_MS then
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_InteractType")
    end
end

local function OnInteractionStart()
    local action, name, _, isOwned = GetGameCameraInteractableActionInfo()
    if not name or name == "" then return end
    WDH_Interact.name    = zo_strformat("<<C:1>>", name)
    WDH_Interact.action  = action
    WDH_Interact.at      = Now()
    WDH_Interact.monster = IsGameCameraInteractableUnitMonster()
    WDH_Interact.owned   = isOwned == true
    WDH_Interact.itype   = nil
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_InteractType")
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_InteractType", INTERACT_POLL_MS, PollInteractionType)
    dbg(string.format(WDH_STRINGS.DEBUG_INTERACT, tostring(action), WDH_Interact.name))
end

-- Gold, das ein Auto-Loot-Addon aus einem leer vorgefundenen Fenster genommen hat
local function OnMoneyUpdate(_, newMoney, oldMoney, reason)
    if reason ~= CURRENCY_CHANGE_REASON_LOOT and reason ~= CURRENCY_CHANGE_REASON_LOOT_STOLEN then return end
    local late = LateTarget()
    if late and newMoney > oldMoney then
        late.gold = late.gold + (newMoney - oldMoney)
    end
end

local function OnLootReceived(_, _, itemLink, quantity, _, lootType, isSelf, isPickpocketLoot, _, itemId)
    if not isSelf then return end

    -- Spuren: itemId ist hier die Antiquitaeten-ID
    if lootType == LOOT_TYPE_ANTIQUITY_LEAD then
        local late = LateTarget()
        if late then
            AddLead(late, itemId)
        elseif WDH_Session then
            AddLead(WDH_Session, itemId)
        elseif Now() - WDH_Last.closedAt <= RECEIVED_GRACE_MS then
            AddLeadToLastRecord(itemId)
        else
            dbg(string.format(WDH_STRINGS.DEBUG_NO_WINDOW, ItemName("lead:" .. itemId), 1))
        end
        return
    end

    -- Taschendiebstahl: kein Lootfenster. Opfer ist die letzte Interaktion,
    -- sonst das Ziel unter dem Fadenkreuz
    if isPickpocketLoot then
        local target
        if WDH_Interact.name and Now() - WDH_Interact.at <= INTERACT_VALID_MS then
            target = WDH_Interact.name
        else
            target = GetUnitName("reticleover")
        end
        if target == nil or target == "" then target = WDH_STRINGS.PICKPOCKET_UNKNOWN end
        local session = NewSession(zo_strformat("<<C:1>>", target), nil, "pickpocket")
        if lootType == LOOT_TYPE_ITEM then
            AddItem(session, itemLink, quantity)
        end
        CommitSession(session)
        return
    end

    -- Lootfenster war schon leer: Beute hier zaehlen
    local late = LateTarget()
    if late then
        if lootType == LOOT_TYPE_ITEM then AddItem(late, itemLink, quantity) end
        return
    end

    -- Beute ohne Lootfenster (z. B. Kleintiere mit "Nehmen")
    if not WDH_Session and Now() - WDH_Last.closedAt > RECEIVED_GRACE_MS then
        if lootType == LOOT_TYPE_ITEM and AddDirectLoot(itemLink, quantity) then return end
        dbg(string.format(WDH_STRINGS.DEBUG_NO_WINDOW, tostring(itemLink), quantity))
    elseif WDH_Session and not WDH_Session.itemIds[itemId] then
        -- Waehrend ein Lootfenster offen ist, aber nicht in dessen Liste.
        -- Moeglicher Hinweis auf Flaechenpluendern: Beute anderer Leichen direkt ins Inventar?
        dbg(string.format(WDH_STRINGS.DEBUG_DURING_WINDOW, tostring(itemLink), quantity, WDH_Session.name))
    elseif not WDH_Session and not WDH_Last.itemIds[itemId] then
        -- Kurz nach einem Lootfenster, aber nicht in dessen Liste: sollte nicht vorkommen.
        -- (Items aus der Liste kommen regelmaessig erst nach LOOT_CLOSED an, die sind bereits gezaehlt.)
        dbg(string.format(WDH_STRINGS.DEBUG_AFTER_WINDOW, tostring(itemLink), quantity))
    end
end

-- -----------------------------------------------------------------------------
-- Ausgabe
-- -----------------------------------------------------------------------------

local function QualityList(q)
    local parts = {}
    local highest = ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE or ITEM_DISPLAY_QUALITY_LEGENDARY
    for quality = ITEM_DISPLAY_QUALITY_TRASH, highest do
        if q[quality] then
            parts[#parts + 1] = ColorByQuality(quality, string.format("%s %d", QualityName(quality), q[quality]))
        end
    end
    return table.concat(parts, ", ")
end

local function BestQuality(q)
    local best = ITEM_DISPLAY_QUALITY_NORMAL
    for quality in pairs(q) do
        if quality > best then best = quality end
    end
    return best
end

-- -----------------------------------------------------------------------------
-- Schnittstelle fuer WDH_Hud.lua
-- -----------------------------------------------------------------------------

WDH.CurrentZoneId  = CurrentZoneId
WDH.MakeKey        = MakeKey
WDH.RecordKey      = RecordKey
WDH.FindRecord     = FindRecord
WDH.ItemName       = ItemName
WDH.SetName        = SetName
WDH.CatName        = CatName
WDH.ColorByQuality = ColorByQuality
WDH.BestQuality    = BestQuality
WDH.QualityName    = QualityName
WDH.SHOW_OFF       = SHOW_OFF

-- Anzeige-Einstellungen des eingeloggten Charakters
function WDH.Settings()
    return WDH_Saved.chars[WDH.charId].settings
end

-- Andere Charaktere des Accounts mit gespeicherten Einstellungen: Namen und IDs, sortiert.
-- Geloeschte Charaktere fallen heraus, umbenannte erscheinen mit aktuellem Namen.
function WDH.OtherCharacters()
    local list = {}
    for i = 1, GetNumCharacters() do
        local name, _, _, _, _, _, id = GetCharacterInfo(i)
        if id ~= WDH.charId and WDH_Saved.chars[id] then
            list[#list + 1] = { name = zo_strformat("<<1>>", name), id = id }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local names, ids = {}, {}
    for _, c in ipairs(list) do
        names[#names + 1] = c.name
        ids[#ids + 1]     = c.id
    end
    return names, ids
end

-- Uebernimmt die Anzeige-Einstellungen eines anderen Charakters
function WDH.CopySettingsFrom(charId)
    local source = WDH_Saved.chars[charId]
    if not source or charId == WDH.charId then return false end
    WDH_Saved.chars[WDH.charId].settings = CopyDisplay(source.settings)
    if WDH.Hud then WDH.Hud:Invalidate() end
    return true
end

function WDH:PrintRecord(zoneId, rec)
    local header = string.format(WDH_STRINGS.RECORD_HEADER, rec.name, ZoneName(zoneId), rec.loots, rec.gold)
    if rec.kind == "aoe" then header = header .. WDH_STRINGS.RECORD_AOE end
    if rec.kind == "pickpocket" then header = header .. WDH_STRINGS.RECORD_PICKPOCKET end
    if rec.kind == "theft" then header = header .. WDH_STRINGS.RECORD_THEFT end
    d(WDH_STRINGS.PREFIX .. header)

    for setId, s in pairs(rec.sets) do
        local slots = {}
        for slot, count in pairs(s.slots or {}) do
            slots[#slots + 1] = string.format("%s %d", WDH_SLOT_NAMES[slot] or slot, count)
        end
        d(string.format(WDH_STRINGS.RECORD_SET,
            ColorByQuality(BestQuality(s.q), SetName(setId)), table.concat(slots, ", "),
            s.n, s.hits, rec.loots, QualityList(s.q)))
    end
    -- Kategorien, darunter eingerueckt ihre Items (Set-Teile stehen oben schon pro Set)
    local itemsByCat = {}
    for id, s in pairs(rec.items) do
        local cat = s.cat or ""
        if cat ~= "SET" then
            itemsByCat[cat] = itemsByCat[cat] or {}
            table.insert(itemsByCat[cat], { id = id, s = s })
        end
    end
    local function PrintItems(list, format)
        for _, e in ipairs(list or {}) do
            d(string.format(format, ColorByQuality(BestQuality(e.s.q), ItemName(e.id)),
                e.s.n, e.s.hits, rec.loots, QualityList(e.s.q)))
        end
    end
    for key, s in pairs(rec.cats) do
        if key ~= "SET" then
            d(string.format(WDH_STRINGS.RECORD_LINE, CatName(key), s.n, s.hits, rec.loots, QualityList(s.q)))
            PrintItems(itemsByCat[key], WDH_STRINGS.RECORD_ITEM)
            itemsByCat[key] = nil
        end
    end
    -- Items ohne Kategorie (Daten aus Version 0.1 vor dem Speichern aller Item-IDs)
    for _, list in pairs(itemsByCat) do
        PrintItems(list, WDH_STRINGS.RECORD_LINE)
    end
end

local function SearchZones(needle, zoneIds, found)
    for _, zoneId in ipairs(zoneIds) do
        for key, rec in pairs(WDH_Saved.zones[zoneId] or {}) do
            if zo_plainstrfind(key, needle) then
                found[#found + 1] = { zoneId = zoneId, rec = rec }
            end
        end
    end
end

-- Sucht Quellen, deren Name den Suchtext enthaelt: zuerst aktuelle Zone und
-- Inventar-Behaelter, ohne Treffer dort in allen Zonen
local function SearchRecords(text)
    local needle = zo_strlower(text)
    local found  = {}
    local here   = CurrentZoneId()
    SearchZones(needle, { here, 0 }, found)
    if #found == 0 then
        local others = {}
        for zoneId in pairs(WDH_Saved.zones) do
            if zoneId ~= here and zoneId ~= 0 then others[#others + 1] = zoneId end
        end
        SearchZones(needle, others, found)
    end
    return found
end

-- Zonen mit gespeicherten Daten im Chat auflisten (/wdh_zones, Menue)
function WDH:PrintZones()
    d(WDH_STRINGS.ZONES_HEADER)
    local any = false
    for zoneId, zone in pairs(WDH_Saved.zones) do
        local sources, loots = 0, 0
        for _, rec in pairs(zone) do
            sources = sources + 1
            loots   = loots + rec.loots
        end
        if sources > 0 then
            any = true
            d(string.format(WDH_STRINGS.ZONES_ENTRY, ZoneName(zoneId), sources, loots))
        end
    end
    if not any then d(WDH_STRINGS.RECORD_NONE) end
end

-- Alle gesammelten Daten loeschen, Einstellungen bleiben (/wdh_reset ja, Menue)
function WDH:ResetData()
    WDH_Saved.zones = {}
    WDH_Saved.last  = nil
    WDH_Last.zoneId, WDH_Last.key = nil, nil
    WDH_Last.lootKey, WDH_Last.lootSeen = nil, nil
    WDH.Hud:Invalidate()
    d(WDH_STRINGS.RESET_DONE)
end

-- -----------------------------------------------------------------------------
-- Slash-Befehle
-- -----------------------------------------------------------------------------

local function RegisterSlashCommands()
    SLASH_COMMANDS["/wdh"] = function(args)
        args = args and zo_strtrim(args) or ""
        if args == "" then
            local rec = WDH_Last.key and FindRecord(WDH_Last.zoneId, WDH_Last.key)
            if not rec then
                d(WDH_STRINGS.RECORD_NO_LAST)
                return
            end
            WDH:PrintRecord(WDH_Last.zoneId, rec)
            return
        end
        local found = SearchRecords(args)
        if #found == 0 then
            d(WDH_STRINGS.RECORD_NONE)
            return
        end
        for _, entry in ipairs(found) do
            WDH:PrintRecord(entry.zoneId, entry.rec)
        end
    end

    SLASH_COMMANDS["/wdh_zone"] = function()
        local zoneId = CurrentZoneId()
        d(string.format(WDH_STRINGS.ZONE_HEADER, ZoneName(zoneId)))
        local zone = WDH_Saved.zones[zoneId]
        if not zone or next(zone) == nil then
            d(WDH_STRINGS.RECORD_NONE)
            return
        end
        for _, rec in pairs(zone) do
            local name = rec.name
            if rec.kind == "aoe" then name = name .. WDH_STRINGS.RECORD_AOE end
            if rec.kind == "pickpocket" then name = name .. WDH_STRINGS.RECORD_PICKPOCKET end
            if rec.kind == "theft" then name = name .. WDH_STRINGS.RECORD_THEFT end
            d(string.format(WDH_STRINGS.ZONE_ENTRY, name, rec.loots))
        end
    end

    SLASH_COMMANDS["/wdh_zones"] = function()
        WDH:PrintZones()
    end

    SLASH_COMMANDS["/wdh_hud"] = function()
        WDH.Settings().hud = not WDH.Settings().hud
        d(WDH.Settings().hud and WDH_STRINGS.HUD_ON or WDH_STRINGS.HUD_OFF)
    end

    SLASH_COMMANDS["/wdh_units"] = function()
        WDH.Settings().hudUnits = not WDH.Settings().hudUnits
        WDH.Hud:Invalidate()
        d(WDH.Settings().hudUnits and WDH_STRINGS.HUD_UNITS_ON or WDH_STRINGS.HUD_UNITS_OFF)
    end

    SLASH_COMMANDS["/wdh_show"] = function(args)
        local quality = tonumber(args)
        if not quality or quality < ITEM_DISPLAY_QUALITY_TRASH or quality > ITEM_DISPLAY_QUALITY_LEGENDARY then
            d(WDH_STRINGS.SHOW_USAGE)
            return
        end
        -- Gilt fuer alle eingeschalteten Arten; einzeln im Menue
        local settings = WDH.Settings()
        for key in pairs(LEGACY_TYPE_SWITCH) do
            if settings[key] ~= SHOW_OFF then settings[key] = quality end
        end
        WDH.Hud:Invalidate()
        d(string.format(WDH_STRINGS.SHOW_SET, ColorByQuality(quality, QualityName(quality))))
    end

    SLASH_COMMANDS["/wdh_debug"] = function()
        WDH_Saved.settings.debug = not WDH_Saved.settings.debug
        d(WDH_Saved.settings.debug and WDH_STRINGS.DEBUG_ON or WDH_STRINGS.DEBUG_OFF)
    end

    SLASH_COMMANDS["/wdh_names"] = function(args)
        local quality = tonumber(args)
        if not quality or quality < ITEM_DISPLAY_QUALITY_TRASH or quality > ITEM_DISPLAY_QUALITY_LEGENDARY then
            d(WDH_STRINGS.NAMES_USAGE)
            return
        end
        WDH.Settings().nameQuality = quality
        WDH.Hud:Invalidate()
        d(string.format(WDH_STRINGS.NAMES_SET, ColorByQuality(quality, QualityName(quality))))
    end

    SLASH_COMMANDS["/wdh_reset"] = function(args)
        -- "yes" funktioniert in jeder Sprache, dazu das Wort der Client-Sprache ("ja")
        local answer = zo_strlower(zo_strtrim(args or ""))
        if answer ~= "yes" and answer ~= WDH_STRINGS.RESET_CONFIRM then
            d(WDH_STRINGS.RESET_USAGE)
            return
        end
        WDH:ResetData()
    end
end

-- -----------------------------------------------------------------------------
-- Initialisierung
-- -----------------------------------------------------------------------------

-- Bis 0.2 lagen die Anzeige-Einstellungen Account-weit in WDH_Saved.settings.
-- Sie werden zur Vorlage, mit der jeder Charakter beim ersten Einloggen startet.
local function MigrateAccountDisplay()
    local old = WDH_Saved.settings
    if old.showQuality == nil and old.hud == nil then return end
    local template = {}
    for k in pairs(DEFAULT_DISPLAY) do template[k] = old[k] end
    for key, switch in pairs(LEGACY_TYPE_SWITCH) do
        if old[switch] == false then
            template[key] = SHOW_OFF
        else
            template[key] = old.showQuality
        end
        old[switch] = nil
    end
    for k in pairs(DEFAULT_DISPLAY) do old[k] = nil end
    old.showQuality = nil
    WDH_Saved.template = CopyDisplay(template)
end

local function InitSaved()
    if type(WDH_Saved) ~= "table" then WDH_Saved = {} end
    WDH_Saved.version  = SAVED_VERSION
    WDH_Saved.settings = WDH_Saved.settings or {}
    MigrateAccountDisplay()
    FillDefaults(WDH_Saved.settings, DEFAULT_ACCOUNT)

    -- Anzeige-Einstellungen je Charakter (ID bleibt bei Umbenennung gleich)
    WDH_Saved.chars = WDH_Saved.chars or {}
    local charId = GetCurrentCharacterId()
    local char = WDH_Saved.chars[charId]
    if not char then
        char = { settings = CopyDisplay(WDH_Saved.template or DEFAULT_DISPLAY) }
        WDH_Saved.chars[charId] = char
    end
    char.name = zo_strformat("<<1>>", GetUnitName("player"))
    FillDefaults(char.settings, DEFAULT_DISPLAY)
    WDH.charId = charId

    WDH_Saved.zones = WDH_Saved.zones or {}
    if WDH_Saved.last then
        WDH_Last.zoneId = WDH_Saved.last.zoneId
        WDH_Last.key    = WDH_Saved.last.key
    end
end

local function RegisterLootTracking()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootUpdated",  EVENT_LOOT_UPDATED,  OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootClosed",   EVENT_LOOT_CLOSED,   OnLootClosed)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LootReceived", EVENT_LOOT_RECEIVED, OnLootReceived)
    -- Vor Ladebildschirm, /reloadui und Logout offene Sitzungen sichern
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Money",        EVENT_MONEY_UPDATE,  OnMoneyUpdate)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Deactivated",  EVENT_PLAYER_DEACTIVATED, function()
        FinishSession()
        FinishPending()
        FinishDirectSession()
    end)
    -- Quelle fuer Beute ohne Lootfenster merken. Der Hook gibt nichts zurueck,
    -- die Interaktion laeuft also normal weiter.
    ZO_PreHook(INTERACTIVE_WHEEL_MANAGER, "StartInteraction", OnInteractionStart)
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME .. "_Loaded",
    EVENT_ADD_ON_LOADED,
    function(_, addonName)
        if addonName ~= ADDON_NAME then return end
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME .. "_Loaded", EVENT_ADD_ON_LOADED)
        if WDH_Initialized then return end
        WDH_Initialized = true

        InitSaved()
        RegisterLootTracking()
        RegisterSlashCommands()
        WDH.Hud:Init()
        WDH.Menu:Init()
    end
)
