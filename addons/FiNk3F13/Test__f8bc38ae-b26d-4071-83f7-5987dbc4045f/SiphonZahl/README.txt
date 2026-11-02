SIPHON ZAHL 0.9.2
Autor: FiNk3--F13--
Manifest: SiphonZahl.addon, AddOnVersion 902, APIVersion 101051.
LibHarvensAddonSettings. Konsole/Gamepad. Keine Chatbefehle.

AENDERUNG 0.9.2
Eigener Skelett-Schuetze anhand echter Testdaten ergaenzt (Effekt118681).
Der Beschwoerungsmarker merkt die ID vor, zaehlt aber keine lebende Einheit.
Erst ein noch vorhandener, tatsaechlich toter eigener Koerper mit passender
ID und Position wird gezaehlt. Verbrauch mit Siphon entfernt genau diese ID.
Keine angesetzte Beschwoerungs- oder Leichenlebensdauer.
PC-Beobachtungen: ID18749 verschwand beim Tod und wurde nicht als vorhandener
toter Koerper bestaetigt. ID64565 blieb nach dem Tod noch9.989 Sekunden als
tote Einheit bestehen. Bei ID36774 meldete Siphon exakt die tote Einheiten-ID.
Diese Zeiten sind Beobachtungen, KEINE im Zaehler hinterlegten Ablaufzeiten.
Skelettmagier/Arkanist und andere Quellen sind damit noch nicht bestaetigt.

ZAEHLMETHODE
Eigene Sprengknochen-/Schaedel-/Skelett-Schuetzen-Leichen werden ohne angenommene Lebensdauer
verfolgt. Zum Zaehlen sind noetig:
- Ein bekannter Erzeugungsmarker mit Einheiten-ID.
- Dieselbe ID an einem eigenen playerpet-Tag.
- Die Einheit existiert laut ESO noch und ist tot.
- Ihre aktuelle RAW-Position liegt im 90-Grad-Kegel und innerhalb 11 Metern.

Die Zahl sinkt bei tatsaechlichem Verlust der Einheit/des Tags oder bei
zugeordnetem Siphon-Verbrauch. Eine neue Einheit im gleichen Pet-Slot ersetzt
die alte Zuordnung. Doppelte oder verbrauchte Marker zaehlen nicht erneut.
Keine Leiche wird nach fest eingestellten 5 oder 10 Sekunden abgezogen.
Die 1.5s-Castkorrelation ordnet Siphon-Antworten zu, sie ist KEINE Leichendauer.

BELEG AUS DEN VIER PC-TESTLAEUFEN
Natuerliche Entfernung: BB-ID16518 nach 5.031s, Schaedel-ID6752 nach 5.016s.
Das sind Beobachtungen, keine im neuen Zaehler hinterlegten Ablaufzeiten.
Siphon meldete exakt die erzeugten IDs62334 und52568; die toten Einheiten
koennen danach noch bestehen, deshalb wird der Ziel-ID-Verbrauch separat genutzt.
FADED kam bereits beim Entstehen der Leiche und wird NICHT als Ende behandelt.
Die Originalaufzeichnung und eine Sicherung bleiben im Arbeitsordner erhalten.

GRENZEN
Getestete Quellen: eigene Sprengknochen (PC-Morph verdorbene Sprengknochen)
und Schaedel. Weitere Morphs/Plattformen beduerfen echter Spieltests.
Gegnerleichen, Banner, Geist und andere Skelett-Morphs werden NICHT gezaehlt.
Andere Leichenverbraucher sind nicht durch diese vier Laeufe bestaetigt.
Fehlende Einheiten-Zuordnung oder Koordinaten werden ausgelassen; Hinweis sichtbar.
Auch ein Zaehler0 schliesst daher andere nutzbare Leichen nicht aus.
Keine vollstaendige Umgebungssuche und keine Sichtlinienpruefung.
Das Modell ist anhand echter Ereignisse belegt, aber keine Garantie aller
aktuell fuer jeden Verbraucher nutzbaren Leichen.

BEDIENUNG
Move UI: rechter Stick oder PC-Maus, Kameramodus wie Weaving Metronome.
Nach 3 Sekunden ohne Eingabe automatisch sperren. Kompakter Rahmen fuer zwei
Ziffern. Groesse/Farbe/Deckkraft und Position bleiben accountweit gespeichert.
Keine Positionsregler, kein Vorschau-Button, kein Debug-/Ereignistest auf dem HUD.

VALIDIERUNG
Alle vier urspruenglichen PC-Ereignislaeufe sowie die Skelett-Testlaeufe
gegen den Zaehler wiedergegeben. Lebender Schuetze, sofortiger Tagverlust,
vorhandener toter Schuetze, Verbrauch, gleichzeitige Leichen und reine
Zeitspruenge zusaetzlich geprueft.
Zusaetzlich: kein Ablauf bei reinem Zeitsprung, lebende Pet-Einheit zaehlt nicht,
FADED bei Erzeugung, Siphon-Zielzuordnung, Doppelevents, Slot-Wiederverwendung,
Verspinden ohne Event, RAW-/Kegelgrenzen, unbekannte Positionen, UI-Bewegung/Farbe.
Neue Implementierung noch nicht direkt im Spiel/auf PS5 bestaetigt.
Lokale Installation aktualisiert nur den PC-PTS-Ordner.
Entwickelt mit Unterstuetzung von OpenAI Codex.
Nicht mit ZeniMax Media Inc. verbunden oder von ihr gesponsert.
