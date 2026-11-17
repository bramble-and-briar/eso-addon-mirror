# Favorite Guild Cycler (v1.4.0)

**Developer:** Animosity  
**Special Credit:** Guild **CRY**

---

## Overview

**Favorite Guild Cycler** automatically rotates the represented guild displayed beneath your character's overhead nameplate across your chosen favorite guilds (Slots 1–5). Built from the ground up for **PlayStation 5 / Console Gamepad UI**, it integrates directly into your Character Sheet, Controller Keybind Strip, and `LibHarvensAddonSettings` menu while keeping your Character Sheet and Guild menus completely smooth and conflict-free.

## Key Features

### 1. Guild Nameplate Cycling & 5 Rotation Modes
- **Favorite Guild Selection (Slots 1–5)**: Choose exactly which of your joined guilds rotate beneath your character nameplate, or toggle to cycle through all joined guilds.
- **Persistent Guild-ID Memory**: Saves favorites by their true ESO Guild ID rather than slot number alone, so leaving or reordering guilds never causes the wrong guild to inherit a favorite.
- **5 Rotation Modes**:
  - **Sequential (`1 -> 5`)**: Rotates forward through your selected favorite guilds in order.
  - **Reverse (`5 -> 1`)**: Rotates backward through your selected favorite guilds.
  - **Shuffle Bag (`No Repeat`)**: Uses a fair Fisher-Yates shuffle bag so every favorite guild is displayed once in random order before reshuffling, with no back-to-back repeats.
  - **Priority Bias (`Primary 50%`)**: Displays your designated Primary Guild every other step (50% total display time) while rotating evenly through all of your other favorite guilds.
  - **Ping-Pong Bounce (`1 <-> 5`)**: Sweeps forward from your first favorite guild to your last and smoothly bounces back in reverse.
- **Optional Unrepresented Step**: Optionally insert a brief "No Guild Displayed" step at the end of each rotation loop.

### 2. Smooth, Hassle-Free PS5 Character Sheet Integration
- **Zero Scroll-Reset Architecture**: Uses persistent pre-commit row injection and in-place row refreshes (`RefreshVisible`) with a post-commit selection guard. Respeccing your **Attributes** (Magicka, Health, Stamina) or scrolling down to inspect your **Active Effects / Buffs** is completely smooth and never snaps or scrolls your menu back to the top.
- **Quick-Access Character Sheet Rows**: Toggle the cycler ON/OFF, step through cycle speeds, or open the interactive **Quick Guild Cycler Dialog** directly from your Character Sheet.
- **Isolated Controller Shortcuts**: Dedicated controller keybind shortcuts open the Quick Dialog or toggle cycling without interfering with native Character Sheet `X` button actions or the Guild Hub menu.

### 3. Smart Context Rules & Automatic Pause Controls
- **Quick Single-Guild Pin (`Pin Guild`)**: Temporarily lock your nameplate to a single guild for a raid night, event, or screenshot without losing your saved favorite checkboxes.
- **PvP Zone Guild Lock**: Automatically lock your nameplate to a specific guild whenever you enter **Cyrodiil**, **Imperial City**, or **Battlegrounds**.
- **Dungeon / Trial Instance Guild Lock**: Automatically represent your raid/progression guild whenever you step into a **4-player Dungeon, 12-player Trial, or Arena**, and resume normal cycling when returning to overland.
- **Group Leader Guild Match**: Automatically represent a shared favorite guild with your current Group Leader when grouped.
- **Smart Pause Toggles**:
  - **Active in Combat by Default** (with an optional toggle to pause during combat).
  - **Auto-Pause in Character Sheet & World Interactions** (bankers, crafting stations, merchants, outfit stations, and rededication shrines) enabled by default for uninterrupted menu navigation.
  - Optional pauses for **Menus**, **Stealth / Hidden**, **Mounted**, **Player Death**, and **Player Housing**.

### 4. API Rate-Limit Safeguard & Extra Customization
- **1-Second Minimum API Guard**: Enforces a minimum **1-second** interval (adjustable from **1s to 300s** via slider, or up to **600s** via slash command) to respect ESO's `SetRepresentedGuildId` API rate limit and help protect against Error 318 disconnects.
- **Account-Wide or Per-Character Profiles**: Share your favorite setup across your entire PSN account by default, or enable **Use Per-Character Settings** for character-specific rotations.
- **Optional Physical Tabard Sync**: Optionally swap matching physical Guild Tabards from your backpack when out of combat.
- **Fallback Guild Restoration**: Automatically restore a chosen fallback guild whenever cycling is turned off.

## Quick Slash Commands (`/fgc` or `/guildcycle`)

| Command | Action |
| :--- | :--- |
| `/fgc` | Instantly toggle guild cycling **ON** or **OFF** |
| `/fgc menu` | Open the gamepad **Quick Guild Cycler & Favorites** dialog |
| `/fgc next` | Immediately switch to the next favorite guild |
| `/fgc speed <1-600>` | Set cycle interval in seconds (e.g., `/fgc speed 5`) |
| `/fgc mode <seq\|rev\|rand\|priority\|pingpong>` | Switch rotation order mode |
| `/fgc fav <1-5>` | Toggle favorite status for Guild Slot 1–5 |
| `/fgc pin <1-5\|off>` | Temporarily pin a single guild slot, or `off` to unpin |
| `/fgc combat` | Toggle whether cycling stays active or pauses in combat |
| `/fgc list` | Display your joined guilds and current favorite badges |
| `/fgc status` | Show active status, currently displayed guild, and session switch count |
| `/fgc about` | Display add-on version and credits |

## Credits

- **Created & Maintained by:** **Animosity**
- **Guild Credit:** Special thanks and credit to the guild **CRY**
