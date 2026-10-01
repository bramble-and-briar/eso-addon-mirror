# OneFrame 1.0

Enhances ESO's vanilla group and raid frames without replacing their controls,
textures, health animations, names, leader icons, ready checks or status indicators.
Supports English and Russian; other client languages use English.

## Installation / Установка

1. Install **LibAddonMenu-2.0**, including dependencies declared by that library,
   through your addon manager or [ESOUI](https://www.esoui.com/downloads/info7-LibAddonMenu.html).
2. Copy the **OneFrame** folder to
   `Documents/Elder Scrolls Online/live/AddOns/` (use your actual ESO documents folder).
3. Confirm `AddOns/OneFrame/OneFrame.txt` exists, enable the addon,
   and reload the UI. Open **Settings → Addons → OneFrame**.

Скопируйте папку **OneFrame** в `Documents/Elder Scrolls Online/live/AddOns/`,
установите **LibAddonMenu-2.0**, включите аддон и выполните `/reloadui`.
Настройки: **Настройки → Дополнения → OneFrame**. Настройки общие для аккаунта.

## Features and settings

- General: enable/disable; optional visual sorting (tank → healer → damage → unknown).
- Interaction: enable/disable frame interaction and the right-click menu independently.
  Whisper opens native chat input; Travel calls native group travel. Remove appears
  only for a leader with direct removal permission, never for oneself or in a vote-kick group.
- Player information: independent account name, native class icon, level and CP toggles.
  CP replaces level for Champion characters. Long account names truncate in compact frames.
- Role colors: vanilla Health/Magicka/Stamina gradients by default; independent custom
  colors and a button to restore native resource gradients. Unknown roles use Health.
- Combat statistics: optional shared DPS/HPS with independent local-player fallback
  and a separate Hodor integration toggle.
- Role-aware rates: damage dealers show DPS, healers HPS, tanks no rate counter.
  Ultimate icons and current points are independently available for every role.
- Damage shields: recolor the **existing shield overlay over the health bar**, including
  opacity. No second shield bar and no extra health polling are introduced.

Sort, account name and combat statistics are off initially. Other enhancements
are enabled. Disabling the addon in its settings restores native colors/anchors,
hides added text, disables menu actions and unregisters combat collection.

## Compatibility and deliberate limits

This release supports **API 101050 and 101051 (Update 51)**. Source audit uses
ESO 12.1.4 (pts12.1); live-client verification is pending. Other API versions
leave frames unchanged and show one localized message. No live-client validation
has yet been performed; use the repository's acceptance checklist before release.
Other addons replacing group frames are outside the compatibility scope.

**Optional Hodor integration:** verified with Hodor Reflexes **2026-05-17** and its
installed LibGroupCombatStats **2026-07-26**. No Hodor files are modified. Both are
optional dependencies; absent, disabled, uninitialized or unverified providers leave
other features working. Enable the relevant Hodor modules and sharing on senders.

OneFrame uses the library's public `GetUnitStats` and callbacks, registering a
consumer with an empty requested-statistics list. It does not start extra broadcasts,
change Hodor settings or duplicate a communication protocol. Each frame's current
account AND character must match the returned statistics. Reused frames never retain
a fixed player mapping; native name/status refresh updates text immediately.

**DPS** is shared total outgoing DPS, including in boss encounters; the library's
separate boss-DPS field is not substituted. **HPS** is shared effective outgoing
healing, not the separate raw/overheal field. In this library version both rates have
1000-unit precision and remote protocol fields max out at 999 (999k). For example,
87,200 becomes 87,000. Formatting also supports `985`, `12.4k`, `1.24m` for local values.

The supplied Hodor HPS UI divides encoded HPS by 10 when printing thousands, which
disagrees with this library's `/1000` encoder. OneFrame follows the actual library
units; its HPS may therefore differ from that Hodor list by 10×.

**Freshness:** shared DPS/HPS expire independently after 10 seconds without a metric
update. Combat start, roster changes, activation/zone changes and Hodor test transitions
invalidate previous values. Confirmed combat end also caps local shared results at
10 seconds. There are no encounter IDs in the protocol: delayed packets cannot be
attributed to a remote encounter with absolute certainty. Unchanged rates may stop
broadcasting and conservatively expire even while a fight continues.

Callbacks drive updates; a one-second sweep while enabled/grouped detects silent
unchanged packets (including zero) and expiry. No per-frame polling. Before any packet,
after expiry, or without a compatible provider, remote members display **`—`**, not
zero. A timestamped received zero displays **`0`**. Generic Hodor/ULT updates cannot
keep DPS/HPS fresh. No remote combat-event reconstruction is performed.

For the **local player**, valid shared DPS/HPS take priority independently. Each missing
metric falls back to the local meter below. Before any local measurement it also shows
`—`. Turning off Hodor integration does not stop the local meter.

**Ultimate:** actual ESO ability textures resolved from the IDs shared through Hodor,
with current points overlaid at the lower right. Both distinct shared bar abilities
appear because this protocol does not identify the active bar; matching IDs collapse.
No generic texture, ability-name substitute or fabricated zero is displayed.
Remote points and costs have two-point precision. Readiness uses the transmitted cost:
dim/desaturated when definitely insufficient, full brightness when definitely ready,
neutral when rounding makes the boundary uncertain. Local values retain full precision.
Ultimate is enabled by default and independent of the DPS/HPS settings.

To distinguish actual zero from unreceived default data, a version-gated runtime
post-hook observes LGCS field writes after their original handler. It never changes
provider values or files. Points expire after 10 seconds; roster/activation resets
require new receipts. Remote icons may wait for a new ability-type packet after reset.

The local meter sums reported outgoing damage/critical/DoT/blocked-damage events and
heal/critical/HoT events from `COMBAT_UNIT_TYPE_PLAYER`. It divides by time since local
combat began, with a one-second minimum. HPS uses raw event `hitValue`, not an estimate
of effective healing. Pet/companion contributions, shield absorption and unlisted
result categories are excluded. These values are **not full encounter-log DPS/HPS**.
The last result remains after combat, resets at the next local combat, activation/zone
transition, reload, or when collection is disabled. Enabling statistics mid-fight
measures only the period after enabling them.

**Shield checkbox:** disabling enhancement restores ESO's native shield rendering;
it does not suppress vanilla shields. This is intentional: native overlay children
also render trauma and healing restrictions. Native code owns shield values, clipping,
overflow, death/offline behavior and animations. Shield amounts above maximum health
saturate the native bar; this is not a numeric shield counter. Very small shields use
ESO's native visibility threshold. Role colors also apply to the native fake-health
layer used underneath shields so the HP color does not revert during shielding.

**Sorting:** changes anchors only, never unit tags or manager tables. Same-role order
uses account names as a deterministic stable key. Native positioning is restored
during combat, outside HUD/cursor HUD scenes and whenever companions are present.
Sorting resumes after those conditions clear. These restrictions preserve native
companion layout and group management behavior. No sorting runs on a render-frame loop.

**Interaction:** native handlers always execute. A right click that cancels a drag
does not open a menu. An existing menu created during that click takes precedence.
Actions validate the current frame, current membership and account/character identity
again when selected; outdated menus become no-ops. Travel failures use ESO's native
feedback. The addon adds no visible interaction controls. Mouse operation is intended
for PC keyboard/mouse, including cursor mode; gamepad-only navigation is not added.

**Layout:** added text stays compact and yields to death/offline/status messages.
Raid text is deliberately small and can truncate, particularly with long Russian
labels. Frame sizes and native label positions are unchanged. No class names are shown.

ДПС/ХПС союзников берутся из совместимого Hodor через LibGroupCombatStats; без свежих
данных — «—», полученный ноль — 0. Для своего персонажа есть локальный резервный расчёт.
Интеграция отключается отдельно и не меняет файлы/настройки Hodor. Проверены Hodor
2026-05-17 и LibGroupCombatStats 2026-07-26; шаг общих данных — 1000.
Выключение щитов возвращает стандартный вид ESO, сохраняя щиты и состояния лечения.
Сортировка временно отключается в бою, при наличии спутников и вне игрового HUD.
Перед публикацией нужна проверка внутри игры; автоматические тесты её не заменяют.

Ultimate доступен всем ролям: настоящая иконка способности и текущие очки поверх неё.
Если Hodor передаёт две разные способности, отображаются обе: активную панель протокол
не сообщает. Без достоверных данных элемент скрывается; полученный ноль отображается.
ДПС показывается бойцам, ХПС — целителям; у танков остаётся Ultimate без счётчика урона.

## Built-in group DPS

General → Group DPS enables the aggregate footer (on by default). The calculation is embedded in OneFrame and does not require LibCombat or Combat Metrics. Disabling it stops aggregate collection and clears its result; individual DPS/HPS are unaffected. Re-enabling begins a fresh aggregate sample. The module adapts the target-based collection from LibCombat v89 by Solinur; attribution, license and differences are in licenses/. ESO can omit distant events or include other players attacking the same target, so this is an estimate, not a complete server-side total.
