WayshrineArrow 0.1.0
====================

AI disclosure: The code of this addon was written with the help of an AI
assistant (Claude by Anthropic). The author reviewed it, tested it in-game
and is responsible for it.

--- English ---

A small, movable arrow on your HUD points in a straight line to the nearest
wayshrine of the map you are on - known or unknown. Made for players who like
to travel on foot, explore a map anew or just want more immersion.

- Target: nearest wayshrine, nearest unknown wayshrine or nearest known one
  (setting, keybind or /wsarrow target)
- Optional below the arrow: name, status (known / unknown) and distance
- Separate colors for known and unknown wayshrines
- Hidden in delves, public and group dungeons, arenas, the Infinite Archive,
  trials, battlegrounds, houses and inside buildings (inns, banks, shops ...);
  optionally in combat or close to the target
- Settings menu with LibAddonMenu-2.0 (optional) - every setting is also
  available as a chat command

Settings are separate for each server (EU/NA) and account. Optionally every
character gets its own settings, and you can copy the settings of another
character.

Commands (keywords are English in every language):
  /wsarrow                        show / hide (also: on, off)
  /wsarrow unlock | lock          move the arrow with the mouse / fix it
  /wsarrow reset                  move the arrow back to its start position
  /wsarrow target [all | unknown | known]
                                  what the arrow points to (no value: next)
  /wsarrow name [on | off]        wayshrine name below the arrow
  /wsarrow status [on | off]      status (known / unknown) below the arrow
  /wsarrow distance [on | off]    distance below the arrow
  /wsarrow combat [on | off]      hide in combat
                                  (without on/off the setting is switched)
  /wsarrow near <0-100>           hide when closer than this many meters
  /wsarrow size <24-160>          arrow size
  /wsarrow font <12-36>           text size
  /wsarrow alpha <20-100>         opacity in percent
  /wsarrow color known <RRGGBB>   color for known wayshrines, e.g. 73D9FF
  /wsarrow color unknown <RRGGBB> color for unknown wayshrines, e.g. FFC740
  /wsarrow color known reset      default color (also for unknown)
  /wsarrow account                same settings for all characters
  /wsarrow character              own settings for this character
  /wsarrow copy                   list characters with own settings
  /wsarrow copy <name | account>  copy their settings to this character
  /wsarrow show                   current settings
  /wsarrow settings               settings menu (needs LibAddonMenu-2.0)
  /wsarrow help                   all commands
  /wsarrow debug                  information for bug reports

The distance is measured from your own movement, so on a map you have not
walked on yet it appears after a few steps.

Buildings are recognized by their door. If a character logs in inside a
building for the very first time, the arrow is shown until you walk out and
in once; after that it is remembered, also across logins.

--- Deutsch ---

Ein kleiner, verschiebbarer Pfeil im HUD zeigt in Luftlinie zum nächsten
Wegschrein der aktuellen Karte - bekannt oder unbekannt. Gedacht für alle, die
gern zu Fuß unterwegs sind, eine Karte neu erkunden oder einfach mehr
Immersion möchten.

- Ziel: nächster Wegschrein, nächster unbekannter oder nächster bekannter
  (Einstellung, Tastenbelegung oder /wsarrow target)
- Wahlweise unter dem Pfeil: Name, Status (bekannt / unbekannt) und Entfernung
- Eigene Farben für bekannte und unbekannte Wegschreine
- Keine Anzeige in Gewölben, öffentlichen Verliesen, Gruppenverliesen, Arenen,
  dem Endlosen Archiv, Prüfungen, Schlachtfeldern, Häusern und in Gebäuden
  (Gasthäuser, Banken, Läden ...); wahlweise auch im Kampf oder nahe am Ziel
- Einstellungsmenü mit LibAddonMenu-2.0 (optional) - jede Einstellung geht
  auch als Chat-Befehl

Einstellungen sind je Server (EU/NA) und Account getrennt. Wahlweise bekommt
jeder Charakter eigene Einstellungen, und du kannst die Einstellungen eines
anderen Charakters übernehmen.

Befehle (die Schlüsselwörter sind in jeder Sprache englisch):
  /wsarrow                        ein-/ausblenden (auch: on, off)
  /wsarrow unlock | lock          Pfeil mit der Maus verschieben / fixieren
  /wsarrow reset                  Pfeil zurück an die Startposition
  /wsarrow target [all | unknown | known]
                                  Ziel: alle / unbekannte / bekannte Wegschreine
                                  (ohne Wert: nächstes Ziel)
  /wsarrow name [on | off]        Name des Wegschreins unter dem Pfeil
  /wsarrow status [on | off]      Status (bekannt / unbekannt) unter dem Pfeil
  /wsarrow distance [on | off]    Entfernung unter dem Pfeil
  /wsarrow combat [on | off]      im Kampf ausblenden
                                  (ohne on/off wird umgeschaltet; an/aus geht auch)
  /wsarrow near <0-100>           ausblenden näher als so viele Meter
  /wsarrow size <24-160>          Pfeilgröße
  /wsarrow font <12-36>           Textgröße
  /wsarrow alpha <20-100>         Deckkraft in Prozent
  /wsarrow color known <RRGGBB>   Farbe für bekannte Wegschreine, z. B. 73D9FF
  /wsarrow color unknown <RRGGBB> Farbe für unbekannte Wegschreine, z. B. FFC740
  /wsarrow color known reset      Standardfarbe (auch für unknown)
  /wsarrow account                gleiche Einstellungen für alle Charaktere
  /wsarrow character              eigene Einstellungen für diesen Charakter
  /wsarrow copy                   Charaktere mit eigenen Einstellungen auflisten
  /wsarrow copy <Name | account>  deren Einstellungen übernehmen
  /wsarrow show                   aktuelle Einstellungen
  /wsarrow settings               Einstellungsmenü (braucht LibAddonMenu-2.0)
  /wsarrow help                   alle Befehle
  /wsarrow debug                  Angaben für Fehlermeldungen

Die Entfernung wird aus deiner eigenen Bewegung vermessen; auf einer Karte,
auf der du noch nicht gelaufen bist, erscheint sie nach ein paar Schritten.

Gebäude werden an ihrer Tür erkannt. Loggt sich ein Charakter zum allerersten
Mal in einem Gebäude ein, bleibt der Pfeil sichtbar, bis du einmal hinaus- und
wieder hineingehst; danach merkt sich das Addon das, auch über Logins hinweg.
