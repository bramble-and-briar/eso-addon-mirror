# PurgeRadar Changelog

## 1.4.3

### Role-aware alerts
- Detects the local player’s LFG role via `GetGroupMemberSelectedRole("player")`.
- **DPS / Tank**: range-focused messaging → `Stack on the healing circles!`
- **Healer**: classic purge / heal-check messaging retained.
- **Disease Leak** (`233997`, Ossein Cage): tanks are completely excluded (no sound, no CSA, no tracking).

### Alert messages
| Situation | Message |
|-----------|---------|
| Disease Leak (DPS/Healer) | `[DISEASE LEAK] <Name> – Stack on the healing circles!` |
| Any tracked effect (DPS/Tank) | `[RANGE CHECK] <Name> – Stack on the healing circles!` |
| Purgeable DoT (Healer) | `[PURGE NOW] <Name> needs a cleanse!` |
| Heal-check DoT (Healer) | `[HEAL CHECK] <Name> – HEAL THROUGH (cannot purge)!` |

### Ability IDs – Must Purge (`ALERT_PURGE`)
- `70116` – Spindleclutch II: Enervating Seal
- `81047` / `81048` – Cradle of Shadows: Sickening Poison
- `78721` / `81053` – Cradle of Shadows: Delirium Poison
- `78604` / `81050` – Cradle of Shadows: Enfeebling Poison
- `74332` – Maw of Lorkhaj: Ruthless Salvo Bleed
- `74566` / `74568` – Maw of Lorkhaj: Lunar Flare
- `89222` – Halls of Fabrication: Melting Point
- `89159` – Halls of Fabrication: Phlebotomize
- `89969` – Halls of Fabrication: Gaping Wound
- `89953` – Halls of Fabrication: Greater Defile
- `89246` – Halls of Fabrication: Venom Injection
- `95415` – Asylum Sanctorium: Overheated
- `95493` – Asylum Sanctorium: Defiled
- `95420` – Asylum Sanctorium: Trial by Fire
- `108253` – Blackrose Prison: Fire Gauntlet
- `108620` – Blackrose Prison: Poisonbloom
- `108432` – Blackrose Prison: Arrow Spray Poison
- `108433` – Blackrose Prison: Venomous Spit

### Ability IDs – Heal-Check only (`ALERT_HEAL` / `ALERT_HEAL_RANGE`)
Cannot be purged; must be healed through. Range tracking and blue indicators still apply.
- `181234` – Scrivener’s Hall: Blood Boil
- `185456` – Exiled Redoubt: Deafening Gaze
- `190789` – Lep Seclusa
- `101234` – Fang Lair
- `112345` – March of Sacrifices
- `45678`  – Sanctum Ophidia
- `123456` – Sunspire / Sanity’s Edge: Ice Tomb
- `142345` – Kyne’s Aegis
- `100001` – Lucent Citadel
- `233997` – Ossein Cage: Disease Leak (`ALERT_HEAL_RANGE` – tanks excluded)

### Zone-in “equip Purge” warning
- Fires only in zones that contain **actual purgeable** DoTs:
  - Spindleclutch II, Cradle of Shadows, Maw of Lorkhaj, Halls of Fabrication, Asylum Sanctorium, Blackrose Prison
- Does **not** fire in heal-check-only zones (Sunspire, Sanity’s Edge, Ossein Cage, Scrivener’s Hall, Exiled Redoubt, Lep Seclusa, Fang Lair, March of Sacrifices, Sanctum Ophidia, Kyne’s Aegis, Lucent Citadel).
- Toggleable via settings: **Enable Zone DoT Warning** (default: on).

### Visuals & performance
- Floating icons (LibFloatingIcons) and group-frame colour overrides treat both `ALERT_HEAL` and `ALERT_HEAL_RANGE` as heal-checks (blue styling).
- Event filters on `EVENT_EFFECT_CHANGED` limited to group unit tags + tracked ability IDs.
- Range tracking loop (200 ms) starts/stops only while active effects exist.

### Settings (LibAddonMenu-2.0)
- Enable Sound Alerts
- Alert Playback Volume (1–5)
- Enable Zone DoT Warning

### Version
- `PurgeRadar.version = "1.4.3"`
