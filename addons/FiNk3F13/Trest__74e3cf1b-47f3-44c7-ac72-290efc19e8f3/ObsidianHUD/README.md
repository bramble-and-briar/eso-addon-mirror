# Obsidian HUD 0.4.0

Fantasy-Design fuer ESO-PC und Controller-/Konsolenoberflaeche. Eigene Metallrahmen mit abgeschraegten Enden, drei gestaffelte Ressourcenbalken und ein seitliches Emblem. Der vorherige rechteckige Panel-Hintergrund ist ausgeblendet. Die aktive Skillleiste bekommt quadratische Rahmen um die echten ESO-Icons; eine zweite Reihe zeigt die inaktive Waffenleiste. Die zweite Reihe ist eine Vorschau und stellt keine zusaetzlichen gleichzeitig nutzbaren Skills bereit.

## Ausprobieren

Version 0.4.0 ergaenzt unter Einstellungen > Addons > Obsidian HUD > HUD-Elemente einzeln verschieben vier weitere Move-UI-Buttons: Skillleiste (fuenf Skills samt ihrer Backbar-Vorschau), Ultimate samt Vorschau, Traenke/Schnellzugriff und die eigene native ESO-Buffanzeige. Ein markierter Verschieberahmen wird per Maus oder rechtem Stick bewegt. Nach drei Sekunden ohne Bewegung endet der Modus und speichert. Die Positionen werden fuer Tastatur- und Controlleroberflaeche getrennt und relativ zur UI-Groesse gespeichert. Das Haupt-HUD und native Menues werden nicht kuenstlich sichtbar geschaltet; der Verschieberahmen bleibt auch im Einstellungsmenue sichtbar. Im HUD sind danach die echten Symbole an der gewaehlten Position. Native Tastenbelegungen, Klick-Handler und Bufflogik bleiben bestehen. Beim Deaktivieren werden die vorherigen Anker wiederhergestellt; der Reset-Button entfernt die gespeicherten vier HUD-Positionen. /reloadui genuegt, neue Bilddateien wurden nicht hinzugefuegt.

Direktbefehle: /obsidian move skills, /obsidian move ult, /obsidian move pots und /obsidian move buffs. /obsidian move verschiebt weiterhin die Ressourcenanzeige. Lokale Tests pruefen alle vier Ziele, unveraenderte native Eingabehandler, Cursor-Rueckgabe, Speichern, Wiederherstellen, 30 simulierte Layoutwechsel, Aufloesungswechsel und getrennte Tastatur-/Controllerprofile. Ein Sichttest im Spiel bzw. auf PS5 steht aus.

Version 0.3.9 stellt die HUD-Schrift auf reines Weiss mit kraeftigerem dunklem Schatten (soft-shadow-thick). Positionen, Ausrichtung und Schriftgroessen bleiben unveraendert. /reloadui genuegt.

Version 0.3.8 korrigiert die Texthoehe gegenueber 0.3.7 um zwei UI-Einheiten nach oben. Die gemeinsame linke Position der Ressourcennamen bleibt bestehen. Die kleinen erhoehten Zierspitzen an den oberen Balkenkanten entfallen. Wegen der Rahmen-DDS-Aenderung ESO vollstaendig neu starten.

Version 0.3.7 verschiebt nur die Ressourcennamen und Zahlen samt Prozenten um drei UI-Einheiten nach unten, zur optischen Mitte der Fuellung. Alle drei Ressourcennamen beginnen jetzt auf derselben linken Position. Werte bleiben rechtsbuendig; Schrift, Farben und Charaktername sind unveraendert. /reloadui genuegt.

Version 0.3.6 nimmt die Textaenderungen aus 0.3.5 zurueck. Ressourcennamen, Werte, Schrift und Charaktername verwenden wieder die Anordnung aus 0.3.4. /reloadui genuegt.

Version 0.3.4 bestimmt die Ressourcenreihenfolge nur anhand der Maximalwerte auf der primaeren Waffenleiste (Frontbar). Die Backbar aktualisiert weiterhin Zahlen und Fuellstaende, veraendert aber nicht die Reihenfolge. Die Frontbar-Auswahl wird pro Charakter gespeichert, damit sie bei einem UI-Neuladen auf der Backbar erhalten bleibt. Beim ersten Start ohne gespeicherte Frontbar-Auswahl gilt Magicka als vorlaeufige Mitte, bis die Frontbar verfuegbar ist. Gleichstand oder noch unvollstaendige Maximalwerte veraendern die letzte Reihenfolge nicht. /reloadui genuegt fuer dieses Lua-Update.

Version 0.3.3 ersetzt die eckige Glanzlinie oben links im Rundemblem durch einen echten Kreisbogen. Die kleinen I/II-Markierungen ueber den Backbar-Skills entfallen. Wegen der geaenderten Rahmen-DDS ESO vollstaendig neu starten.

Version 0.3.2 vergroessert die Motive klassenweise innerhalb einer runden Portraetmaske. Arkanist erhaelt den staerksten Motivzoom (27 Prozent), Nachtklinge 18 Prozent; die uebrigen Motive 6 bis 10 Prozent. Das Portraetfenster steigt von 72 auf 77 UI-Einheiten. Aeussere Verzierungen werden an der inneren Kreisflaeche begrenzt und nicht ueber den Metallrahmen gezeichnet. Die 256-Pixel-Aufloesung pro Symbol bleibt erhalten. DDS-Tests pruefen die sichtbare Kontur auch in UI-Einheiten gegen den Innenradius. Wegen der geaenderten DDS-Textur ESO vollstaendig neu starten.

Version 0.3.1 passt jedes Klassensymbol anhand seiner sichtbaren Alpha-Kontur einzeln ein und zentriert es im kreisfoermigen Sicherheitsbereich. 256 statt 128 Pixel pro Symbol bewahren mehr Details aus den unveraenderten Originalmotiven. Der 1024x512-DXT3-Atlas braucht 524.416 Bytes. Im runden Emblem entfaellt das bisherige Hintergrundwappen, damit es nicht hinter schmalen Motiven durchscheint. Wegen der geaenderten Texturgroesse ESO vollstaendig neu starten. Die lokalen Tests pruefen auch den Abstand der sichtbaren Kontur zur Kreisgrenze. Die neue Darstellung im Spiel muss noch bestaetigt werden.

Version 0.3.0 ergaenzt sieben eigene Klassensymbole: Drachenritter (Drachenfeuer), Zauberer (Sturm-Rune), Nachtklinge (Schattenklingen), Templer (Sonne und Lanze), Hueter (Baer und Natur), Nekromant (Seelenschaedel), Arkanist (Buch und Auge). Sie wurden mit dem eingebauten Imagegen-Werkzeug erstellt. Die vollstaendigen Prompts stehen in docs/class-emblem-prompts.json. Die Laufzeitgrafik art/class_emblems.dds packt alle sieben Motive in eine transparente 512x256-DXT3-Textur mit 131.200 Bytes. Die Charakterklasse waehlt das passende Atlasfeld automatisch, unabhaengig von Sprache und Controlleroberflaeche. Der Schalter Eigene Klassensymbole wechselt zu den normalen ESO-Icons. Solange der Atlas nicht geladen ist, bleibt das native Icon sichtbar; unbekannte Klassen erhalten das native Icon bzw. das vorhandene Wappen. Wegen des neuen DDS-Pfads ESO vollstaendig neu starten. Lokale Tests fuer alle sieben Klassenzuordnungen, Umschalten und verzögertes Laden bestehen; der Sichttest im Spiel steht aus.

Version 0.2.8 aktualisiert die Skillvorschau direkt bei EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, ohne auf den 250-ms-Abgleich zu warten. Ein einmaliger Abgleich im Folgeframe beruecksichtigt ESOs eigene Ereignisverarbeitung; schnelle weitere Wechsel ersetzen den ausstehenden Abgleich. Der 250-ms-Timer bleibt fuer laufende Restzeiten und die allgemeine Sichtbarkeit erhalten. Aktualisiert wird der vom Spiel bestaetigte Wechsel, auch bei Controllerbedienung; ein abgelehnter Tastendruck taeuscht keinen erfolgreichen Wechsel vor. /reloadui genuegt fuer dieses Lua-Update.

Version 0.2.7 stimmt Rundemblem und untere Aussparung auf denselben Mittelpunkt und Radius ab. Das runde Emblem ist 100 statt 86 UI-Einheiten gross, damit die drei Balken innerhalb seiner Hoehe anschliessen. Die Kurve wird als feste linke Kappe gezeichnet; Aenderungen der Balkenbreite verlaengern nur den geraden Teil. Fuellung und Rahmen verwenden dieselbe Kontur. Die Levelzahl steht mit Abstand darunter. Nach dieser Texturaenderung ESO vollstaendig neu starten. DDS-Kontur und lokale Lua-Tests fuer verschiedene Breiten und Ressourcenstaende bestehen; ein neuer Sichttest im Spiel steht aus.

Version 0.2.6 verwendet beim runden Emblem fuer den untersten Balken eigene DDS-Grafiken mit einer konkaven linken Kurve in Rahmen und Fuellung. Neue Grafikdateien erfordern einen vollstaendigen Spielneustart. Die Kurve bleibt an der untersten Position, auch wenn Magicka und Ausdauer ihre Reihenfolge tauschen.

Unter Einstellungen > Addons > Obsidian HUD > Ressourcen-HUD > Move UI laesst sich die gesamte Ressourcenanzeige (Leben, Magicka, Ausdauer und Emblem) verschieben. Mit der Maus ziehen oder den rechten Controller-Stick bewegen. Hilfslinien markieren die Bildschirmmitte. Nach drei Sekunden ohne Bewegung endet der Modus und speichert die Position. Alternativ /obsidian move eingeben; derselbe Befehl beendet einen laufenden Verschiebemodus. Vorher bereits aktive Menue-/Cursormodi bleiben erhalten. /reloadui laedt Version 0.2.4; neue Grafikdateien wurden nicht hinzugefuegt.

Der Ordner liegt in `pts/AddOns/ObsidianHUD`. Da es ein neuer Addonordner ist, ESO neu starten und Obsidian HUD sowie LibHarvensAddonSettings 2.2.0 oder neuer aktivieren. Dann unter Einstellungen > Addons > Obsidian HUD anpassen. Fuer den Live-PC muss derselbe Ordner nach `live/AddOns` kopiert werden. Lokale Dateien aktualisieren keine PlayStation-Installation.

`/obsidian off` schaltet das Design aus und gibt die originalen Ressourcenanzeigen und Skilldekorationen wieder frei. `/obsidian on` schaltet es ein. Ohne Argument wird umgeschaltet. Das geht auch ueber die Controller-Einstellungen.

## Enthalten

- Leben, Magicka und Ausdauer mit Ist-/Maximalwert und Prozent.
- Helle Schildlinie auf dem Lebensbalken, wenn die ESO-Visualisierungsabfrage einen Schild meldet.
- Getrennte Farben sowie Metallakzent, Position, Breite, Skalierung und Deckkraft.
- Native aktive Skillbuttons, inklusive ihrer ESO-Tastenbelegungen und Bedienung.
- Andere Waffenleiste mit Faehigkeitsicons und verfuegbaren Effekt-/Abklingzeitwerten.
- Normale Ressourcen werden ueber ihre vorhandene externe Sichtbarkeitsbedingung ausgeblendet. Die vorherige Bedingung wird beim Ausschalten wiederhergestellt. Reittier-, Belagerungs- und Werwolfanzeigen werden nicht als Ersatzbalken unterdrueckt.
- Eigene, geometrisch gezeichnete Fantasy-Grafiken in kleinen DXT3-Dateien. Keine Bildteile aus den beigefuegten Referenzen wurden kopiert. tests/build_fantasy_art.py erzeugt die Grafiken reproduzierbar.

## Umfang der ersten Version

Die aktive Skillreihe behaelt ihre ESO-Anordnung und Controllerbeschriftung. Dies ist ein WoW-inspiriertes Design, keine WoW-Aktionsleistenlogik. Target- und Gruppenrahmen sind in dieser Version noch nicht gestaltet. Ressourcen werden bei Ereignissen aktualisiert; ein 250-ms-Abgleich behandelt Sichtbarkeit, Waffenwechsel und die andere Skillleiste. Keine automatische Kampfaktion wird ausgefuehrt. Andere Addons, die dieselben Ressourcen-/Skillanzeigen umgestalten, koennen sich mit dem Design ueberschneiden.

Die neue Ressourcenanzeige bildet nicht alle besonderen Zustandsvisualisierungen des ESO-Originals nach. Bei Problemen mit einer Mechanik die Originalbalken ueber den Schalter zusaetzlich anzeigen oder Obsidian deaktivieren.

## Pruefung

Lokale Lua-5.1-Syntax- und Verhaltenstests pruefen Ressourcenwerte, Null-Maxima, Waffenleistenwahl, native Wiederherstellung, besondere Balken, Menue-/Ladewechsel und die echten Einstellungs-Callbacks. Ein echter ESO-/PS5-Test des Designs steht aus.

API-/Quellreferenzen:
- https://github.com/esoui/esoui/blob/live/esoui/ingame/playerattributebars/playerattributebars.lua
- https://github.com/esoui/esoui/blob/live/esoui/ingame/actionbar/actionbar.lua
- https://github.com/esoui/esoui/blob/live/ESOUIDocumentation.txt

## Darstellungskorrektur 0.1.1

Nach einer Spielaufnahme mit sichtbaren Labels, aber fehlenden Flaechen wurde die gemeinsame Textur als wahrscheinlicher Fehlerpunkt behandelt. Die vorherige 4x4-DXT1-Datei wird nicht mehr verwendet. Assets.xml laedt die neue DXT3-Flaeche und eine eingebaute ESO-Ausweichtextur vor. Hintergruende, Balken, Glanz, Rahmen und Text haben explizite Zeichenebenen. Solange kein Material geladen ist, werden die Original-Ressourcen freigegeben. In den Einstellungen sowie mit /obsidian status steht der aktuelle Ladezustand. Die Statusabfrage aendert den An/Aus-Schalter nicht. Der Fix ist lokal geprueft; eine neue Spielaufnahme steht aus. Wegen des neuen Texturpfads ESO vollstaendig neu starten.
## Fantasy-Design 0.2.0

Auf Wunsch wurde das Ressourcen-HUD an den Fantasy-Referenzen ausgerichtet: helle Metallkanten, abgeschraegte Balkenenden, rote/blaue/gruene emaillierte Fuellungen und ein seitliches Emblem. Die drei Balken sind untereinander gestaffelt. In den Einstellungen laesst sich Rundes Emblem statt Raute waehlen. Das Emblem zeigt das von ESO gelieferte Klassensymbol, wenn verfuegbar; sonst bleibt das eigens gezeichnete Wappen sichtbar. Es wird kein echtes 3D-Spielerportraet gerendert.

Der Metall-Akzent faerbt Rahmen und Emblem. Bisherige Standard-Bronzefarbe und Standardbreite werden einmalig auf das neue Layout umgestellt; eigene andere Farben und Positionen bleiben bestehen. Falls die neuen Fantasy-Grafiken noch nicht geladen sind, bleiben die originalen Ressourcenanzeigen aktiv. Wegen der neuen DDS-Dateien ESO vollstaendig neu starten.

Die neuen Fantasy-Dateien umfassen zusammen 103.040 Bytes. tests/fantasy_assets_test.py prueft das ausgelieferte Format, transparente Rahmenzentren, Ecken und Balkensilhouetten. Lokale Tests ersetzen keinen Sichttest im ESO-Client oder auf PS5.
## Ressourcenreihenfolge 0.2.1

Leben bleibt oben. Magicka und Ausdauer werden automatisch nach ihrem maximalen verfuegbaren Ressourcenpool sortiert: die groessere Ressource kommt in die Mitte, die kleinere nach unten. Der momentane Verbrauch aendert die Reihenfolge nicht. Bei gleichen oder noch nicht verfuegbaren Maximalwerten bleibt die letzte Reihenfolge erhalten; initial steht bei Gleichstand Magicka in der Mitte. Aenderungen der Maximalwerte, etwa durch Ausruestung oder Buffs, werden automatisch beruecksichtigt. Farben, Beschriftungen und Zahlen bleiben ihrer Ressource zugeordnet. /reloadui genuegt fuer dieses Lua-Update.

## Ladedialog-Diagnose 0.2.2
Der Sichttest im laufenden PTS-Client zeigte kein eigenes HUD. Die Ursache ist noch nicht bestaetigt. /obsidian status meldet jetzt den Aktivzustand, die HUD-Szene und Ladezustand sowie Dateidimensionen fuer Rahmen, Balken, Emblem, Flaeche und ESO-Ersatz einzeln. /reloadui laedt diese Diagnose. Die Lua-Verhaltenstests einschliesslich der erweiterten Statusabfrage bestehen. Dies ist eine Diagnoseerweiterung, kein bestaetigter Darstellungsfix.

## Waffenwechsel-Korrektur 0.2.3
Vor jeder Skillleisten-Aktualisierung werden die vorherigen Transparenzaenderungen freigegeben. Eine noch veraltete Kategoriezuordnung darf niemals den aktiven Button oder denselben Slot als hintere Leiste ausblenden. Ein Regressionstest simuliert 30 Waffenwechsel mit jeweils veralteter und anschliessend aktualisierter Zuordnung und prueft alle sechs aktiven und hinteren Slots. Die lokalen Lua-Tests bestehen; die Bestaetigung im Spiel steht aus. Fuer dieses reine Lua-Update genuegt /reloadui.
