# Ride Along

One keybind to hop on the multi-rider mount of a group member, without targeting them or opening the interaction wheel.

*Controls → Ride Along → Ride with a group member*, or `/ride`.

- If you're looking at a group member who has a free seat, you ride with them.
- Otherwise you ride with the **nearest** group member within 5 m who is on a multi-rider mount with a free seat.
- If there's nobody, or you can't get on right now (in combat, dead, already riding along), you get a short chat message.

## Why it doesn't replace the mount key

The ideal would be a single key: ride along if there's a free seat, otherwise summon your own mount. The game doesn't allow that. The mount keybind calls `ToggleMount()`, which is a **private** function: addon code can neither call it nor wrap it. So Ride Along needs its own key.

## Upgrading from Mounty Python

This is the same addon under a new name. Delete the old `MountyPython` folder. The keybind has a new name too, so bind it again in *Controls → Ride Along*.
