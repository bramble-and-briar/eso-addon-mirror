ARCLIGHT TAUNT 1.0.3
Modernes Multi-Target-Taunt-HUD fuer The Elder Scrolls Online
Autor / Pflege: tareN

FUNKTIONEN
Arclight Taunt zeigt erkannte aktive Taunt-Effekte mehrerer Gegner in einem
kompakten und anpassbaren HUD. Farbcodierte Restzeiten, schmale oder vollflaechige
Balken, Zielhervorhebung, Bosskennzeichnung und Boss-Frueh-/Ablaufwarnungen
helfen Tanks auch bei groesseren Gegnergruppen, den Ueberblick zu behalten.

PFLICHTBIBLIOTHEKEN (SEPARAT INSTALLIEREN)
- LibAddonMenu-2.0 r43 oder neuer:
  https://www.esoui.com/downloads/info7-LibAddonMenu-2.0.html
- LibMediaProvider:
  https://www.esoui.com/downloads/info56-LibMediaProvider.html
Beide Bibliotheken sind erforderlich, aber nicht im Download enthalten.

INSTALLATION
1. Den Ordner ArclightTaunt nach
   Dokumente/Elder Scrolls Online/live/AddOns/ entpacken.
2. Die Datei muss direkt hier liegen:
   .../AddOns/ArclightTaunt/ArclightTaunt.txt
3. Beide Bibliotheken separat installieren (beispielsweise mit Minion).
4. ESO starten oder /reloadui verwenden und dann das Menue oeffnen:
   ESC > Einstellungen > Add-ons > Arclight Taunt

AKTUALISIEREN
Nur den bisherigen Ordner ArclightTaunt ersetzen. Den SavedVariables-Ordner
nicht loeschen: Er enthaelt die persoenlichen Einstellungen und HUD-Position.

STANDARDWERTE (NEUINSTALLATION)
- HUD-Position X=1507, Y=370; HUD-Groesse 125 %, Bildschirm-Anpassung aktiv.
- Eine Spalte mit bis zu zehn Eintraegen, nach Restzeit sortiert.
- Tuerkis / Gelb ab 7 s / Rot ab 4 s, Warnschwellen anpassbar.
- Schmaler Signalbalken; optionaler Fortschritt ueber die ganze Zeile.
- Boss-Fruehwarnung ab 2,5 s und Ablaufwarnung standardmaessig aktiv.
- Boss-Ablaufwarnton standardmaessig an mit Todesstoß; Immunitaet/Stapel aus.
- Einmaliger Begruessungshinweis bei Neuinstallation.

SPRACHEN
Englisch ist Haupt- und Fallbacksprache. Deutsch, Franzoesisch, Spanisch
und Russisch werden automatisch anhand der ESO-Spielsprache gewaehlt.
Andere Clientsprachen verwenden Englisch. Gespeicherte Einstellungen,
Medien und Positionen bleiben beim Sprachwechsel erhalten.

BEKANNTE EINSCHRAENKUNGEN
- Tracking nutzt derzeit die Taunt-Effekt-IDs 38254 und 38541. Nicht alle
  Faehigkeiten, insbesondere Scribing-Kombinationen, wurden einzeln geprueft.
- Ein abgelaufener Taunt bedeutet nicht zwingend einen Aggro-Wechsel.
- Die erweiterte Bosserkennung kann starke Nicht-Bosse einbeziehen.
- Immunitaets-/Stapelanzeige ist experimentell; keine Gruppensynchronisation.
- Die HUD-Zielmarkierung nutzt beobachtete eigene Taunt-Zeiten oder eine direkt
  durch ein Effektereignis bestaetigte Identitaet. Fuer Pet-/Gruppenziele und
  den Todesfallback ist ein direkter Ereignisbezug erforderlich. Unsichere
  Zeituebereinstimmungen entfernen keine andere Gegnerzeile. Es gibt keine
  separate Anzeige am Fadenkreuz.
- Fehlende Medien verwenden voruebergehend eine Ersatzdarstellung. Die Auswahl
  bleibt gespeichert und kann bei spaeterer Registrierung wieder erscheinen.
  Die verfuegbaren Medienlisten werden beim Oeffnen der Einstellungen erneuert.

BOSS-EINSTELLUNGEN
Warnungen und Erkennung stehen gemeinsam unter Bosse. Darstellung der Warnung
und Boss-Erkennung haben eigene Ueberschriften; Boss-Warnungen entfaellt als Dopplung.
Warnung testen spielt den ausgewaehlten Ton nur bei aktiviertem Warnton ab.
Das rote Ablaufbanner und die kleinere tuerkise Fruehwarnung haben getrennte,
feste Bereiche: Tuerkis liegt unter der Position des roten Banners. Beide
koennen gleichzeitig erscheinen und fassen ihre Bosse jeweils getrennt zusammen.
Fruehwarnungen entfernen einen Boss beim Ablauf, erneuten Taunt oder erkannten
Tod sofort; sie warten nicht hinter Rot. Ihre Lebensdauer folgt den aktiven
Taunts im Fruehwarnfenster. Die Anzeigedauer gilt fuer Rot und Testvorschauen.
Beide Bereiche nutzen dieselbe Position und Deckkraft. Warnung testen zeigt
zuerst Rot und bei aktivierter Fruehwarnung 1,5 Sekunden spaeter Tuerkis. Nur im
kombinierten Test bleibt Rot mindestens 2 Sekunden sichtbar, ohne die gespeicherte
Dauer zu aendern. Fruehwarnungen bleiben lautlos.
Kommt Tuerkis zu sichtbarem Rot hinzu, gleitet es verdeckt dahinter nach unten
hervor. Allein blendet Tuerkis weich ein und aus. Kommt Rot spaeter dazu, startet
eine sichtbare Fruehwarnung nicht neu. Erweiterte Bossgruppen blenden ohne
abrupten Neustart weiter; bei sehr kurzer Restzeit wird der Einflug verkuerzt.
Resets, Schalter und echte Warnungen verwerfen vorgemerkte Testmeldungen.
Die beiden Warntests stehen direkt nach den Fruehwarn-Einstellungen nebeneinander
mit gleicher Breite. Willkommens- und Sprach-/Schrifttest stehen gemeinsam unten
in Tracking & Experimente. Zeilenhintergrund bleibt optional und standardmaessig
ohne Textur; vorhandene Hintergrund-Auswahlen bleiben erhalten.
Der Ton wird gemeinsam mit Warnung testen geprueft; es gibt keinen separaten
Probehoerknopf. Der echte Audio-Cooldown bleibt durch Vorschauen unveraendert.
Angeheftete Bosse mit
abgelaufenem Taunt stehen vor Bossen mit aktivem Taunt; die normalen
Ausblenderegeln gelten weiterhin. Gespeicherte Tonwahlen bleiben erhalten;
Todesstoß gilt fuer Neuinstallationen oder wiederhergestellte Standardwerte.
Die fuenf Hauptueberschriften verwenden wieder die normale weisse Darstellung. Akzente
innerhalb der Bereiche: Champagner fuer Boss-Erkennung, Rot/Tuerkis fuer
Warnungen, Blau fuer Zielfokus und Gelb fuer
experimentelle Anzeigen. Normale Einstellungen und Tests bleiben dezenter.

OFFIZIELLE WEBSITE UND FEEDBACK
https://www.esoui.com/downloads/info5008-ArclightTauntModernTankHUD.html
Im Add-on-Einstellungsmenü findest du unter dem Titel Website und Feedback.
Beide führen zur ESOUI-Seite (Feedback über die Kommentare).

SUPPORT
Bei fehlendem Taunt bitte Faehigkeit, Morph, Spielsprache, Begegnung,
beobachtetes Verhalten und gegebenenfalls Lua-Fehler auf ESOUI melden.

CREDITS / TRANSPARENZ
Entwicklung und Pflege durch tareN. Die Funktionen und das Interface wurden
umfangreich im echten ESO, auch in DLC-Dungeons, getestet und durch automatisierte
Lua-Regressionstests ergaenzt. KI-gestuetzte Lua-Programmierung wurde unter
Leitung von tareN eingesetzt. Keine Verbindung zu ZeniMax Online Studios.
LibAddonMenu-2.0 und LibMediaProvider sind externe Pflichtbibliotheken, die
nicht in diesem Archiv mitgeliefert werden.
