# Bloom HPS (LibFights edition)

A small Elder Scrolls Online meter that shows the following numbers, all taken from **LibFights**:

| Value | Meaning |
|---|---|
| **HPS / HPM** | Effective healing you did per second / minute (overheal excluded) |
| **Heal Personal / Group** | Your healing on yourself / on everyone else |
| **Crit Heal / Crit HPS / Crit Rate** | (optional) Healing from critical heals, per second, and the share of your heals that critted |
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

## Battlegrounds and history

- **In a battleground** the meter adds up every fight of the match (rates are over your time in combat) and its title reads *Bloom HPS · Battleground*. When the battleground finishes, or you leave it early, the match totals are printed in chat, saved, and the meter is reset for the next one. The running totals are kept in the saved variables, so a `/reloadui` mid-match does not lose them.
- **History** (needs LibESQL): every fight and every battleground is saved in two LibESQL tables, so you can look back later:
  - `bloomhps_fights`: one row per fight (`bg_id` links it to its battleground)
  - `bloomhps_bgs`: one row per battleground, with its mode and result (`Win` / `Loss` / `Tie` / `Left` / `Unknown`)

  Both have the date, character, zone, duration, HPS, HPM, healing (personal / group), crit healing, shields and mitigation. The oldest fights are dropped once there are 3000. You can also query the tables yourself in the ESQL window, for example `SELECT * FROM bloomhps_bgs WHERE result = 'Win'`.

## Requirements

- **LibFights** 1.0.0 with the shield API (`GetSPS`, `GetSPM`, `GetTotalShield`) (required). A copy is in `LibFights/`.
- **LibAddonMenu-2.0** (optional, for the settings panel).
- **LibESQL** (optional, for the saved fight / battleground history). Without it the battleground totals and reset still work, but nothing is saved.

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
| `/bloomhps fights [text]` | The 10 newest saved fights whose zone, battleground, date or character contains `text` (SQL `LIKE '%text%'`, not case-sensitive). No text lists the newest. |
| `/bloomhps bg [text]` | The 10 newest saved battlegrounds whose name, mode, result, zone, date or character contains `text`, e.g. `/bloomhps bg loss`, `/bloomhps bg 2026-11` |
| `/bloomhps bg #12` | Battleground 12 and each of its fights |
| `/bloomhps textures` | Show which texture path is in use and whether each candidate path loaded |

## Settings

Settings are under **Settings → Addons → Bloom HPS**:

- Show/hide the meter, position X/Y, scale. While you change the position or scale, the meter stays on screen (even if it is switched off or hidden by the menu) until about 2.5 seconds after the last change.
- Healing, shielding and mitigation colors
- **Show Critical Healing Line** (off by default): adds Crit Heal, Crit HPS and heal Crit Rate
- Show/hide the shield lines, the personal / group split lines and the mitigation line
- **Show Battleground Totals** (on by default): show the whole match while in a battleground, reset when it finishes
- **Save Fight & Battleground History** (on by default, needs LibESQL)
- **Track Group Shields** (on by default): starts LibFights in group mode, which the group shield number needs. Takes effect after `/reloadui`.

Settings from earlier versions (position, colors) carry over.

## Code layout

| File | Responsibility |
|---|---|
| `HPSMeter.addon` | Manifest. Declares LibFights as a dependency and sets the load order. |
| `src/Core.lua` | Namespace, defaults, number/color helpers, chat output |
| `src/Data.lua` | **The only file that touches LibFights.** Turns a fight (or the summed fights of a battleground) into the numbers above. |
| `src/History.lua` | Battleground totals and reset, saving fights / battlegrounds to LibESQL, and the `LIKE` lookups |
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
| Crit Heal | `totals.healOutCrit` (effective healing from `CRITICAL_HEAL` / `HOT_TICK_CRITICAL`) |
| Crit HPS | `HPS * healOutCrit / healOut` |
| Crit Rate | `totals.healCritsOut / totals.healHitsOut` |
| Mitigated | `fight:GetTotalMitigated()` |
| MPS | `fight:GetMPS()` |
| Mitigated % | `mitigated / (mitigated + totals.damageIn)` |

## Textures (PC and console)

Textures load in the background, and only once the game draws them. Consoles take much longer than PC to get past the loading screen. Bloom HPS therefore checks its textures like this:

- It waits until the loading screen is gone (`EVENT_PLAYER_ACTIVATED`).
- It tries every candidate folder spelling (`/HPSMeter/`, `HPSMeter/`, and the folder name reported by the game) at the same time, then uses the first one that loads.
- If nothing has loaded after 20 seconds, it shows a plain background and keeps checking every 5 seconds. When a texture loads later, the flowers come back.

After installing or updating the addon, **fully restart the game**, especially on console. `/reloadui` does not pick up new texture files. On console, also make sure the `textures/` folder is included in the package you upload.

## Known limitations

- **SPS is shields absorbing damage on you, not shields you cast on others.** LibFights counts a "shield" when the game reports that damage was absorbed by a shield (`ACTION_RESULT_DAMAGE_SHIELDED`). That event says who was shielded, but not whose shield it was. As a result:
  - Shields from other players that absorb damage on you are counted.
  - Shields you put on allies are not.
- **Shield Group** counts damage absorbed by shields on other group members, whoever cast them. It needs LibFights group mode. If group mode is off, or another addon started LibFights without it, the meter shows `-`.
- **Heal Group** means your healing on anyone other than you, grouped or not.
- **Mitigated** is exact for shields. LibFights estimates the block, armor and avoid parts.
- Group mode makes LibFights read every combat event instead of only yours. That costs a little more in large fights. Turn off **Track Group Shields** if you don't need the group shield number.
- Heals from pets are counted, because LibFights treats player pets as the player. Heals from companions are not.
