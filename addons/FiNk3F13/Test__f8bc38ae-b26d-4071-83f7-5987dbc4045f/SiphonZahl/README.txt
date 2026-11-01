SIPHON ZAHL 0.6.9 BETA - .addon / Gamepad / PTS API 101052

BEDIENUNG
Im Gamepad-Einstellungsmenue den Add-on-Bereich von LibHarvensAddonSettings
und Siphon Zahl oeffnen. Keine Chatbefehle.
Move UI einschalten, mit rechtem Stick verschieben und wieder ausschalten.
Groesse sowie horizontale und vertikale Position sind per Regler einstellbar.
Vorschau 3 ist eine Beispielzahl. Position und Groesse werden gespeichert.
Leichenereignisse werden innerhalb und ausserhalb des Kampfes verarbeitet.
Kampfende setzt die Zaehlung nicht zurueck. Nur im Kampf anzeigen betrifft
ausschliesslich die Sichtbarkeit; Verbrauch und Ablauf werden weiter verfolgt.
Ein Tastendruck ohne bestaetigten Verbrauch markiert Leichen nicht unsicher.
Corpseburster-Verbrauchsmeldungen werden mit Siphon-Zielmeldungen abgeglichen.
Ein verbleibendes ? bedeutet weiterhin: Verbrauch nicht eindeutig zugeordnet.

DIAGNOSE
Bei wiederholten Fragezeichen Debug-Aufzeichnung im Einstellungsmenue aktivieren.
Problem nachstellen und danach ausloggen, damit ESO die SavedVariables schreibt.
Gespeichert werden maximal 300 Ereignisse in SiphonZahlSaved.debugLog mit
Zeitpunkt, Kampfstatus, technischen IDs, Pet-Effekten und dem Unsicherheitsgrund.
Keine Spielernamen und kein automatischer Upload. Standardmaessig aus.

ABHAENGIGKEIT
LibHarvensAddonSettings >=20109, separat installieren/aktivieren.
CorpseTracker und LibAddonMenu sind fuer diese Version nicht erforderlich.

BEGRENZTE LEICHENSCHAETZUNG
Eigene Blastbones-Schadenereignisse, Schaedel-Leichenmarker 220102 und
Banner-Leichenmarker 227114: geschaetzte Lebensdauer 5 Sekunden.
Neu: erkannte Geister-Morphs (Spirit Guardian/Intensive Mender) bei natuerlichem
Tod und erkannte Skelettmagier-/Schuetzen-Effekte bei Ablauf: Schaetzung 10 Sekunden.
Erzeugung wird erst beim passenden Ereignis gezaehlt, nicht beim Beschwoeren.
Geister werden nicht pauschal anhand eines Timers als tote Leichen behandelt.
Mehrere Meldungen fuer dieselbe Unit-ID werden zusammengefasst.
Siphon-Selbstmeldungen warten kurz auf eine identifizierende Zielmeldung.
Identifizierter Verbrauch wird abgezogen; unbekannter Verbrauch markiert
den bisherigen Restbestand mit ?. Neue Leichen werden dabei nicht rueckwirkend
als unsicher markiert. Corpseburster wird nicht als Leichenerzeugung gezaehlt.
Keine vollstaendige Zaehlung aller Leichen im Raum: NPC-Leichen, unerkannte
Pet-Morphs, Ruestungsquellen und virtuelle Ressourcen sind nicht enthalten.
Bereits vor dem UI-Neuladen beschworene Pets werden nicht nachtraeglich erfasst.
IDs, Lebensdauern und Verhalten muessen im Zielpatch im Spiel getestet werden.
Keine Garantie fuer Reichweite, Sichtlinie oder Nutzbarkeit.
0 rot: keine unterstuetzten Leichen geschaetzt.
3 gruen: drei geschaetzte Leichen.
3? gelb: unsicherer Restbestand; es koennten weniger oder keine sein.

STATUS
SiphonZahl.addon ist das einzige Manifest; Dateinamen exakt geprueft.
Im PC-PTS-AddOns-Ordner installiert. Nicht auf Konsole veroeffentlicht.
Konsolen beziehen Add-ons aus ESOs Katalog; ein PC-PTS-Ordner reicht nicht.
Lua-Mocktests bestanden. Kein realer Xbox-/PlayStation-Test erfolgt.
Mit OpenAI Codex entwickelt. Keine fremden Quelldateien enthalten.
Nicht mit ZeniMax Media Inc. verbunden oder von ihr gesponsert.


Diagnose 0.6.4 protokolliert auch Todesereignisse und vergleicht deren IDs mit nicht zugeordneten Siphon-Zielen. Daraus werden noch keine NPC-Leichen gezaehlt.


Korrektur 0.6.5: Ein in den Kampfereignissen identifizierter, getoeteter NPC wird als separate Verbrauchsquelle erkannt. Wird seine Leiche mit Siphon verwendet, bleiben eigene Schaedel-/Blastbones-Eintraege unveraendert. Diese Zuordnung laeuft auch bei deaktiviertem Debug. NPC-Leichen werden weiterhin nicht in die angezeigte eigene Leichenschaetzung aufgenommen.


0.6.6: Skelettbeschwoerungen werden beim Entfernen nahe ihrem gemeldeten natuerlichen Laufzeitende ebenfalls als Leichenschaetzung erfasst, auch ausserhalb des Kampfes. Fruehes Entfernen wird nicht pauschal gezaehlt. Veraltete Fade-Meldungen fuer andere Unit-IDs werden ignoriert. Debug zeichnet nun auch den Ablauf gezaehlter Leichen auf. Dieser neue Ersatzpfad ist mit Mocktests geprueft, noch nicht im Spiel bestaetigt.


0.6.7: Siphon-Effektmeldungen werden nur nach einer bestaetigten Siphon-Aktivierung als Verbrauch ausgewertet. Reines Frontbar-/Backbar-Wechseln darf weder Leichen verbrauchen noch den Bestand unsicher markieren. Antworten auf eine echte Aktivierung werden auch nach einem folgenden Waffenwechsel verarbeitet. Debug protokolliert Waffenwechsel und versieht neue Eintraege mit der Versionsnummer.


0.6.8 PS5-Diagnose: Debug-Aufzeichnung im LibHarvens-Menue aktivieren und das Menue schliessen. Links oben erscheinen die laufende Add-on-Version, API, Plattform, letzte Aktivierung, Waffenpaar und Verbrauchsgrund. Leiche erzeugen, Frontbar/Backbar/Frontbar wechseln und bei erneutem Fragezeichen einen Screenshot dieser Diagnose aufnehmen. Diese ZIP ist fuer den Konsolen-Upload vorbereitet, nicht auf PS5 veroeffentlicht oder dort getestet.


0.6.9: Autor FiNk3--F13--. Radiusfilter standardmaessig aktiv, Standardradius 8 Meter, im LibHarvens-Menue einstellbar. Verglichen werden die Spielerposition und gemeldete eigene Pet-Leichenpositionen. Bekannte Leichen ausserhalb des Radius werden nicht angezeigt, intern aber fuer Verbrauch und Ablauf weiterverfolgt. Position unbekannt oder ungueltig: Leiche wird ausgelassen. Eine 0 ist daher kein Beweis, dass absolut keine nutzbare Leiche existiert. Kein Sichtliniencheck, keine vollstaendige NPC-Erfassung. Die Debug-Anzeige zeigt Innen/Aussen/Position unbekannt. Positionsverfuegbarkeit auf echter PS5 muss noch geprueft werden. AI-Unterstuetzung: OpenAI Codex.

