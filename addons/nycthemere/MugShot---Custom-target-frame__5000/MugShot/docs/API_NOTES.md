# MugShot — API Notes

> API version confirmed: **101051** (from `ESOUIDocumentationP51_2.txt` header)
> Also accepting: **101052** (next patch, listed in manifest for forward compatibility)

---

## Functions Used

### Unit Identity

| Function               | Signature                      | Notes                                   |
|------------------------|--------------------------------|-----------------------------------------|
| `DoesUnitExist`        | `(unitTag) → bool`             | Guard before any other unit call        |
| `GetUnitName`          | `(unitTag) → string`           | NPC/object name                         |
| `GetUnitDisplayName`   | `(unitTag) → string`           | Player `@handle`; empty string for NPCs |
| `IsUnitPlayer`         | `(unitTag) → bool`             | True for player characters              |
| `GetUnitReaction`      | `(unitTag) → UnitReactionType` | Hostile, friendly, neutral constants    |
| `GetUnitReactionColor` | `(unitTag) → r, g, b`          | Returns 0–1 floats                      |
| `GetUnitClassId`       | `(unitTag) → number`           | Used to look up player class icon       |
| `GetUnitRaceId`        | `(unitTag) → number`           | Used to look up race icon badge         |
| `GetUnitAlliance`      | `(unitTag) → number`           | Used to look up alliance icon badge     |

#### UnitReactionType constants

```text
UNIT_REACTION_HOSTILE
UNIT_REACTION_FRIENDLY
UNIT_REACTION_NEUTRAL
UNIT_REACTION_PLAYER_ALLY
UNIT_REACTION_NPC_ALLY
UNIT_REACTION_COMPANION
UNIT_REACTION_DEFAULT
```

---

### Unit Vitals

| Function       | Signature                                           | Notes                                     |
|----------------|-----------------------------------------------------|-------------------------------------------|
| `GetUnitPower` | `(unitTag, powerType) → current, max, effectiveMax` | `COMBAT_MECHANIC_FLAGS_HEALTH` for health |

- `effectiveMax` accounts for max-health buffs; `max` is the base cap.
- Displayed format: `current/max` with lowercase unit abbreviations (`2.1m/3m`, `24.3k/24.3k`).

---

### Damage Shield

```lua
GetUnitAttributeVisualizerEffectInfo(
    unitTag,
    ATTRIBUTE_VISUAL_POWER_SHIELDING,   -- unitAttributeVisual
    STAT_MITIGATION,                    -- statType
    ATTRIBUTE_HEALTH,                   -- attributeType
    COMBAT_MECHANIC_FLAGS_HEALTH        -- powerType
) → value:nilable, maxValue:nilable, sequenceId:nilable
```

- When active, returns the numeric shield absorption capacity.
- Rendered as a cyan overlay bar (`0.50, 0.85, 1.0, 0.65`) and formatted into health text as `[value]` (e.g. `[3.6k]`).

---

### Buffs & Status Effects

```lua
GetNumBuffs(unitTag) → numBuffs
GetUnitBuffInfo(unitTag, buffIndex)
  → buffName, timeStarted, timeEnding, buffSlot, stackCount,
     iconFilename, deprecatedBuffType, effectType, abilityType,
     statusEffectType, abilityId, canClickOff, castByPlayer
```

- Icons and timers are displayed in a 10-slot pre-allocated container beneath the health bar.
- Timers are updated via a 250 ms ticker that automatically activates when timed effects are present and stops when no target or only passive effects exist.

---

### Events

| Event                                 | Params (after eventCode)                                                  | Filter strategy                                                                 |
|---------------------------------------|---------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| `EVENT_RETICLE_TARGET_CHANGED`        | _(none)_                                                                  | Fires only for reticleover target switches                                      |
| `EVENT_POWER_UPDATE`                  | `unitTag, powerIndex, powerType, powerValue, powerMax, powerEffectiveMax` | `REGISTER_FILTER_UNIT_TAG`, `"reticleover"`                                     |
| `EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED`   | `unitTag, unitAttributeVisual, statType, attributeType, powerType, …`     | Filtered in callback for `"reticleover"` and `ATTRIBUTE_VISUAL_POWER_SHIELDING` |
| `EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED` | Same as above                                                             | Same as above                                                                   |
| `EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED` | Same as above                                                             | Same as above                                                                   |
| `EVENT_EFFECT_CHANGED`                | `changeType, effectSlot, effectName, unitTag, …`                          | Filtered in callback for `"reticleover"`                                        |
| `EVENT_ADD_ON_LOADED`                 | `addonName`                                                               | Filtered to `"MugShot"`, then immediately unregistered                          |

---

### EVENT_MANAGER

```lua
EVENT_MANAGER:RegisterForEvent(namespace, event, callback)
EVENT_MANAGER:AddFilterForEvent(namespace, event, REGISTER_FILTER_UNIT_TAG, "reticleover")
EVENT_MANAGER:AddFilterForEvent(namespace, event, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_HEALTH)
EVENT_MANAGER:UnregisterForEvent(namespace, event)
```

---

### UI Controls & Anchors

- `WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultBackdrop")` inherits two anchors (`AnchorFill`). Always invoke `control:ClearAnchors()` prior to assigning custom dimensions or position anchors to avoid ESO anchor conflict warnings.
- `ZO_HUDFadeSceneFragment:New(frame)` attached to `HUD_SCENE` and `HUD_UI_SCENE` ensures smooth fade transitions without hiding the frame when opening the chat box.
