# ValuesBars

An add-on for **The Elder Scrolls Online** that shows the numbers the default UI hides: the current value, the maximum and the percentage on your bars, plus the charge percentage of your Ultimate.

## Features

- **Value and percentage on the bars:** health, magicka and stamina, target, boss and experience, for example `10,000 / 20,000 (50%)`.
- **Ultimate charge:** shows the percentage on the Ultimate ability button. It can go above 100%, and it disappears when no Ultimate is equipped on the active bar.
- **Flexible placement:** for health, magicka and stamina, put the text inside, above or below the bars, and adjust the spacing.
- **Alignment:** choose where the text sits horizontally on the magicka, stamina and experience bars.
- **Readability:** adjustable font size and four contrast styles (thin soft shadow, thick soft shadow, shadow and thick outline).
- **Number format:** with or without a thousands divider (`12,345` or `12345`).
- **Live preview:** see your changes in the settings menu without leaving it.
- **Languages:** English and Spanish. The add-on follows your game client language and falls back to English.

## Installation

1. Download the [latest release](https://www.esoui.com/downloads/info4940-ValuesBars.html) and extract it so the folder is named `ValuesBars`.
2. Move the folder to your add-ons directory:
   - **Windows:** `Documents\Elder Scrolls Online\live\AddOns\`
   - **macOS:** `~/Documents/Elder Scrolls Online/live/AddOns/`
3. Start the game and enable **ValuesBars** in the add-ons menu.

## Settings

Open **Settings > Add-Ons > ValuesBars**.

This menu needs [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html). It is optional: without it, ValuesBars still works with its default settings, you just can't change them.

| Group           | Options                                                                   |
| --------------- | ------------------------------------------------------------------------- |
| General         | Show Values, Show Preview                                                 |
| Text and Values | Font Size, Improve Contrast, Number Format, Show Percentage               |
| Character Bars  | Text Position, Text Spacing, Magicka / Stamina / Experience Bar Alignment |
| Ultimate        | Show Ultimate Percentage, Position (top, center or bottom of the button)  |

## Adding a language

All texts live in `lang/`. To add a language:

1. Copy `lang/en.lua` to `lang/<code>.lua`, where `<code>` is the language code of the game client (for example `de` or `fr`).
2. Change the code in `ValuesBars.RegisterLanguage("en", { ... })` to match the file name, and translate the values.
3. Keep every key exactly as it is. Only the values are translated, and `\n` is a line break that must stay.

No other file needs to change. Any key missing from a translation shows the English text.

## Saved settings

Settings are saved per account and per megaserver (NA, EU, PTS), so changing them on one server does not affect the others.

## Compatibility

Built for API version `101051`.

## Credits

- Thanks to **@Barfot** (in-game name).
- **Azurah**, a similar add-on that also shows values on the default bars, as a reference.
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html) for the settings menu.

## AI disclosure

This add-on was developed with the assistance of AI (Claude, by Anthropic). The code, the translations and the documentation were drafted with it, and the author reviewed and tested everything in-game. The English texts were also reviewed by a human reviewer.

## License

See the [LICENSE](LICENSE) file.

## Author

- Teniente.R (nick in game)
- rr69sport on [GitHub](https://github.com/rr69sport)
