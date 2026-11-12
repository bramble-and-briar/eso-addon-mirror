InventoryPulse 1.0.2
====================

AI disclosure: The code of this addon was written with the help of an AI
assistant (Claude by Anthropic). The author reviewed it, tested it in-game
and is responsible for it.

--- English ---

InventoryPulse shows short messages in the middle of your screen that fade in
and then fly away in an arc. It has two parts:

BagCount
  Whenever the number of items in your backpack changes, you see how many
  slots are used (or free), e.g. "161/215" or "75% full". The color changes when only
  15 or 5 slots are left, and you get "Inventory full!" when nothing is left.
  You can choose to see it only from a certain fill level (e.g. 80 %) or only
  every few items (e.g. 150, 160, 170 ...).

StackCount (backpack, plus craft bag with ESO Plus)
  Whenever a material in your craft bag reaches 200, 400, 600 ... you see
  its icon and name and how many full 200 stacks you have, e.g.
  "Rubedite Ingot: 7×200". Handy if you sell full stacks in a guild store.
  Full stacks in the backpack are reported too (potions, soul gems,
  lockpicks ...), as those never go into the craft bag.

You can change almost everything: font, size, outline, opacity, colors,
how long the message stays in the middle and how it flies away.
Optional extras: the message can shrink while flying away (3D effect),
BagCount's font can grow with the fill level, and StackCount can play
a sound when a new 200 stack is complete.
By default messages only appear in the normal game view (not in menus)
and stay quiet while a bank is open.

Settings: Settings > Add-ons > InventoryPulse (needs LibAddonMenu-2.0),
or in chat: /ipulse help shows all commands and current values.

Optional libraries:
  - LibAddonMenu-2.0 (settings menu)
  - LibMediaProvider (more fonts)


--- Deutsch ---

InventoryPulse zeigt kurze Meldungen in der Bildschirmmitte, die langsam
erscheinen und dann im Bogen davonfliegen. Es besteht aus zwei Teilen:

BagCount
  Sobald sich die Anzahl der Gegenstände im Rucksack ändert, siehst du, wie
  viele Plätze belegt (oder frei) sind, z. B. "161/215" oder "75% voll". Die Farbe ändert
  sich, wenn nur noch 15 oder 5 Plätze frei sind, und bei vollem Rucksack
  erscheint "Inventar voll!". Auf Wunsch kommt die Meldung erst ab einem
  bestimmten Füllgrad (z. B. 80 %) oder nur alle paar Gegenstände
  (z. B. bei 150, 160, 170 ...).

StackCount (Rucksack, mit ESO Plus zusätzlich Handwerksbeutel)
  Sobald eine Ressource im Handwerksbeutel 200, 400, 600 ... erreicht,
  siehst du Icon und Name und wie viele volle 200er-Stapel du hast, z. B.
  "Rubedit-Barren: 7×200". Praktisch, wenn du im Gildenladen volle Stapel
  verkaufst.
  Volle Stapel im Rucksack werden ebenfalls gemeldet (Tränke, Seelensteine,
  Dietriche ...), denn die wandern nie in den Handwerksbeutel.

Fast alles ist einstellbar: Schriftart, Größe, Umriss, Deckkraft, Farben,
wie lange die Meldung in der Mitte steht und wie sie davonfliegt.
Optionale Extras: Die Meldung kann beim Wegfliegen kleiner werden
(3D-Effekt), die Schrift von BagCount kann mit dem Füllgrad wachsen, und
StackCount kann einen Ton abspielen, sobald ein neuer 200er-Stapel voll ist.
Standardmäßig erscheinen die Meldungen nur in der normalen Spielansicht
(nicht in Menüs) und bleiben stumm, solange eine Bank geöffnet ist.

Einstellungen: Einstellungen > Erweiterungen > InventoryPulse (benötigt
LibAddonMenu-2.0) oder im Chat: /ipulse help zeigt alle Befehle und die
aktuellen Werte.

Optionale Bibliotheken:
  - LibAddonMenu-2.0 (Einstellungsmenü)
  - LibMediaProvider (weitere Schriftarten)


## Development Notes

This addon was developed with the assistance of AI tools.
All generated content was reviewed and adapted before publication.


License: MIT (see LICENSE)
