ICNextBossTelVar 1.5.1-console

Ein gemeinsames Addon mit .addon-Manifest, Boss-Anzeige und Tel-Var-Bankautomatik.
LAM bietet die Boss-Panel-Position per X/Y-Regler, Gruppensichtungen (experimentell) und die Tel-Var-Einstellungen.

BOSSTIMER: unknown bis zu einer sicheren lebenden Sichtung oder einem qualifizierten Todesfall.
Ein lokaler Countdown startet NUR, wenn das Addon eigenen positiven Schaden am Boss ueber EVENT_COMBAT_EVENT erkannt hat und maximal 120 Sekunden spaeter dessen Tod erkannt wird. Bei vorhandenen Unit-IDs muessen diese uebereinstimmen. Der reine Blick auf eine Leiche startet keinen Countdown. Erkennung fremder Gruppenschadensereignisse ist nicht garantiert; Gruppenmitglieder koennen eigene Treffer lokal erfassen.
ready: lebender Boss innerhalb der letzten 45 Sekunden gesehen (lokal). Die Anzeige garantiert nicht dessen gegenwaertiges Leben. Nach Ablauf eines Countdowns mit zuvor bestaetigtem Tod wird ready angezeigt (geschaetzter Respawn, nicht serverbestaetigt). Ohne bestaetigten Tod oder aktuelle Lebendsichtung bleibt unknown.
15 Minuten sind ein Richtwert; das Spiel liefert keine dokumentierte allgemeine Respawn-Uhrzeit ueber die Addon-API. Eventbedingte Spawnzeiten koennen abweichen.

GRUPPENSYNC: Die Schnittstelle fuer LibGroupBroadcast ist vorbereitet. Fuer ein funktionierendes Broadcast-Protokoll MUSS eine eindeutige Protokoll-ID auf https://wiki.esoui.com/LibGroupBroadcast_IDs reserviert werden. Bis dahin bleibt die Uebertragung bewusst deaktiviert, auch wenn die LAM-Option eingeschaltet ist. Das verhindert ID-Kollisionen. LibGroupBroadcast ist nicht enthalten.

ACHTUNG: Noch nicht auf Konsole getestet. Event-Beschraenkungen koennen dazu fuehren, dass unbekannt angezeigt wird statt falscher Countdownwerte.


PSN-WHITELIST (v1.5.2):
Nur die PSN-IDs jh20405270 und xNoXreAson sind freigegeben.
Pruefung erfolgt beim Laden mittels des von ESO zurueckgegebenen
Account-Displaynamens (GetDisplayName). Ein optionales fuehrendes @
wird entfernt, Gross-/Kleinschreibung ignoriert. Keine Freigabe bei
fehlender/nicht passender Identitaet. Kein sicherer Kopierschutz.
Keine Garantie, dass die Konsolen-API in jeder Plattformkonfiguration
den PSN-Namen exakt wie erwartet zurueckgibt. Ingame-Test erforderlich.

Version 1.5.3: Der Addon-Listen-Autor lautet Bugged. Das LAM-Menue heisst IC Helper by JH und wird nur bei erfolgreicher PSN-Whitelistpruefung registriert.


Version 1.5.5: BUGGED / Autor j.hhh / LAM IC Helper by JH.
LAM bietet X/Y-Position, Boss-Panel-Groesse 50-200 Prozent sowie Maus-Ziehmodus.
Auf der PlayStation bitte X/Y-Regler verwenden (keine Maus notwendig).
Tel Var Saver hat KEIN HUD-Element und arbeitet nur beim Bank-Oeffnen im Hintergrund.
PSN-Whitelist unveraendert. Gruppensynchronisierung weiterhin deaktiviert ohne reservierte Protokoll-ID.


Version 1.5.7: Konsolen-Waehrungs-API via GetCurrencyAmount/TransferCurrency statt veralteter Funktionen. Tel Var 0 bis 10000, 1000er Schritte, kein HUD. Boss-Panel 690x330, Gamepad-Schrift, Skalierung. Original-Boss-Erkennung ueber Todesmeldung / Lebend-zu-Tot-Fallback; ready/unknown. Gruppensynchronisierung nicht aktiv ohne registrierte ID.

Version 1.6.3: LAM-Schalter "Boss-Timer ueberall anzeigen" (Standard AUS). Boss-Panel kann auch ausserhalb von IC angezeigt werden; Respawn-Endzeiten laufen weiter. Boss-Events nur in IC.

1.6.3: Optionale IC-Flaggenstatus-Spalte: EP/AD/DC und unknown, nur in IC live abfragbar.

Flaggenstatus: nur in IC; ausserhalb unknown. Innerhalb bei gemeldetem Angriff: under attack (orange).
