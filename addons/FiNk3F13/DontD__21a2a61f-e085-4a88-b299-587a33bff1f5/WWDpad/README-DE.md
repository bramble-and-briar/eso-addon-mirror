# WW D-Pad — Version 0.6.1

Autor: FiNk3--F13--

## Manuelle Hotkeys

Hotkey 1 lädt das nächste Setup der aktuell gewählten WW-Seite.
Hotkey 2 lädt das im Feld Setupname für Hotkey 2 eingetragene Setup derselben
Seite, zum Beispiel Miniboss. Danach setzt Hotkey 1 die normale Reihenfolge
an der gemerkten Position fort: Trash 3 → Miniboss → Trash 4.
Nach dem letzten normalen Setup wird wieder das erste geladen.

Die normale Reihenfolge umfasst alle Setups auf der Seite. Der Zielname muss
eindeutig sein. Groß-/Kleinschreibung und äußere Leerzeichen werden ignoriert.
Bei leerem, unbekanntem oder doppeltem Zielnamen erfolgt kein direkter Wechsel.

Einstellungen: PC/PTS → Einstellungen → Erweiterungen → WW D-Pad;
Konsole → Optionen → Add-ons → WW D-Pad.

Wähle zwei unterschiedliche Tasten. Verfügbar sind die ESO-Aktionen
Aufgabenwechsel (normal Steuerkreuz rechts), Karte (PlayStation: Touchpad)
und Waffe ziehen/wegstecken. Deine ESO-Belegung gilt entsprechend.
Je nach Aktion ist Gedrückthalten nötig. Belegte Tasten tauschen ihre Rollen.
Die Umbelegung gilt nur im Gamepad-Modus bei geschlossenem Menü.

## Tastendruck im Kampf

Ein Hotkey-Tastendruck im Kampf merkt genau einen Wechsel vor. Es wird nicht
versucht, Ausrüstung oder Fähigkeiten während des Kampfes zu wechseln.
Nach Kampfende wird das vorgemerkte Setup geladen, unter Beachtung der
bestehenden 800-ms-Sperre und bei geschlossenem Menü.

Weitere Eingaben werden nicht aufgestaut. Der erste vorgemerkte Wechsel bleibt
maßgeblich. Es werden also auch beim Spammen nicht mehrere Setups nachgeladen.
Bei Hotkey 1 wird die nächste Position zum Zeitpunkt des Tastendrucks gemerkt;
bei Hotkey 2 das zu diesem Zeitpunkt gefundene Zielsetup.

Der vorgemerkte Wechsel wird bei Tod, einem Ladebildschirm, Ausschalten des
Add-ons oder einer Änderung der WW-Seite bzw. des betroffenen Setup-Eintrags
verworfen. Ein manueller vorgemerkter Wechsel hat Vorrang vor der Automatik.
Während eines bereits laufenden WW-Wechsels werden weitere Hotkeys ignoriert.

## Optionale automatische Bosserkennung

Automatische Bosserkennung ist standardmäßig AUS und unabhängig auswählbar.
Der Hauptschalter Hotkeys aktivieren schaltet auch die Automatik ab.

Bei aktivierter Automatik nutzt WW D-Pad WWs vorhandene GetBossByLocation-
Raumfunktion der ausgewählten WW-Seite und vorhandene Boss-Einheiten.
So können unterstützte Bossbereiche bereits vor dem Auftauchen des Bosses
zugeordnet werden, soweit WWs jeweilige Raumfunktion das liefert.
Es handelt sich um dieselbe Raumgrundlage wie WW, nicht um eine neue Karte.

Bei erkanntem Boss laden bietet zwei Möglichkeiten:

- Passendes WW-Setup: sucht auf der aktuell ausgewählten Seite nach einer
  exakten WW-Bossbedingung oder einem exakt passenden Setupnamen. Im Namensmodus
  kann auch ein passend benanntes anvisiertes angreifbares Ziel einen Miniboss
  identifizieren. Fehlende oder mehrdeutige Zuordnungen führen zu keinem Wechsel.
- Immer Setup von Hotkey 2: lädt bei einem erkannten Bossbereich oder einer
  Boss-Einheit das unter Hotkey 2 eingetragene Setup, zum Beispiel Miniboss.
  Ein beliebiger anvisierter Gegner löst diesen Modus nicht aus.

Automatische Wechsel erfolgen nur außerhalb des Kampfes und ohne geöffnete
Menüs. Eine bereits verarbeitete Begegnung löst nicht fortlaufend neue Wechsel
aus. Ein manueller Hotkey-Wechsel wird nicht sofort durch dieselbe erkannte
Bossbegegnung rückgängig gemacht. Bei einem Erkennungsfehler schaltet sich nur
die Automatik aus; die manuellen Hotkeys bleiben verfügbar.

Zum Prebuffen kannst du die Automatik ausschalten. WWs eigene automatische
Setupwechsel weiterhin ausgeschaltet lassen, damit nicht zwei Automatiksysteme
wechseln. WW D-Pad verändert WWs Einstellungen nicht.

## Schalter im Schnellrad

In LibRadialMenu → WW D-Pad stehen zwei Einträge zur Verfügung:

- WW-Hotkey AN/AUS: Hauptschalter für manuelle Hotkeys und Automatik.
- Bossautomatik AN/AUS: nur die automatische Erkennung umschalten.

Auf PC/PTS kann /wwdpad den Hauptschalter umschalten.

## Schutz und Update

Alle Wechsel teilen sich eine Sperre: WW-Abschluss abwarten und danach 800 ms Pause. Ohne Bestätigung nach 45 Sekunden oder bei einem Fehler während
des gestarteten Wechsels schaltet sich das Add-on ab. Dann WW prüfen, /reloadui
ausführen und gegebenenfalls wieder aktivieren.

Die gemerkte normale Position ist je ausgewählter WW-Seite und Charakter
getrennt und gilt bis zum Neuladen. Ein zwischenzeitlich manuell geladenes
Prebuff-Setup verschiebt die gemerkte Position nach einem direkten Sprung nicht.

PTS: WWDpad ist im PTS-AddOns-Ordner installiert; nach Update /reloadui.
Manuell den alten WWDpad-Paketordner ersetzen. Vorhandene Hotkey-Einstellungen
und der Zielsetupname bleiben erhalten; die neue Automatik startet AUS.

PS5: Paket über den ESO-Konsolen-Uploader veröffentlichen und anschließend aus
dem Add-on-Katalog installieren. Die PTS-Installation aktualisiert keine Konsole.

Abhängigkeiten: Wizard's Wardrobe mit seinen Bibliotheken, LibRadialMenu,
auf PC LibAddonMenu-2.0, auf Konsole LibHarvensAddonSettings.
Andere Umbelegungen derselben Tasten deaktivieren.

## Prüfung

Mit ESO-Stubs geprüft: normale/directe Wechsel und Rückkehr, Prebuff,
Menüs, Tastenbelegungen und Migration, 1.000 Eingaben über beide Tasten,
1.000 Eingaben im Kampf mit genau einem Wechsel nach Kampfende, Abbruch der
Vormerkung, 800-ms-Sperre, Automatik-Schalter, WW-Bossraum ohne sichtbare
Boss-Einheiten, Namens-/Bedingungszuordnung, fester Automatik-Zielmodus und
Vorrang manueller Eingaben. Test im laufenden ESO und auf Konsole steht aus.

Mit KI-Unterstützung erstellt. Nicht von ZeniMax Media Inc. oder verbundenen
Unternehmen erstellt, unterstützt oder gesponsert.
