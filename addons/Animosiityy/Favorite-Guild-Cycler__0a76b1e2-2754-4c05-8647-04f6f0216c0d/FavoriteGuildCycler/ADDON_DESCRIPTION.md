# Favorite Guild Cycler — Add-On Description

**Created by:** Animosity  
**Guild Credit:** CRY  
**Version:** 1.4.0 (PS5 / Console & Gamepad Edition)

## Short Description (For Manifest / Console Add-On Listing)

Automatically rotates the displayed guild beneath your character nameplate across your selected favorite guilds (Slots 1–5). Built for PS5 and Gamepad UI with smooth, zero-scroll-reset Character Sheet controls, 5 rotation modes (Sequential, Reverse, Shuffle Bag, Priority Bias, and Ping-Pong), Quick Guild Pin, automatic PvP and Dungeon/Trial guild locks, Group Leader sync, and a 1-second API rate-limit safeguard. Created by **Animosity** with special credit to the guild **CRY**.

## Organized Feature Breakdown

### Core Nameplate Cycling
- **Custom Favorite Rotation (Guilds 1–5)**: Pick which of your joined guilds rotate beneath your character nameplate, or cycle through all joined guilds at once.
- **True Guild-ID Persistence**: Remembers your favorite guilds by their unique ESO Guild ID across logins and reloads, so reordering or leaving guilds never mixes up your favorites.
- **5 Rotation Modes**:
  1. **Sequential (`1 -> 5`)**: Cycles forward in order from your first favorite guild to your last.
  2. **Reverse (`5 -> 1`)**: Cycles backward in reverse order.
  3. **Shuffle Bag (`No Repeat`)**: Fair random deck shuffle that displays each favorite guild once before reshuffling, preventing back-to-back repeats.
  4. **Priority Bias (`Primary 50%`)**: Displays your main guild 50% of the time while rotating evenly through all of your other favorite guilds (`Primary -> Guild B -> Primary -> Guild C...`).
  5. **Ping-Pong Bounce (`1 <-> 5`)**: Sweeps forward from first to last and smoothly bounces back.
- **Safe Speed Control (1s – 300s)**: Enforces a strict 1-second minimum interval to respect ESO's represented-guild API rate limit and protect against Error 318 disconnects.

### Smooth PS5 Character Sheet & Controller UI
- **Hassle-Free Character Sheet Integration**: Toggle cycling ON/OFF, step through cycle speeds, or open the **Quick Guild Cycler Dialog** right below your Character Sheet list—while keeping **Attribute Respeccing** (Magicka, Health, Stamina) and **Active Effects / Buffs** inspection 100% free of scroll resets or cursor jumps.
- **Conflict-Free Native Menus**: Leaves the Guild Hub and native Character Sheet dropdowns untouched so controller navigation always feels responsive.
- **Full Add-On Settings Menu**: Complete `LibHarvensAddonSettings` menu under **Options -> Add-Ons -> Favorite Guild Cycler**.

### Smart Context Automation & Pauses
- **Quick Guild Pin (`/fgc pin`)**: Temporarily lock a single guild for a trial run, PvP session, or guild event without erasing your saved favorite selections.
- **PvP & Dungeon/Trial Locks**: Automatically lock a dedicated PvP guild in **Cyrodiil / Imperial City / Battlegrounds** or a dedicated PvE raid guild inside **Dungeons, Trials, and Arenas**.
- **Group Leader Match**: Optionally represent a shared favorite guild with your current Group Leader.
- **Smart Pause Rules**: Works **in combat by default** (with an optional combat pause toggle), automatically pauses background switching while you are viewing your Character Sheet or interacting with crafting stations/bankers/shrines, and includes optional pauses for Menus, Stealth, Mounted riding, Player Death, and Player Housing.
- **Account-Wide or Per-Character Profiles**: Share settings across all characters by default, or enable per-character profiles, Fallback Guild restoration, and optional Physical Tabard syncing.

### Quick Slash Commands
- `/fgc` — Toggle guild cycling ON or OFF
- `/fgc menu` — Open the Quick Guild Cycler & Favorites dialog
- `/fgc next` — Switch to the next favorite guild immediately
- `/fgc speed <1-600>` — Set cycle speed in seconds
- `/fgc mode <seq|rev|rand|priority|pingpong>` — Change rotation mode
- `/fgc fav <1-5>` — Toggle favorite status for Guild 1–5
- `/fgc pin <1-5|off>` — Pin a single guild or unpin (`off`)
- `/fgc status` — View live status, current guild, and session switch count
- `/fgc about` — View version and credits

## Credits
Developed by **Animosity** with special credit and thanks to the guild **CRY**.
