# PB's GammaAdjuster

Fixes the console game forgetting your brightness at login in The Elder Scrolls Online: asks the
game to apply the brightness you saved in *Calibrate Brightness* again as soon as you enter the
world.

- **Author:** PinkBanther
- **Version:** 1.1.0
- **Requires:** `LibHarvensAddonSettings` >= 20106

## What it does, and what it cannot

Since Update 51 (API 101051) the console game comes up at the default brightness at every login,
even though the brightness you saved is still stored. This add-on notices that the screen and the
stored brightness differ and asks the game to apply the stored one. It looks as soon as the player
is activated and again 1, 5 and 15 seconds later, in case the game puts its own value back.

**It cannot choose a brightness.** Earlier versions (1.0.x) had a slider that wrote a value. On
console the game ignores that write, so the slider never changed anything and it was removed. Set
the brightness in the game's own *Calibrate Brightness* screen, as usual; this add-on brings that
saved value back after a login.

It calls the game only when the two values differ. If the screen is already at the saved
brightness, nothing is touched.

## Settings

- **Restore the saved brightness at login** -- on by default.
- **Restore the saved brightness now** -- a button that does the same thing by hand.

## Chat commands

| Command | |
|---|---|
| `/pbgamma` | The live and the saved brightness, how the client classes `ApplySettings`, the last result and a log of what the game answered. |
| `/pbgamma resync` | Restore the saved brightness now. |
| `/pbgamma on` / `off` | Restore it at login, or leave it to the game. |

If the screen does not change after a login, type `/pbgamma` and send the lines it prints.

## Why this works (measured on PS5, Update 51, API 101051, 2026-10-10)

The brightness lives in two places and they come apart:

| | what it is |
|---|---|
| live value | the CVar `GAMMA_ADJUSTMENT`. What the renderer follows and what the calibration screen shows. The pregame screen sets it to 100 on console on purpose (ESO-404970), a reset that dates from 2019. |
| saved value | the graphics setting `GRAPHICS_SETTING_GAMMA_ADJUSTMENT` (`GetSetting`). What the console profile loads, and what the player saved. |

Right after login the live value read `100` and the saved value read `133` (and `138`, `135` on
other days): the profile still has the right value, it is just no longer pushed to the live one.

What an add-on can do about it:

| call | result |
|---|---|
| `SetCVar("GAMMA_ADJUSTMENT", v)` | Returns normally and changes nothing. Add-on code is untrusted and the console drops the write silently. |
| `SetSetting(...)` | Private. Raises UI error 459E4D05, even under `pcall`. |
| `CallSecureProtected` | Reaches only functions the client classes as protected. `SetCVar` is classed neither protected nor private, so it does not apply. |
| `RefreshSettings()` | **Destructive.** With live 100 and saved 135, one call left both at 100: it pulls the live value into the saved one. The client calls it whenever the options screen opens. Never called by this add-on. |
| `ApplySettings()` | **Works.** With live 100 and saved 133, one call left both at 133. It is the options screen's Apply button: it makes the engine use the stored settings. |

The add-on calls `ApplySettings` and judges the result against the saved value as it was
beforehand. A call that overwrote the saved brightness (as `RefreshSettings` does) is reported as
that, never as success, and stops every further automatic call that session; the player then
re-saves the brightness in *Calibrate Brightness*. The automatic path makes at most three calls
per session.

The calibration screen cannot be borrowed instead. It writes the CVar from trusted client code;
calling its confirm handler puts an add-on function on the call stack, and showing the screen from
an add-on would build its dialog -- including the confirm handler -- under an add-on frame, which
is how a client closure becomes permanently untrusted.

### Did Update 51 change the brightness code?

Checked against the client's Lua source (`esoui/esoui`, branch `live`, 12.1.5 of 2026-09-28):

- The calibration screen (`gammaadjust.lua`) has not changed since 10.0.5 (2024-06).
- 12.1.5 changed the legal-document screens and added VFX intensity options; 11.3.4 only
  reordered the entries of the gamepad video menu.
- `ESOUIDocumentation.txt` has not changed its `GetCVar` / `SetCVar` entries since 2016.

Nothing visible in Lua explains the missing push, so it is in the engine, which the Lua source
does not show. It looks like a game bug worth reporting to ZeniMax.

## Notes

- **Do not open the game's settings right after a login, before the add-on has restored the
  brightness.** The game calls `RefreshSettings` when the options screen opens; with the screen
  still at the default, that overwrote a saved 135 with 100 when the add-on's diagnostic called it
  (measured), and very likely the 138 that had turned into 100 between two logins. The add-on
  restores as soon as you enter the world.
- HDR: the game hides its own gamma setting while HDR is on. The add-on does not check; `/pbgamma`
  prints whether the system reports HDR.

## Tests

```
lua test/run.lua        # any Lua 5.1+, luajit included
```

Runs the add-on's load and login sequence against a stand-in client modelled on the measurements
above: two stores, an `ApplySettings` that pushes, does nothing or overwrites, a game that resets
its value late, a client that says the call is private or protected, unreadable values, the
settings panel and the slash commands. It also counts calls to `SetCVar`, `SetSetting` and
`RefreshSettings` over every session and requires zero. It cannot say what the real console does;
the PS5 measurements above did.
