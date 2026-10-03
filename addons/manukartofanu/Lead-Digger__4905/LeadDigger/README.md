# Lead Digger

Lead Digger is a small Elder Scrolls Online add-on that shows which zones contain your expiring antiquity leads. Zones with the most leads are shown first, and each count is colored according to the highest-quality lead in that zone.

The add-on counts only activated leads that appear in the Antiquities Journal. Unused tradeable lead items in your inventory are not included until they are activated.

The add-on supports English and Russian.

## Features

- Groups active antiquity leads by zone.
- Sorts zones by lead count, quality, expiration time, and name.
- Lets you choose how many zones are visible.
- Customizable width and text colors.
- Optional header and hidden-zone footer.
- Movable and lockable HUD list.
- Temporary preview mode with sample data for configuring the layout.
- Automatically hides when there are no active expiring leads.

## Requirements

- LibAddonMenu-2.0 r43 or newer.

## Installation

1. Copy the `LeadDigger` folder into:

   `Documents/Elder Scrolls Online/live/AddOns/`

2. Make sure LibAddonMenu-2.0 is installed and enabled.
3. Start ESO or run `/reloadui` if the game is already running.

## Configuration

Open **Settings → Addons → Lead Digger**.

Available settings include visibility, position locking, preview mode, visible zone count, zone-column width, header and footer visibility, and text colors.

Preview mode displays eleven sample zones. It uses the normal rendering path, so changes to the visible-zone limit, footer, colors, and dimensions can be checked immediately. Preview mode is temporary and turns off after `/reloadui` or restarting the game.

## Chat commands

- `/ld` — toggle visibility.
- `/ld show` — show the add-on.
- `/ld hide` — hide the add-on.
- `/ld lock` — lock its position.
- `/ld unlock` — unlock it for dragging.
- `/ld reset` — restore the default position.

The longer `/leaddigger` command supports the same arguments.

## Русский

Lead Digger показывает, в каких зонах накопились временные зацепки для поиска древностей. Зоны с наибольшим количеством зацепок отображаются первыми, а цвет числа соответствует зацепке наивысшего качества в этой зоне.

Аддон учитывает только активированные зацепки, отображаемые в журнале древностей. Неиспользованные обмениваемые предметы-зацепки в инвентаре не учитываются, пока их не активируют.

Настройки находятся в разделе **Настройки → Дополнения → Lead Digger**. Режим предпросмотра показывает одиннадцать тестовых зон и позволяет заранее настроить количество строк, ширину, цвета, заголовок и нижний колонтитул. После `/reloadui` или перезапуска игры предпросмотр автоматически отключается.

## License

Lead Digger is available under the [MIT License](LICENSE.txt).

## Legal notice

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
