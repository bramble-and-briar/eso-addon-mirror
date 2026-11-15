# LiveBuffUptime2 - Konsolenfassung mit eingebauter LibCombat

2.4.15: Startfehler durch Zugriff auf geschuetzte ESO-Globals behoben.
Konstanten werden ausschliesslich explizit verbunden.

2.4.14-integriert.1: Vollstaendige PC-LibCombat v87 direkt eingebaut, inklusive
DoT-Fix aus CMX2. Eigener Bibliotheksname und eigene Konstanten verhindern
Konflikte mit CMX2, LibCombat und LibCombat2. Externe Combat-Bibliotheken werden
nicht verwendet. LibHarvensAddonSettings bleibt erforderlich.
Einstellungen und gespeicherte Berichte bleiben erhalten.
Pruefung im Spiel: /lbu2 status (LibCombat eingebaut, Version 87, DoT-Fix 1).

Aeltere Versionen:

2.4.13: LibCombat2 ist wieder Pflichtabhaengigkeit und wird bevorzugt.
Die Konsolen-Bridge wird geladen; LibCombat bleibt optional fuer lokale PC-Tests.
Krits und Maximalwerte werden auch aus nativen Konsolentreffern gespeichert.
Skills-Spalten und bestehende Berechnungen bleiben erhalten.


2.4.12: Skills-Tabelle um Krits/Treffer, Krit-Prozent, Durchschnitt und
Maximalwert erweitert. Neue PC-Kaempfe erfassen Krits und Max pro Skill und
Gegner aus LibCombat; der Durchschnitt ist Schaden / Treffer. Alte Berichte
zeigen fuer nicht gespeicherte Krit-/Max-Daten einen Strich. Buff-/Debuff-Layout
und die vorhandene DPS-Zeitbasis bleiben erhalten.

2.4.11: Benoetigt LibCombat (v1) und LibHarvensAddonSettings.
Verwendet immer LibCombat, auch wenn LibCombat2 installiert ist.
Die Konsolen-Bridge wird nicht geladen. Skill-Schaden, DPS und die
Boss-/Add-Auswahl bleiben enthalten; SavedVariables werden beibehalten.

Eigener Addon-Name, eigene Lua-Globals, eigene Steuerelemente und eigene
SavedVariables (LiveBuffUptime2_SavedVariables) verhindern Konflikte mit
der Konsolenversion. Einstellungen und Kampfberichte starten separat.

Befehle: /lbu2 uptime, /lbu2 move, /lbu2 reset, /lbu2 status.
Die Statistikansicht verwendet weiterhin das Controller-Layout.

Skills: Links Alle Ziele oder einen einzelnen Gegner waehlen. Rechts dessen Skill-Schaden, Treffer und DPS-Anteil; unten bleibt der Gesamtschaden sichtbar. Neue Kaempfe erforderlich fuer die Ziel-Aufteilung.

Einzelziel-DPS folgen der CMX-Zielzeit aus LibCombat. Skill-Zeilen verwenden weiterhin die Gesamtzeit. Einzelziel-DPS sind keine addierbaren Gesamt-DPS-Anteile.

Schaden und DPS werden ausschliesslich unten angezeigt: Alle Ziele zeigt Gesamtwerte, ein ausgewaehlter Gegner seine eigenen Werte.

Boss-Auswahl: Boss-Schaden und Skill-DPS verwenden dieselbe separat erfasste Gruppen-Kampfzeit. Neue Kaempfe erforderlich. Alle Ziele behalten LibCombats aktive Zeit fuer den CMX-Vergleich.
