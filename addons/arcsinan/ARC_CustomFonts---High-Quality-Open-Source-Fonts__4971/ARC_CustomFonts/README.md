# ARC_CustomFonts

**ARC_CustomFonts** by **@arcsinan** provides a curated collection of high-quality, 100% royalty-free open-source fonts for *The Elder Scrolls Online* (ESO).

All fonts are pre-compiled into ESO's modern `.slug` font format (Update 41+ Slug font renderer engine) as well as standard `.ttf` format.

## Features

- **LibMediaProvider (LMP) Integration**: All 11 custom fonts are automatically registered with `LibMediaProvider-1.0`. Any media-capable addon (such as **Bandit UI**, **pChat**, **AUI**, **Foundry Tactical Combat**, **Azurah**, **Combat Metrics**, **SCT**, etc.) can immediately select these fonts from their in-game dropdown menus!
- **Optional In-Game UI Font Overrides**: Easily replace standard ESO fonts for **Chat**, **General UI**, **Headers & Window Titles**, and **Books & Lore** directly from the Addon Settings menu.
- **100% Free & Open-Source (SIL OFL / Public Domain)**: No proprietary or copyright-restricted fonts. Every typeface is freely licensed for open distribution.
- **Turkish Diacritics & Extended Unicode**: Complete support for `ç, ğ, ı, İ, ö, ş, ü, â, î, û` and European characters.

---

## Included Fonts

| Font Name | Style | Recommended Use | License |
| :--- | :--- | :--- | :--- |
| **Cinzel** | Roman / Fantasy Serif | Titles, lore headers, character names | SIL OFL |
| **Cinzel Decorative** | Ornate Fantasy Capitals | Achievement titles, prominent window headers | SIL OFL |
| **MedievalSharp** | Gothic Celtic Fantasy | Storybook dialogue, medieval RP immersion | SIL OFL |
| **Bebas Neue** | High-Impact Bold Condensed | Combat numbers, SCT damage, cooldown timers | SIL OFL |
| **Inter** | Ultra-Crisp Modern Sans | Chat log, inventory list, tooltip text | SIL OFL |
| **Outfit** | Contemporary Geometric Sans | Minimalist clean modern UI | SIL OFL |
| **Lora** | Warm Classic Editorial Serif | Quest dialogue, books, notes, and scrolls | SIL OFL |
| **DejaVu Sans** | Reliable Clean Sans-Serif | General interface readability | Public Domain |
| **DejaVu Sans Bold** | Bold Clean Sans-Serif | High-visibility interface labels | Public Domain |
| **Turkish Font Regular** | High-Compatibility Unicode | Chat and UI with full Turkish diacritics | Public Domain |
| **Turkish Font Bold** | High-Compatibility Bold | Headers and buttons with full Turkish diacritics | Public Domain |

---

## Slash Commands

- `/customfonts` - Opens the ARC Custom Fonts settings panel.
- `/arcfonts` - Shortcut to open the settings panel.

---

## Dependencies (Mandatory)

This addon requires the following libraries to function properly:
- **LibAddonMenu-2.0** (`>= 43`): For the in-game settings panel and font configuration.
- **LibMediaProvider-1.0** (`>= 34`): For registering media and sharing fonts across addons.

*Both libraries can be installed automatically via [Minion](https://minion.mmoui.com/) or downloaded manually from ESOUI.*
