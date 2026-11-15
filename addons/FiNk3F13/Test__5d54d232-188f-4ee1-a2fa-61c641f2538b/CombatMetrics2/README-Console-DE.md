# Combat Metrics 2 – Originaloptik mit Controller-Bedienung

Version 1.7.10-integriert.1 · Basis: Combat Metrics 1.7.8 von Solinur.

Version 10 verteilt das Erfassen des Originallayouts und die Größenanpassung des großen Kampfberichts auf kleine Schritte mit höchstens zwölf Bedienelementen pro Aufruf. Damit wird die im PS5-Foto gemeldete synchrone Rekursion beim Öffnen mit /cmx entfernt. Der Bericht öffnet sich nach Abschluss der Layoutarbeit; der erste Aufruf kann daher kurz dauern. Wiederholte Größenänderungen brechen veraltete Layoutaufträge ab. Ein neuer Regressionstest prüft 2.101 nachgebildete Bedienelemente, Größen und Anker, die Bildschirmbegrenzung, verzögertes Öffnen und den Abbruch veralteter Aufträge. Die Bindings-Korrektur aus Version 9 ist enthalten. Die tatsächliche Bestätigung auf der PS5 steht aus.

Version 9 korrigiert den beim Vereinheitlichen umbenannten Sondernamen der Tastenbelegungsdatei: Sie heißt wieder Bindings.xml und bleibt im Format Bindings. Andere XML-Dateien haben GuiXml als Hauptelement. Für die PS5 muss ein neues Release hochgeladen und installiert werden; Änderungen am PTS-Ordner aktualisieren die Konsole nicht. Die Dateistruktur wird zusätzlich auf XML-Hauptelemente geprüft.

Version 8 vereinheitlicht die Dateinamen und Manifestverweise auf CombatMetrics2. Alte, nicht geladene Testoberflächen und doppelte/veraltete Manifestdateien wurden aus dem Paket entfernt und außerhalb des Add-on-Ordners gesichert. Globale Namen und Speicherdaten bleiben gleich.

Version 7 stellt die vollständige Aufzeichnung bei bestehenden Testinstallationen einmalig wieder her. In den gelesenen Charaktereinstellungen war der Leichtmodus aktiv; er deaktiviert Kampfprotokoll und abgeschlossene Berichte. Spätere bewusst gewählte Modusänderungen bleiben erhalten. Der Schalter weist nun ausdrücklich auf fehlende Kampfberichte hin. Konsolenaktionen zur DPS-/HPS-Ausgabe zeigen eine native, lesbare Zusammenfassung und öffnen keine geschützte Chat-Eingabe. Der Aufzeichnungstest führt die ursprüngliche Ereignisregistrierung aus: Leichtmodus sperrt das Schadensprotokoll, Vollmodus registriert die Ereignisse wieder und übernimmt ein simuliertes Schadensereignis. Der Spieltest nach /reloadui steht aus.

Version 6 beseitigt den wiederholten Zugriff auf das private IsKeyDown bei der Controller-Navigation. Bericht und Kontextlisten verwenden jetzt ausschließlich die öffentliche Stickabfrage. Die Rückkehr aus den Einstellungen nutzt den öffentlichen Szenenwechsel; Chat-Zusammenfassungen verwenden StartChatInput. HUD-Werte werden auch im ausgeblendeten Zustand aktualisiert, fehlende Einzelwerte werden sicher behandelt, und beim Zurückkehren zum Spiel werden Sichtbarkeit und letzte Messwerte erneuert. Lokale Regressionstests bestehen; eine erneute Messung im PTS nach /reloadui muss dies im laufenden Spiel bestätigen.

Version 5 entfernt die Füllung der Auswahl vollständig, verwendet einen weißen 2-Pixel-Rahmen und einen transparenten Hintergrund für die große Hinweisbox.

Version 4 verbessert die Auswahl mit dem linken Stick: Ein goldener Rahmen mit drei Pixel breiten, durchgehenden Kanten markiert das angewählte Element. Die Beschreibungen der linken Symbole erscheinen in einer eigenen Textbox mit 27-Punkt-Controller-Schrift. Die Box wird an den Text angepasst und innerhalb des Bildschirms platziert. Spezielle Gegenstands- und Fähigkeitshinweise werden während der Auswahl zusätzlich vergrößert; beim Verlassen wird deren ursprüngliche Skalierung wiederhergestellt. Textauflösung, Positionierung und Ausblenden sind lokal geprüft. Die visuelle Bestätigung im Spiel nach `/reloadui` steht noch aus.

Startkorrektur in Version 3: Die alten `POWERTYPE_*`-Konstanten wurden durch die aktuellen `COMBAT_MECHANIC_FLAGS_*`-Konstanten ersetzt. In Version 2 brach dadurch die komplette UI-Datei beim Laden ab; `/cmx` meldete anschließend eine fehlende Fensterfunktion. Ein zusätzlicher Test führt jetzt die gesamte originale UI-Datei ohne die entfernten Konstanten aus und prüft, dass Initialisierung, Größenänderung und der Slash-Befehl registriert werden. Der Test besteht; die Bestätigung im laufenden PTS nach erneutem `/reloadui` steht noch aus.

Die PTS-Installation unter `AddOns/CombatMetrics2` lädt wieder die ursprünglichen Dateien `CombatMetrics2.xml`, `CombatMetrics2UI.lua` und die Legacy-Daten. Damit stammen das kompakte Live-HUD, das große Auswertungsfenster, Balken, Diagramme, Fähigkeitslisten und die zugehörigen Berechnungen aus dem Original. Die vorherige native Listenansicht ist nicht mehr der aktive Kampfbericht.

Aktuelle Testfassung: ausschließlich die eingebaute CMX2Combat (LibCombat v87 mit DoT-Fix). Die zusätzliche LibCombat2-Vergleichsanbindung, deren Dialog und /cmx2test wurden aus dem Paket entfernt. /cmx2 öffnet den normalen Bericht. Für einen vollständig isolierten Test auf der PS5 auch andere aktive Add-ons beachten: LiveBuffUptime2 kann LibCombat2 weiterhin selbst verwenden. Das separate LibCombat2-Add-on wurde durch diese Änderung nicht verändert.

## Benutzung

1. In ESO `Combat Metrics 2` aktivieren. Für den Vergleich können Original und CombatMetrics2 gleichzeitig aktiv sein: `/cmx` gehört dem Original, `/cmx2` dieser Fassung.
2. `/reloadui` ausführen, dann `/cmx2` eingeben. CombatMetrics2 registriert oder überschreibt `/cmx` nicht.
3. Auf dem Controller bewegt der linke Stick die weiße Auswahl über die ursprünglichen Bedienelemente. A/Kreuz löst das ausgewählte Element aus; X/Quadrat öffnet dessen Kontextaktion. LB/RB bzw. L1/R1 wechseln zum vorherigen/nächsten Feld. B/Kreis schließt den Bericht. Der rechte Stick scrollt dort, wo das ursprüngliche Element eine Scrollfunktion anbietet. Ein Druck auf den linken Stick schaltet Mehrfachauswahl um.
4. Y/Dreieck öffnet die ergänzten Controller-Einstellungen. Hier lassen sich HUD-Komponenten, Compact/Horizontal/Vertical, HUD-Größe und Position sowie die Größe des Berichts anpassen. Die Zuweisung der Tasten erfolgt über die jeweiligen ESO-UI-Aktionen; eigene Tastenbelegungen können abweichen.
5. Optional lässt sich der Bericht über LibRadialMenu → Combat Metrics 2 öffnen.

Das Add-on verwendet eigene Namen und eigene Speicherdaten (`CombatMetrics2_Save` und `CombatMetrics2FightDataSV`). Das originale Combat Metrics und seine gespeicherten Kämpfe wurden nicht geändert oder übernommen. Die Aufzeichnungs- und Kodierungsbibliotheken sind in getrennten Namensräumen enthalten; LibAddonMenu, LibCustomMenu und LibDebugLogger werden für diese Anpassung nicht benötigt.

## Prüfstatus

Die vorangehende Listenfassung ließ sich im tatsächlichen PTS-Konsolenmodus mit `/cmx` öffnen. Die jetzt wieder aktivierte Originaloberfläche wurde danach geändert und noch nicht im laufenden Spiel geprüft. Für diese Fassung bestehen die Lua-Syntaxprüfung, die Prüfung der Manifestpfade einschließlich Groß-/Kleinschreibung und lokale Tests für die ursprüngliche HUD-Ausgabe (DPS, Einzelziel-DPS, HPS, Überheilung, eingehende Werte und Zeit) sowie für die Controller-Auswahl, Kontextaktionen und Scrollweitergabe. Die lokalen Tests verwenden nachgebildete UI-Objekte. Ein vollständiger Kampf-, Diagramm- und Speicherlauf im echten Konsolenmodus steht noch aus.

Insbesondere Drag-and-drop, Mausauswahlbereiche im Diagramm und Spezialdialoge sind damit noch nicht als vollständig mit Controller bedienbar bestätigt. Die Originaloptik allein stellt diese Funktionen nicht automatisch auf Controller um.

Die Installation im PTS aktualisiert keine PlayStation oder Xbox. Es wurde nichts hochgeladen oder veröffentlicht.

Ursprüngliche Autorenangaben und Lizenzen sind im Paket erhalten.
