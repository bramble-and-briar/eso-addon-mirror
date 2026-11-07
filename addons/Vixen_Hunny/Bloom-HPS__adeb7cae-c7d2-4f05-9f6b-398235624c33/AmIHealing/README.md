# Bloom HPS (LibFights edition)

A small Elder Scrolls Online meter that shows the following numbers, all taken from **LibFights**:

| Value | Meaning |
|---|---|
| **HPS / HPM** | Effective healing you did per second / minute (overheal excluded) |
| **Heal Personal / Group** | Your healing on yourself / on everyone else |
| **SPS / SPM** | Damage absorbed by shields on you per second / minute |
| **Shield** | Total damage absorbed by shields on you this fight |
| **Shield Personal / Group** | Absorbed by shields on you / on other group members (group mode) |
| **Mitigated / MPS / %** | Damage mitigated, per second, and as a share of incoming damage |

The meter looks like this:

```
HPS: 4k  HPM: 240k
Heal Personal: 10k  Group: 30k
SPS: 600  SPM: 36k  Shield: 6k
Shield Personal: 6k  Group: 9k
Mitigated: 6k  MPS: 600  (23.1%)
```

Rates are averaged over the current fight. When combat ends the meter keeps showing that fight's final numbers until the next fight starts. LibFights decides when fights start and end.

## Requirements

- **LibFights** 1.0.0 with the shield API (`GetSPS`, `GetSPM`, `GetTotalShield`) (required). A copy is in `LibFights/`.
- **LibAddonMenu-2.0** (optional, for the settings panel).

## Installation

1. Copy this folder into your AddOns directory as **`HPSMeter`**. The folder name must match `HPSMeter.addon`.
   - PC live: `Documents\Elder Scrolls Online\live\AddOns\HPSMeter\`
   - PTS: `Documents\Elder Scrolls Online\pts\AddOns\HPSMeter\`
2. Make sure LibFights is installed. The bundled `HPSMeter/LibFights/` copy works, or you can install it as its own `AddOns/LibFights/` folder. Use one copy, not both.
3. Enable **Bloom HPS** and **LibFights** in the in-game AddOns list.

Bloom HPS calls `Start_Logging()` for you when it loads. LibFights records nothing until that call. If another addon already started logging, Bloom HPS just reads the same data.

## Commands

| Command | Action |
|---|---|
| `/bloomhps` | Print healing, shielding (with personal / group splits) and mitigation for the current or last fight |
| `/bloomhps help` | List commands |

## Settings

Settings are under **Settings → Addons → Bloom HPS**:

- Show/hide the meter, position X/Y, scale
- Healing, shielding and mitigation colors
- Show/hide the shield lines, the personal / group split lines and the mitigation line
- **Track Group Shields** (on by default): starts LibFights in group mode, which the group shield number needs. Takes effect after `/reloadui`.

Settings from earlier versions (position, colors) carry over.

## Code layout

| File | Responsibility |
|---|---|
| `HPSMeter.addon` | Manifest. Declares LibFights as a dependency and sets the load order. |
| `src/Core.lua` | Namespace, defaults, number/color helpers, chat output |
| `src/Data.lua` | **The only file that touches LibFights.** Turns the current fight into the numbers above. |
| `src/UI.lua` | Label, shadow and auto-sizing backdrop. Builds the display text. |
| `src/Settings.lua` | LibAddonMenu-2.0 panel |
| `src/Commands.lua` | Slash commands |
| `src/Init.lua` | Startup. Hooks into LibFights' `FIGHT_STARTED` / `FIGHT_ENDED` callbacks. |

### Performance

Bloom HPS registers **no combat events of its own** and does not listen to LibFights' per-event `COMBAT_EVENT` callback. It reads the fight totals that LibFights already keeps, on a 500 ms timer that only runs during a fight. Out of combat it does nothing.

## How the numbers are calculated

From the LibFights fight object (`LibFights.GetLastFight()`):

| Value | LibFights call |
|---|---|
| HPS | `fight:GetHPS()` (`totals.healOut / duration`) |
| HPM | `fight:GetHPM()` |
| SPS | `fight:GetSPS()` (`GetTotalShield() / duration`) |
| SPM | `fight:GetSPM()` |
| Shield, Shield Personal | `fight:GetTotalShield()` (`totals.shieldAbsorbedIn`) |
| Shield Group | `fight:GetGroupShieldTotal()` (group mode only) |
| Heal Personal | `totals.selfHeal` |
| Heal Group | `totals.healOut - totals.selfHeal` |
| Mitigated | `fight:GetTotalMitigated()` |
| MPS | `fight:GetMPS()` |
| Mitigated % | `mitigated / (mitigated + totals.damageIn)` |

## Known limitations

- **SPS is shields absorbing damage on you, not shields you cast on others.** LibFights counts a "shield" when the game reports that damage was absorbed by a shield (`ACTION_RESULT_DAMAGE_SHIELDED`). That event says who was shielded, but not whose shield it was. As a result:
  - Shields from other players that absorb damage on you are counted.
  - Shields you put on allies are not.
- **Shield Group** counts damage absorbed by shields on other group members, whoever cast them. It needs LibFights group mode. If group mode is off, or another addon started LibFights without it, the meter shows `-`.
- **Heal Group** means your healing on anyone other than you, grouped or not.
- **Mitigated** is exact for shields. LibFights estimates the block, armor and avoid parts.
- Group mode makes LibFights read every combat event instead of only yours. That costs a little more in large fights. Turn off **Track Group Shields** if you don't need the group shield number.
- Heals from pets are counted, because LibFights treats player pets as the player. Heals from companions are not.
