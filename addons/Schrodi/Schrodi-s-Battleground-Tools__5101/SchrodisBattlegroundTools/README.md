# Schrodi's Battleground Tools

A battlegrounds addon: a more informative scoreboard and a faster way to queue.

## Credits and history

Inspired by **[Better Scoreboard](https://www.esoui.com/downloads/info3182-BetterScoreboard.html)** by **M0R** (@M0R_Gaming), which added damage, healing and class icons to the battlegrounds scoreboard and a multi-queue selection. This addon started as a visual patch for Better Scoreboard's scoreboard, grew into a standalone addon and is now a complete rewrite: it contains no code from Better Scoreboard. Remembering the mode on the built-in Battlegrounds screen is an idea from *BattlegroundModeSaver*.

Better Scoreboard isn't needed. Disable it, as well as BetterBetterScoreboard and BattlegroundModeSaver if you still have them: they hook the same game controls, and this addon does what they did.

## Scoreboard

![Scoreboard in a 6v6v6 match](../_screenshots/SchrodisBattlegroundTools/SchrodisBattlegroundTools-scoreboard.png)

- **Damage and healing** next to each player's score, plus **class icons**.
- The game's own Damage, Heals and flag columns (added in 12.1.5) are hidden again, and the window keeps its narrower width.
- **Big lobbies fit without a scrollbar** (9v9, 6v6v6, 8v8). The list grows with your screen height, and if that's still not enough, rows are packed closer together.
- **One name per row**, chosen by the setting below (by default, the game's own "Prefer character names" setting).

## Queuing

![Multi-queue panel](../_screenshots/SchrodisBattlegroundTools/SchrodisBattlegroundTools-queue.png)

A multi-queue panel in the Group & Activity Finder. By default it **replaces the Battlegrounds panel** (the entry keeps its name and icon); with that setting off it's a separate **Battleground Queue** entry right after Battlegrounds.

- **Queue several battleground types at once** with checkboxes. Your selection is remembered between sessions. The list updates by itself when a queue unlocks or a weekly event starts or ends.
- **Quick buttons** such as *4v4 Competitive* or *Big Team Battles* above Join Queue: one click selects the solo and group versions of that queue and joins.
- Your **battleground rank** and XP bar, as on the Battlegrounds screen.
- **Bonus rewards** under the list: whether today's daily bonus reward is still available (it's shared by all battlegrounds, not tied to one queue), what the reward is, and the solo bonus for joining a Group queue alone.
- **Auto requeue** *(off by default, resets on every reload)*: click the "Auto requeue: On/Off" line above the Finder's "Status" to switch it. If you decline a ready check, you are queued again for the same battlegrounds once the cooldown is over. A ready check that times out, or leaving the queue yourself, never requeues you.
- **Cooldown timer**. After declining or missing a ready check, the Finder's "Status: Queued" text shows how long until you're allowed to queue again, and the Join Queue button stays disabled until then.
- **Time in queue on the HUD**: the game's activity tracker shows e.g. *Queued for 10:45*.

  ![Time in queue on the HUD](../_screenshots/SchrodisBattlegroundTools/SchrodisBattlegroundTools-tracker.png)

The buttons and checkboxes are disabled whenever the game wouldn't let you queue anyway: already queued, mid ready check, using the Group Finder, or on cooldown.

If you prefer the game's own Battlegrounds screen (turn off *Replace the Battlegrounds panel*), it **remembers the last selected mode** across reloads (account-wide).

## Settings

*Settings → Addons → Schrodi's Battleground Tools* or `/sbt` (needs LibAddonMenu-2.0; without it everything runs with the defaults)

- **Player name display:** game setting, @account, character name, or both, in either order.
- **Replace the Battlegrounds panel** (on). Takes effect after a reload.
- **Time in queue on the HUD** (on).
- **Remember last battleground mode in vanilla finder** (on).
- **Show quick queue buttons** (on).
- Colors for Competitive and Standard queues and for damage and healing numbers.

All settings are account-wide and apply immediately, except replacing the Battlegrounds panel.

## Changelog

See [changelog.txt](changelog.txt).
