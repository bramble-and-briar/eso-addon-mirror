# Obsidian HUD 0.7.19

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
