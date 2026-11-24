# Improved Death Recap: Vanilla UI

An add-on for **Improved Death Recap** (IDR) by Solinur. It shows IDR's data in the game's own death recap window instead of IDR's separate window.

IDR records much more about your death than the game does: every hit, damage over time tick, heal and shield in the last seconds, with the source and your remaining health. The game's death recap is the nicer window, but it only lists a few of the attacks. This addon fills the game's window with IDR's data, so you get both.

**Improved Death Recap must be installed and enabled.** This addon does not record anything by itself.

![Death recap with a long list of attacks](../_screenshots/ImprovedDeathRecapVanillaUI/ImprovedDeathRecapVanillaUI.png)

## What you see

- **Every recorded event, oldest to newest.** Hits, damage over time ticks, heals and shields. The list scrolls, and the window grows only as far as your screen allows. It opens scrolled to the killing blow.
- **Damage numbers colored by damage type.** Uses the same colors as IDR's chat log and Combat Metrics. Damage over time ticks use a darker shade of the same color.
- **An icon for how the hit landed:** direct hit, damage over time, blocked, healed, absorbed by a shield, or oblivion (unblockable).
- **Critical hits** are marked with `!` after the number.
- **Remaining health** after each event, colored from green to red.
- **Attacker names** as @names, with their AvA rank icon in their alliance color. In battlegrounds, names are colored by team. Improved Death Recap only records character names, so the @name comes from wherever the game knows it: players you had under the reticle, everyone in a battleground, your group, and the attackers in the game's own (short) death recap list, the killing blow included. Anyone else shows their character name.

If IDR has nothing recorded for a death (for example right after `/reloadui`), the normal death recap is shown.

## Settings

*Settings → Addons → Improved Death Recap: Vanilla UI*

- **Minimum damage/healing to show** (default 0): hides events smaller than this. The killing blow is always shown.
- **Show tips section** (default on): the game's tips under the attack list. Turning it off leaves more room for attacks on small screens.

## Keybinds

*Controls → Improved Death Recap: Vanilla UI* has **Scroll death recap up / down**, unbound by default. While you're dead the mouse usually turns the camera, so the mouse wheel only scrolls the list in cursor mode.

## Upgrading from ImprovedImprovedDeathRecap

This is the same addon under a new name. Delete or disable the old `ImprovedImprovedDeathRecap` folder, because the two can't run together. Settings are not carried over; the only ones are the minimum amount and the tips checkbox. Keybinds are kept.

## Requirements

- Improved Death Recap
- LibAddonMenu-2.0

