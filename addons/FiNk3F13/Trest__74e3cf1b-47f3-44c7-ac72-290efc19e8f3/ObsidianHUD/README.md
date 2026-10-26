# Obsidian HUD 0.7.2

Fantasy-HUD fuer ESO mit Ressourcenbalken, Klassenemblem und Skillrahmen.
Benoetigt LibHarvensAddonSettings ab Version 20200.

Einstellungen: Obsidian HUD im Addon-Einstellungsmenue.
Unter Skill-HUD-Ansicht stehen Standard, Nur laufende Skills,
Beide Reihen gleich gross, Frontbar oben, Backbar unten und
Doppel-Ultimate mit Aufladerahmen zur Auswahl.
Move UI verschiebt Ressourcen, Skills, Ultimate, Traenke und Buffanzeige.
Die bisherigen Ansichten zeigen nur die aktive Ultimate, ohne zusaetzliche Ultimate-Vorschau.
Bei Frontbar oben, Backbar unten sitzt sie rechts mittig zwischen den Reihen
und behaelt ihre fruehere native Groesse und goldene Darstellung.
Move UI haelt diese vertikale Zentrierung; horizontal bleibt die Ultimate separat verschiebbar.
Die Tasten stehen weiterhin
unter der unteren Reihe; die Ultimate-Waffenwechselanimation bleibt dort aus.

Die zusaetzliche Ansicht Doppel-Ultimate mit Aufladerahmen behaelt feste Skillreihen
und zeigt beide Ultimate-Felder, Front-Ultimate leicht nach oben und Back-Ultimate
nach unten versetzt. Ein goldener Rahmen fuellt sich auf beiden Feldern im
Uhrzeigersinn anhand aktueller Ultimate-Punkte und der jeweiligen Leistenkosten.
Der native goldene Ueberrahmen wird nur hier ersetzt, damit beide Felder einheitlich
aussehen. Tasten bleiben unter der unteren Ultimate; die untere Bildschirmgrenze
beruecksichtigt beide Felder. Keine weiteren Einstellungsregler erforderlich.
Lokale Tests pruefen Leistenkosten, Aufladestand, Positionen, Waffenwechsel und
die unveraenderte Einzel-Ultimate-Ansicht. Eine Sichtpruefung im Spiel steht aus.

Nach Lua-Aenderungen /reloadui eingeben. Bei geaenderten DDS-Grafiken
ESO vollstaendig neu starten.

Der Addon-Ordner enthaelt die Laufzeitdateien und benoetigten Grafiken.
Tests, Grafikgeneratoren, Vorschaubild, Klassen-Prompts und die bisherige
Entwicklungshistorie liegen ausserhalb von AddOns unter:

    ../../ObsidianHUD-Development/

Alle Entwicklungspruefungen lassen sich dort mit run_checks.py ausfuehren.
