# Immersive Rumors
**Author:** Fadosch | **Version:** 1.0.0

An immersion addon for **The Elder Scrolls Online (Update 51+)** that removes blue text highlights from **Rumors** clues, hints, and journal entries. 

Now, important keywords and clues blend seamlessly into the surrounding text color so you actually have to read and solve the mysteries yourself instead of having the answers served on a silver platter!

---

## English

### What it does
In Update 51, the new **Rumors** detective system was introduced. While Rumors removed compass waypoints and quest markers to encourage old-school detective gameplay, the game still highlights key terms and locations in bright **blue** text (e.g. `|c3A92FF...|r`). 

This makes clues trivial to solve without reading the actual narrative. **Immersive Rumors** fixes this by:
- **Stripping blue/cyan highlight codes** from Rumors hints and clue texts.
- **Blending keywords seamlessly** into the surrounding text color (e.g. standard parchment white/cream).
- **Preserving non-hint formatting:** Gold rewards (`|cFFD700`), red failure warnings, or green success text remain completely untouched.
- **Universal Language Support:** Works seamlessly across **ALL game client languages** (English, German, French, Russian, Japanese, Spanish, Chinese, etc.) because it filters internal color tags, not language-specific words.

### Features
- **Quest Journal & Rumors Tab:** Automatically sanitizes Rumors details upon opening, switching entries, or refreshing (Keyboard & Gamepad mode).
- **Bullet Lists:** Intercepts clue lists on entry so newly discovered clues appear without blue highlights.
- **NPC Dialogues (Optional):** Cleans dialogue texts when speaking with rumor NPCs (e.g., Tilli the Gossip).
- **Readable Notes & Lore Reader (Optional):** Cleans in-game letters and notes.
- **Settings Menu:** Integrated into [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) under `Settings -> Addons -> Immersive Rumors`.

### In-Game Chat Commands
- `/ir` (or `/immersiverumors`, `/rnbh`, `/noblue`) — Displays addon status and help.
- `/ir on` — Enables the addon.
- `/ir off` — Disables the addon.
- `/ir toggle` — Toggles the addon on or off.
- `/ir debug` — Toggles debug mode (prints detected and cleaned text lines in chat).

### Installation
1. Extract the `ImmersiveRumors` folder into your ESO AddOns directory:
   `Documents/Elder Scrolls Online/live/AddOns/`
2. Launch ESO (or type `/reloadui` in chat if already running).
3. Under the in-game **Add-Ons** menu, make sure **Immersive Rumors** is checked.

---

## Deutsch

### Beschreibung
In Update 51 wurde das neue **Gerüchte-System (Rumors)** eingeführt. Obwohl das System bewusst auf Kompass-Markierungen und Zielpfeile verzichtet, hebt das Spiel wichtige Schlüsselwörter und Zielorte in auffälligem **Blau** hervor (z. B. `|c3A92FF...|r`). 

Dadurch muss man die Hinweistexte kaum lesen, um die Lösung zu erfassen. **Immersive Rumors** behebt dies:
- **Entfernt blaue und cyanfarbene Hervorhebungen** aus Hinweistexten und Beschreibungen.
- **Natürliche Textfarbe:** Hervorgehobene Begriffe übernehmen nahtlos die Umgebungsfarbe (z. B. das Pergament-Weiß des Tagebuchs) – man muss die Texte tatsächlich aufmerksam lesen!
- **Erhält andere Formatierungen:** Belohnungen (z. B. Gold `|cFFD700`), rote Warnungen oder grüne Erfolgsmeldungen bleiben unangetastet.
- **Funktioniert in allen Sprachen:** Da interne Farbtags gefiltert werden, funktioniert das Addon auf Deutsch, Englisch, Französisch und jeder anderen Sprache identisch.

### Funktionen
- **Quest-Tagebuch & Gerüchte-Reiter:** Automatische Bereinigung beim Öffnen, Wechseln oder Aktualisieren von Gerüchten (Tastatur- & Gamepad-Modus).
- **Bullet-Listen:** Fängt Aufzählungslisten direkt ab, sodass neu gefundene Hinweise sofort ohne Blau erscheinen.
- **NPC-Dialoge (optional):** Bereinigt auch Gespräche mit Klatschbasen und Questgebern (z. B. Tilli).
- **Gelesene Notizen & Briefe (optional):** Bereinigt lesbare Zettel und Schriftstücke in der Spielwelt.
- **Einstellungsmenü:** Integriert in [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) unter `Einstellungen -> Erweiterungen -> Immersive Rumors`.

### Chat-Befehle
- `/ir` (oder `/immersiverumors`, `/rnbh`, `/noblue`) — Zeigt Status und Kurzhilfe an.
- `/ir on` — Aktiviert das Addon.
- `/ir off` — Deaktiviert das Addon.
- `/ir toggle` — Schaltet das Addon um.
- `/ir debug` — Schaltet Debug-Ausgaben im Chat an/aus.

---

### Mandatory Notice as Required by ZeniMax
```
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates.
The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc.
in the United States and/or other countries. All rights reserved.
You can read the full terms at: https://account.elderscrollsonline.com/add-on-terms
```
