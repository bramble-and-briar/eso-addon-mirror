# Obsidian HUD 0.7.53

Der Skill-/Trank-/Ultimate-Rahmen verwendet jetzt eine 256x256-DDS mit
gleichmaessigem Metallprofil und symmetrischen Ecken auf allen vier Seiten.
Die transparente Icon-Oeffnung und die bisherigen HUD-Abmessungen bleiben
erhalten. Die alte Fantasy-Raute samt Texturverweisen wurde entfernt; das
runde Klassenemblem bleibt erhalten.

Die Verschiebefunktionen sind jetzt nur noch mit dem rechten Controller-Stick
bedienbar. Maus-Ziehen ist fuer Ressourcen, Skills, Ultimate, Traenke, Buffs,
Synergie und den gemeinsamen Skill-HUD-Bereich entfernt. Gespeicherte Positionen,
Groessen und die automatische Speicherung nach drei Sekunden bleiben erhalten.

Die vier Ansichten heissen jetzt "Animation - mit/ohne Doppel-Ultimate" und
"Ohne Animation - mit/ohne Doppel-Ultimate". Die gespeicherten Ansichtswerte
bleiben gleich. "Ohne Animation" deaktiviert nur den Waffenwechsel-Effekt;
Druckanimation und Benutzungs-Glow bleiben in allen Ansichten aktiv.

Alle /obsidian-Befehle, Timer-/Materialdiagnosefunktionen und die kuenstliche
Stack-Testanzeige wurden entfernt. Verschieben, gemeinsames Verschieben und
Zuruecksetzen sind weiterhin ueber das Einstellungsmenue verfuegbar. Historische
Befehlsangaben in den folgenden aelteren Versionsnotizen gelten nicht mehr.

Neu: "Skill-HUD gemeinsam verschieben" im Einstellungsmenue oder
/obsidian move skillhud. Bewegt Skills mit Backbar, Traenke und Ultimate
als gemeinsamen Bereich mit unveraenderten Abstaenden. Ressourcen-HUD,
Buffanzeige und Synergie bleiben stehen. Einzelnes Verschieben bleibt erhalten.

Move UI fuer Skills, Traenke und Ultimate speichert jetzt unabhaengige
Bildschirmpositionen. Keine erzwungene gemeinsame Hoehe und keine gemeinsame
Randkorrektur mehr. Manuelle Positionen werden nicht relativ zu den Skills
skaliert. Beim Start des Verschiebens bleiben alle drei Bereiche an ihrer
aktuellen Position; nur der ausgewaehlte Bereich folgt dem rechten Stick.
Die beiden Skillreihen bzw. Ultimate-Symbole bleiben jeweils als Bereich zusammen.

Im Einstellungsmenue bleibt nur "Gesamtes HUD: Position und Groesse
zuruecksetzen". Die drei separaten Reset-Schaltflaechen wurden entfernt.

Reset-Schaltflaechen haben jetzt auch am PC einen sichtbaren Buttontext.
Der Positionsreset entfernt ebenfalls die getrennte Skalierungs-Positionskopie,
damit alte Positionen nicht sofort wiederhergestellt werden. Ressourcen-Reset
beendet laufendes Verschieben vor dem Schreiben der Standardwerte. Neu:
"Gesamtes HUD zuruecksetzen" bzw. /obsidian reset setzt alle HUD-Positionen
(Tastatur/Controller) und Ressourcen-/Skill-Skalierung zurueck. Gewaehlte Ansicht,
Farben und Timer-Einstellungen bleiben dabei erhalten.

Der Druckeffekt eines aktiven Skills bewegt/verkleinert nicht mehr das Symbol
der anderen Waffenleiste. Dessen Rahmen folgt jetzt dem stabilen Slot statt
dem animierten aktiven Rahmen. Beide Leisten behalten dieselbe Ruhegroesse;
der aktive Skill behaelt seine Druckanimation und der Waffenwechsel seine
bisherige Animation. Regressionstest prueft ruhende Vorschau bei wechselnden
aktiven Symbolgroessen in allen festen Ansichten, Skalierungen und Waffenleisten.

Erweiterter Abgleich mit dem vorhandenen FancyActionBar+ 2.19.8:
Minen/Schutzfelder und gefrorene Tore werden als einzelne Effektinstanzen
mit gemeinsamer Laufzeit und Anzahl erfasst. Elternmeldungen zaehlen nicht
als zusaetzliche Mine; Aktualisierungen verdoppeln keinen Eintrag. Verbleibende
Schildladungen und die zwei Explosionsphasen von Fluch/Shalks bekommen passende
Zaehler. Einige Skills ohne brauchbare Effektmeldung (Momentum, skriptbezogene
Effekte, Grave Lord's Sacrifice) nutzen ihre passenden eigenen Kampfmeldungen.
Eigene Begleitereffekte sind jetzt ebenfalls registriert. Alte Stapelmeldungen
mit erkennbar aelterem Startzeitpunkt koennen neue Stapel nicht mehr entfernen.

Wie beim Referenz-Addon aktiviert das eingeschaltete HUD die ESO-Einstellung
fuer Aktionsleisten-Timer, damit die nativen Laufzeitdaten bereitstehen.
Das Layout und die bestehenden Symbolanimationen werden dabei nicht geaendert.
Neue Tests pruefen die Sonderfall-Lebenszyklen und die echte Eventregistrierung.
Die Funktionen wurden mit simulierten ESO-Meldungen geprueft; eine vollstaendige
Pruefung saemtlicher Skills im Spiel ist damit nicht ersetzt. Optionale FAB-
Darstellungen wie Kanal-/Zauberzeit statt Effektdauer, passive Ultigenerierungs-
Cooldowns und synthetische Bereitschaftssymbole werden nicht uebernommen.

Skelettmagier (114317) und beide Morph-IDs (118680, 118726) starten den Timer
jetzt bei der Einsatzmeldung aus der tatsaechlichen GetAbilityDuration-Laufzeit.
Vorher warteten diese Skills auf die Effektmeldung nach der Beschwoerungs-
Animation. Die sofortige Aktualisierung der stabil verankerten Texte bleibt
aktiv; spaetere eigene Effektmeldungen koennen die Laufzeit korrigieren.
Test reproduziert die vorher fehlende Sofortanzeige und prueft ersten Einsatz,
verzoegerte Effektmeldung und Recast fuer alle drei IDs bei einem auf Nullgroesse
animierten Symbol. Die Symbolanimation wird nicht angehalten oder veraendert.

Skill-Timertexte haengen jetzt am stabilen Slot statt an den animierten Icon-
Grenzen. Timer-Mitte und Stack-Ecke folgen ebenfalls dem Slot, damit eine
eingeklappte/verkleinerte Icon-Animation die Textflaeche nicht mit verkleinert.
Die Einsatzmeldung aktualisiert sichtbare Skill-Texte unmittelbar nach dem
Start der Timerdaten; sie wartet nicht auf den naechsten HUD-Tick. Symbol-
Animationen werden dadurch weder beendet noch veraendert. Test prueft den
ersten Cast und Recast bei einem bereits auf Nullgroesse animierten Icon,
laufende Stacks, Text-Update vor OnUpdate und unveraenderte HUD-Sichtbarkeit.

Gemeinsame Recast-Korrektur: Bei neuer Aktivierung werden noch laufende alte
Effektinstanzen als vorherige Generation erfasst. Eine passende verzoegerte
Fade-Meldung der alten Generation beendet nicht die neue Laufzeit, auch bei
fehlenden Zeitstempeln und wiederverwendetem Effekt-Slot. Buff-Snapshots und
zugehoerige Effektmeldungen werden dabei nicht als zwei alte Generationen
behandelt. Vor dem ersten Gain einer neu gestarteten Aktivierung darf ein
unzuordenbarer Fade des ersetzten Effekts den Starttimer nicht loeschen.
Echte Fade-Meldungen des aktuellen Effekts bleiben wirksam. Diese Logik gilt
zentral auch fuer normale Skills, nicht nur Siphon. Regressionstest fuer mehrere
Recasts aller sechs Leichen-Skills und einen generischen Event-Timer, beide
Meldungsreihenfolgen, Snapshots, Waffenwechsel und tatsaechliches Ende.

Die aktuellen Nutzerscreenshots zeigen Detonierenden Siphon im aktiven Slot
als ID 118763. Die vorhandene Aktivierungsregel war nur unter 118764 hinterlegt.
Damit konnte Cast ja bei Timer 0 erscheinen, ohne dass die Regel startete.
Effekt-/Slot-IDs aller sechs Leichen-Skills sind nun Alias ihres konfigurierten
Skill-IDs; Castzustand, Startdauer, effektbasierte Korrektur und Fade sind fuer
beide Darstellungen gemeinsam. Neuer Test reproduziert den Screenshot mit
118763 und nativer Restzeit 0; prueft anschliessend den vollstaendigen Weg
bis zum Timer-Text, beide Leisten und eigene Effekt-/Fade-Meldungen.
Die anderen Screenshot-IDs sind dadurch nicht automatisch als behoben
bestaetigt. Der visuelle Spieltest steht weiterhin aus.

Gezielte Laufzeitdiagnose fuer den weiterhin nicht bestaetigten Siphon-Timer:
/obsidian timers gibt einmalig alle belegten Skills beider Leisten aus, mit
tatsaechlicher Slot-/Fähigkeits-/Effekt-ID, erfasstem Cast, Anzahl zugeordneter
Effekte, berechneter und nativer Restzeit sowie HUD-Text/Sichtbarkeit.
Kein automatisches Logging, keine neue SavedVariables-Historie, keine Aenderung
der Timerberechnung. Die Meldung des Nutzers konnte bisher nicht mit echten
Clientdaten reproduziert werden; eine weitere Ursache wird nicht behauptet.

Systematischer Abgleich aller konfigurierten Tracker: 345 numerische Timer-
Zuordnungen, 14 Ausschluesse, 21 Aktivierungsfaelle und 35 numerische Stack-
Gruppen der lokalen FancyActionBar+ 2.19.8-Referenz stimmen mit den vorgesehenen
Regeln ueberein. Der gewuenschte 20s-Elan-Buff bleibt eine bewusste Anpassung.
Explizite Aktivierungsregeln haben nun Vorrang vor generischen Kanal-/Toggle-
Metadaten; damit werden Siphon/Leichenverbindungen und vergleichbare Sonderfaelle
nicht mehr durch die gemeinsame Pruefung unterdrueckt. Drei aktive Schildvarianten
sind ihrem Grundeffekt zugeordnet, auch fuer Effektmeldungen und Fade.
Eine neue Testmatrix prueft alle 357 hinterlegten Timer-Zuordnungen und alle
Stack-Zuordnungen ueber beide Waffenleisten und alle sechs Slots: 4.284 Timer-,
1.752 Stack- und 96 Metadatenkombinationen, zusaetzlich alle sechs Leichen-Skills
mit fehlender API-Dauer. Normale Kanaele/Toggle-Skills bekommen weiterhin keine
erfundenen Laufzeiten. Layout und Animationen bleiben unveraendert. Die Tests
simulieren API-/Event-Daten und ersetzen keinen Spieltest jeder ESO-Faehigkeit.

Aufloesender Elan verfolgt auf ausdruecklichen Wunsch den 20-Sekunden-Buff
Kleinere Entschlossenheit (61693), statt der Heilung (61509). Eigene Aktivierung
startet den Timer, passende eigene Buff-Meldungen aktualisieren ihn. Der
gemeinsam mit anderen Skills verwendete Buff darf den Timer nicht ohne eigene
Elan-Aktivierung starten. Grundform und Widerhallender Elan bleiben Heilungstimer.

Elan, Widerhallender Elan und Aufloesender Elan erhalten eine gezielte
Heilungs-Timerregel. Die API-Dauer des Heilungseffekts hat bei erfolgreicher
Aktivierung Vorrang vor der Eltern-Dauer. Eigene beobachtete Heilungseffekte
ersetzen diese Aktivierungszeit; ihre Fade-Meldungen beenden sie. Aufloesender
Elan ist explizit dem Heilungseffekt 61509 zugeordnet, nicht dem laenger laufenden
Buff Kleinere Entschlossenheit (61693). Bekannte Rang-II-IV-IDs sind auf den
jeweiligen Morph normalisiert. Test deckt alle drei Varianten/Raenge, beide
Leisten, Recast, fremde Heilung, Fade und Reload-Snapshots ab. Keine fest
geratene Sekundenlaenge; die tatsaechliche Laufzeit kommt aus Spiel-API/Events.

Timer-/Stack-Erfassung mit FancyActionBar+ 2.19.8 main.lua/config.lua verglichen
und eigenstaendig erweitert. Gemeinsame Aufloesung von Schriftlehre-Slot-IDs
zu echten Faehigkeits-IDs; effektbasierte Timer und native Slot-Beobachtungen
auf beiden Waffenleisten. Kurze Nullabfragen der inaktiven Leiste loeschen
keine noch laufende, tatsaechlich beobachtete Slot-Restzeit. Explizite Null-
Events, Ende, eigene Fade-Meldungen und Skillwechsel verwerfen den Cache.
Stacks kommen aus nativer API, passenden Effektmeldungen oder Buff-Snapshots.
Eigene Ziel-Stacks werden je Einheit verfolgt; angezeigt wird der hoechste
echte Stackwert, keine Summe oder Zielanzahl. Verbrauchte Zaehler, fremde
Ziel-Effekte und veraltete Fade-Meldungen werden getrennt behandelt.
Weitere numerische Stack-Zuordnungen ergaenzt; synthetische Bereit-Symbole
werden nicht als Stapelzahlen dargestellt. FancyActionBar muss nicht installiert
sein. Keine Aenderung an Layout, Groesse oder Waffenwechsel-Animationen.

Beide Skillreihen verwenden in den festen Ansichten dieselben tatsaechlichen
Rahmenmasse: die inaktive Reihe kopiert die beiden Ecken des aktiven Artworks
mit dem jeweiligen Zeilenversatz. Ihre Groesse wird nicht mehr unabhaengig
aus einer geschaetzten Ruhegroesse berechnet. Symbol-Innenabstand und Rahmen
bleiben dadurch auch bei UI-Skalierung, Waffenwechsel und animierten
Groessenaenderungen gleich. Die bestehenden Animationseinstellungen bleiben.

Skill-Timer mit Effekt-ID-Zuordnung koennen jetzt die echte native Slot-
Effektrestzeit nutzen, wenn noch keine eigene Effektmeldung erfasst wurde.
Vorher wurde diese Restzeit bei jeder solchen Zuordnung pauschal verworfen.
Eigene beobachtete Effekte behalten Vorrang; eine native Zeitmessung ohne
Cast-Ereignis verhindert nicht die spaetere Zuordnung eines eindeutigen Effekts.
Gilt fuer aktive und inaktive Waffenleiste. Mehrphasen-/Platzierungsregeln,
Zaehler-/Sofortskill-Ausschluesse und der Verzicht auf Cooldown-Schaetzungen
bleiben erhalten. Animationen und HUD-Positionen wurden nicht veraendert.

In den animierten Ansichten ueberspringt ausschliesslich die Ultimate den
Waffenwechsel-Flip. Die fuenf normalen Skills behalten ihre Animation und die
Zuordnung der Zeile zum tatsaechlichen Symbolwechsel. Die beiden Ansichten
ohne Animation bleiben unveraendert. Ultimate-Aktivierungs-/Bounce-Effekte
werden durch diese gezielte Waffenwechsel-Aenderung nicht beendet.

Die beiden animierten Ansichten behalten wieder den vollstaendigen nativen
Waffenwechsel-Flip. Zeile, Vorschau und Tasten folgen der vom nativen Button
tatsaechlich dargestellten Waffenleiste (slot.hotbarCategory). Diese Kategorie
wechselt zusammen mit dem Symbol am Animationsmittelpunkt. Alte Symbole
bleiben beim Einklappen in ihrer alten Zeile; erst die neuen Symbole erscheinen
in der neuen Zeile. Die Ultimate-Aufladung nutzt dieselbe sichtbare Kategorie.
Nur die beiden expliziten Ansichten ohne Animation beenden die Timelines.
Die sofortige Beendigung aus 0.7.32 ist fuer animierte Ansichten zurueckgenommen.

Feste Skillreihen beenden den nativen Waffenwechsel-Flip nun fuer alle Slots
3 bis 8 mit normalen Completion-Callbacks. Vorher wurde das nur fuer die
Ultimate gemacht: die anderen aktiven Buttons wanderten mit dem alten Symbol
in die neue Zeile und wechselten erst am Flip-Mittelpunkt ihr Icon.
Die Frame-Updates erfassen auch von ESO spaeter gestartete Flip-Timelines.
Normale Skill-Aktivierungs-/Bounce-Animationen bleiben in den animierten
Ansichten erhalten; die bestehenden Ansichten ohne Animation bleiben bestehen.

Der goldene Ultimate-Aufladerahmen rechnet seine Bildschirmmasse in die
tatsaechlichen Einheiten der Linienanker um. Dazu wird ein unsichtbarer
Einheiten-Probeanker pro geaenderter Rahmengroesse gemessen. So werden
UI-/HUD-Skalierungen nicht erneut auf bereits skalierte Masse angewendet.
Gilt fuer aktive und inaktive Ultimate, ohne Aenderung der HUD-Positionen.
Regressionstest vergleicht Linienendpunkte und Artwork-Bildschirmkanten
bei mehreren Skalierungen, Waffenwechsel, Groessenwechsel und Nullgeometrie.
Visuelle Bestaetigung im Spiel steht aus.

Im aktuellen interface.log nachgewiesener Laufzeitfehler behoben:
GetUnitPower liefert mehrere Werte. Die direkte Uebergabe an tonumber
interpretierte das Maximum 500 als Zahlenbasis und brach den HUD-Tick
waehrend des Ultimate-Updates ab. Dadurch wurden auch Ultimate-Vorschau,
Pfeil, Trankrahmen und anschliessende Positionierung nicht fertig aktualisiert.
Die Konvertierung verarbeitet jetzt ausschliesslich den ersten Rueckgabewert.
Der Regressionstest reproduzierte vor der Korrektur denselben Fehler mit
den drei ESO-Rueckgabewerten statt des bisherigen einzelnen Mock-Wertes.

Der Trankrahmen haengt am stabilen Schnellzugriff-Slot, damit ein vom Spiel
ausgeblendetes leeres Item-Symbol nicht auch den HUD-Rahmen versteckt.
Der hellgruene Leistenpfeil bleibt neben dem aktiven Skill verankert, ist aber
kein Kind des nativen Skill-Slots mehr und erbt dessen Alpha nicht.

Einzel-Ultimate: Tastensymbole direkt unter dem eigenen Rahmen statt auf Hoehe
der unteren Skillreihe. Die Doppel-Ultimate-Ansichten bleiben unveraendert.

Die Vorschau der anderen Waffenleiste nutzt bei fehlender Slot-Textur das
Symbol der belegten Faehigkeit. Feste Ansichten setzen die Vorschau-Deckkraft
explizit zurueck. Ultimate-Vorschau und Waffenleisten-Zuordnung werden auch
im Frame-Update synchronisiert, einschliesslich leerer aktiver Ultimates.
Regressionstest fuer beide Doppel-Ultimate-Ansichten: zwei belegte Slots,
fehlende inaktive Slot-Textur, wiederholte Wechsel mit konstanten Front-/Back-
Positionen, leere Slots und HUD-Sichtbarkeit. Ingame-Bestaetigung steht aus.

Feste Skillzeilen pruefen nun auf genau einen eigenen Slot-Anker. Von ESO
zusaetzlich gesetzte Anker bleiben nicht neben dem HUD-Anker bestehen. Die
nativen horizontalen Abstaende werden vor dem Umankern erfasst; alle fuenf
aktiven Slots werden auf dieselbe Zeile ausgerichtet. Der erste Skill aktualisiert
nur das Skill-Layout zusaetzlich im Frame-Update, auch bei leerem Slot. So werden
spaete native Template-/Waffenwechsel-Aenderungen nicht erst im 250-ms-Takt
korrigiert. Der Ultimate-Aufladerahmen folgt der tatsaechlichen Rahmenflaeche
statt einer geschaetzten Ruhegroesse. Keine neue Gesamt-HUD-Verschiebung und
keine automatische Aenderung gespeicherter Positionen. Ingame-Vergleich steht aus.

Gezielte Skill-HUD-Korrektur ohne gemeinsamen Verschiebemodus: Skill-,
Ultimate- und Trankpositionen rechnen Bildschirmkoordinaten auch bei einer
vom Spiel geerbten Skalierung korrekt in Ankerkoordinaten um. Die Umrechnung
wird bei Skalierungs-/Aufloesungswechsel neu gemessen. Leere aktive Slots
aktualisieren ihre Tastenanker ebenfalls, damit nach einem Waffenwechsel
keine alten Beschriftungspositionen bleiben. Nur Skill-HUD-Positionen
zuruecksetzen entfernt auf Wunsch ausschliesslich Skill-/Ultimate-/Trank-
positionen. Keine automatische Loeschung gespeicherter Einstellungen.
Die Ressourcen-Verschiebelogik, Buffanzeige und Synergie wurden nicht umgebaut.

Ultimate-Aufladerahmen pruefen beide Waffenleisten getrennt auf eine wirklich
belegte Ultimate. Leere Slots behalten auch bei veralteten ESO-Kosten keinen
alten Rahmen. Beim Waffenwechsel werden Zwischenstaende ausgeblendet, bis
die Leisten-Zuordnung wieder stimmt; eine weiterhin belegte andere Leiste
behaelt in der Doppel-Ultimate-Ansicht ihre eigene Vorschau. Aus-/Einruesten
und leere aktive Slots werden auch ueber das laufende Text-Update erkannt.

Der native Synergie-Hinweis (Symbol, Taste und Text) ist unter HUD-Elemente
einzeln verschieben > Move UI: Synergie-Hinweis verschiebbar, auch wenn
gerade keine Synergie bereitsteht. Der beschriftete Bewegungsrahmen ist
die Vorschau; die echte Synergie wird nicht kuenstlich aktiviert. Rechter
Stick, automatisches Speichern nach drei Sekunden und getrennte Tastatur-/
Controllerpositionen wie bei den anderen HUD-Elementen. Am PC alternativ
/obsidian move synergy. Positionen zuruecksetzen umfasst auch Synergie.
Skill-Skalierung und Front-/Backbar-Wechsel verschieben den Hinweis nicht.

Alle Skills der jeweils inaktiven Waffenleiste bleiben jetzt vollstaendig
entsaettigt und abgedunkelt, auch mit laufendem Timer, Stapeln oder aktivem
Umschalteffekt. Das gilt auf Frontbar und Backbar sowie fuer die inaktive
Ultimate-Vorschau. Timer-/Stapeltexte behalten ihre eingestellten Farben und
ihre Helligkeit; aktive native Skill-Icons bleiben unveraendert. Kein Einfluss
auf Effektlaufzeiten, Proc-Bereitschaft oder Waffenwechsel-Animationen.

Fantasy-HUD fuer ESO mit Ressourcenbalken, Klassenemblem und Skillrahmen.
Benoetigt LibHarvensAddonSettings ab Version 20200.
Bereite, benutzbare verstaerkte Skills erhalten nur auf der aktiven Leiste ESOs eigene Proc-
Animation mit additivem Lichtschein statt eines umgefaerbten Rahmens.
Die Proc-Anzeige nutzt ESOs Bereitschaftssignal sowie die bekannten
Override-IDs und Zaehler fuer den dritten Schaedelwurf und Spektralbogen.
Sie funktioniert unabhaengig von Skill-Timern und bleibt auch in den Ansichten
ohne Waffenwechsel-/Druckanimationen sichtbar. Die Proc-Textur animiert wie
in ESO mit 64 Einzelbildern bei 30 fps; der Lichtschein verwendet ESO-Grafiken.
Nach Verbrauch der Stacks verschwindet die Hervorhebung wieder.
Auf der inaktiven Leiste bleiben Schaedelwurf und Spektralbogen samt Rahmen
ausgegraut, auch wenn ihre Stacks bereits bereit sind. Ein laut ESO gerade
nicht benutzbarer Skill (z. B. ohne gueltiges Ziel) bekommt keinen Zusatzschein.
Skill-Timer brauchen keine eingeschaltete originale ESO-Timeranzeige.
Das HUD verfolgt eigene Skill-Ausloesungen, gemeldete eigene Effekte auf
Spieler/Gegnern und aktive eigene Buffs. Erkannte Effekt- und Phasenzeiten
haben Vorrang vor den Zeiten des uebergeordneten ESO-Buttons. Normale
Skill-Ausloesungen starten keinen geratenen Tooltip-Countdown mehr.
Nur gezielte Sonderregeln (z. B. Fallenplatzierung, Leichenseile und Rituale)
duerfen direkt bei der Ausloesung eine Dauer starten. Die aktuelle Effekt-
Dauer von ESO hat dabei Vorrang vor fest hinterlegten Ersatzwerten.
Frontbar und Backbar nutzen dieselben Timer-Daten.
Sofortfaehigkeiten ohne Dauer und umschaltbare Dauer-Skills erhalten keinen
kuenstlichen Countdown. Fremde Effekte werden nicht uebernommen.
356 numerische Skill-/Effekt-Zuordnungen decken Klassen, Waffen und Gilden ab.
Davon sind 36 reine Counter-/Proc-Zuordnungen bewusst keine Laufzeit-Timer.
Ein gemappter Skill wartet auf seine Effektmeldung; die Tooltipdauer wird
nicht vor dem Treffer als Buff-Timer gestartet. Gemeinsame Buffs werden nur
einem vorher selbst ausgeloesten Skill zugeordnet. Ein normaler Recast laesst
den noch laufenden Effekt bestehen, bis der neue Treffer ihn ersetzt.
Eindeutige eigene Effekte koennen nach einem Reload ohne Recast erkannt werden.
Fallen erkennen auch einen spaeten Ausloeser. Fluch und Warden-Angriffe
wechseln zwischen getrennten Phasen; spaete Meldungen aus Phase eins duerfen
Phase zwei nicht beenden. Fehlende native Restzeiten loeschen keine weiterhin
gemeldeten eigenen Effekte. Slot-Effekt-Updates stossen die Erkennung sofort an.
Abklingzeiten werden nicht mehr als Skill-Effektlaufzeit angezeigt. Der
Trank-Cooldown bleibt weiterhin Teil des nativen Trankbuttons.
Sprengknochen und die verseuchte Morphvariante teilen sich mit ihren jeweils
ausgegrauten Slot-IDs einen Timer. Ein gemeldeter eigener Explosions-Treffer
beendet ihn; spaete Folgedebuffs starten ihn nicht neu. Grabesfuerst-Opfer
bleibt getrennt und darf seinen tatsaechlichen Buff nach dem Opfer anzeigen.
Nachtklingen-Schatten beruecksichtigen unterschiedliche Volks-Effekt-IDs.
Die Datenbeziehungen wurden mit der lokalen FAB+ 2.19.8-Referenz abgeglichen;
die Timerlogik ist eigenstaendig. Unbekannte Sonder-/Schriftlehre-Skills
koennen weiterhin spezifische Zuordnungen benoetigen. Alle Beziehungen und
die gemeinsamen Ablaufregeln sind lokal simuliert, nicht komplett ingame getestet.
Ressourcenbalken gleiten bei Regeneration innerhalb von 120 ms zum echten Wert.
Verbrauch wird sofort dargestellt, damit keine ueberfuellte Anzeige bleibt.
Die Fuellung wird auf den sichtbaren Innenbereich der DDS begrenzt; transparente
Raender und die Metallspitze zaehlen nicht als nutzbare Balkenlaenge. Bis zur
tatsaechlich vollen Ressource bleibt eine kleine sichtbare Restluecke, auch auf
der gebogenen Leiste. 100 % werden erst bei vollem Wert angezeigt und zeichnen
sofort den vollen Balken. Zahlen und Prozent aktualisieren sich sofort.
Bei geaendertem Maximalwert und nach Ladebildschirmen gilt der echte Stand.

Ein aktives Schadensschild wird hellblau direkt innerhalb des Lebensbalkens
angezeigt. Neben den normalen Lebenswerten steht hellblau Ges. fuer aktuelles
Leben plus Schild, z. B. 20.000 Leben + 8.000 Schild = 28.000 gesamt.
Nach Verbrauch verschwinden Schildflaeche und Zusatzwert. Die Flaeche wird
auf die Balkenbreite begrenzt; der Gesamtwert behaelt den vollen Schildbetrag.

Einstellungen: Obsidian HUD im Addon-Einstellungsmenue.
Unter Skill-Leiste vergroessert "Gesamtes Skill-HUD: Groesse" Skills,
Backbar, Ultimate, Traenke, Rahmen, Timer, Stacks, Pfeil und Tasten gemeinsam.
Standard ist 1,00, maximal 1,50 in 0,05-Schritten. Alte Prozentwerte werden
automatisch uebernommen. Die Einstellung wird
gespeichert und wirkt direkt in allen Ansichten. Ressourcen und die separat
verschiebbare Buffanzeige behalten ihre eigene Groesse.
Die Vergroesserung behaelt die Bildschirmposition als Ausgangspunkt bei.
Die Abstaende zu Ultimate und Trank wachsen mit. Backbar und Aufladerahmen
werden aus den urspruenglichen Slotmassen berechnet und nur einmal skaliert.
Auch ohne gespeicherte Move-UI-Position bleiben die Skill-, Ultimate- und
Trankfelder mit Platz fuer ihre Tasten oberhalb des unteren Bildschirmrands.
Unter Skill-HUD-Ansicht stehen Frontbar oben, Backbar unten und
Doppel-Ultimate mit Aufladerahmen zur Auswahl.
Standard, Nur laufende Skills und Beide Reihen gleich gross wurden entfernt.
Alte gespeicherte Auswahlen dieser Ansichten wechseln automatisch auf
Frontbar oben, Backbar unten; das ist auch die Vorgabe fuer neue Installationen.
Die beiden festen Ansichten gibt es zusaetzlich als eigene Auswahl mit dem
Zusatz ohne Animation. Diese Varianten ueberspringen native Skill-Aktivierungs-,
Waffenwechsel- und Textwechselanimationen, fuehren deren Aktualisierungs-Callbacks
aber weiterhin aus. Timer, Punkte, Aufladung, Tasten und Positionen bleiben erhalten.
Move UI verschiebt Ressourcen, Skills, Ultimate, Traenke und Buffanzeige.
In den beiden festen Zweireihen-Ansichten sitzt der Trank links mittig zwischen
den Skillreihen und bleibt beim Waffenwechsel dort. Horizontal bleibt er separat
verschiebbar. Bei nur einer sichtbaren Reihe gilt seine bisherige Position.
Die bisherigen Ansichten zeigen nur die aktive Ultimate, ohne zusaetzliche Ultimate-Vorschau.
Bei Frontbar oben, Backbar unten sitzt sie rechts mittig zwischen den Reihen
und behaelt ihre fruehere native Groesse.
Move UI haelt diese vertikale Zentrierung; horizontal bleibt die Ultimate separat verschiebbar.
Die Tasten stehen weiterhin
unter der unteren Reihe; die Ultimate-Waffenwechselanimation bleibt dort aus.

Die zusaetzliche Ansicht Doppel-Ultimate mit Aufladerahmen behaelt feste Skillreihen
und zeigt beide Ultimate-Felder, Front-Ultimate leicht nach oben und Back-Ultimate
nach unten versetzt. Ein goldener Rahmen fuellt sich symmetrisch von unten
mittig auf beiden Seiten entlang der abgeschraegten HUD-Ecken nach oben anhand
aktueller Ultimate-Punkte und der
jeweiligen Leistenkosten. Alle Ultimate-Ansichten verwenden denselben hellen
Goldton mit einem ruhigen Leuchtsaum. Die inaktive Ultimate wird am Rahmen
nicht mehr abgedunkelt. Die Aufladung trifft sich oben mittig, wenn die jeweilige
Ultimate bereit ist. Noch nicht aufgeladene Rahmenabschnitte bleiben transparent;
nur der erreichte Aufladestand erscheint gold mit Leuchtsaum. Tasten bleiben
unter der unteren Ultimate; die untere Bildschirmgrenze beruecksichtigt beide
Felder. Keine weiteren Einstellungsregler erforderlich.
Lokale Tests pruefen Leistenkosten, Aufladestand, Positionen, Waffenwechsel und
die unveraenderte Einzel-Ultimate-Ansicht. Eine Sichtpruefung im Spiel steht aus.

Nach Lua-Aenderungen /reloadui eingeben. Bei geaenderten DDS-Grafiken
ESO vollstaendig neu starten.

Der Addon-Ordner enthaelt die Laufzeitdateien und benoetigten Grafiken.
Tests, Grafikgeneratoren, Vorschaubild, Klassen-Prompts und die bisherige
Entwicklungshistorie liegen ausserhalb von AddOns unter:

    ../../ObsidianHUD-Development/

Alle Entwicklungspruefungen lassen sich dort mit run_checks.py ausfuehren.
