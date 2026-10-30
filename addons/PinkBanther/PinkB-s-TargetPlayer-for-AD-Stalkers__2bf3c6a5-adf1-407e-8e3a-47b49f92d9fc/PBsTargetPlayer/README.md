# PB's TargetPlayer for AD Stalkers

Puts the game's own target marker on chosen players in The Elder Scrolls Online on console, so
they stand out above their nameplate.

- **Author:** PinkBanther
- **Version:** 1.7.0
- **Requires:** nothing. `LibHarvensAddonSettings` >= 20106 is optional and gives you the settings
  panel; without it the chat commands do everything.

## Who may use it

**Two PSN IDs only: `SO1-WYLDE` and `PinkBanther`.** At load the add-on reads the console ID of the
player who is logged in (`GetPlatformDisplayName`) and runs only if it is one of those two (case, a
leading `@` and surrounding spaces do not matter). The ESO `@account` is not consulted.

Anyone else who installs it gets one line in chat after login --
「あなたはこのアドオンを使用できません」 -- and nothing more: no events, no settings panel, no saved
variables, no markers. `/pbtarget` repeats the message and shows which PSN ID was read, so a refused
owner can see whether the ID was mis-read. The message is Japanese whatever the client language is.

The check lives in `Main.lua`, which is plain text on the player's machine. It keeps the add-on from
being used by accident or by a casual installer; it is not protection against someone who edits the
file. To change who is admitted, edit `ALLOWED_USERS` in `Main.lua`.

## What it does

Register up to **twenty players**. When you put the reticle on one of them, the add-on sets a
**target marker** on them -- the same marker the game's marker wheel sets. The engine draws it
above their nameplate, and the game also shows its icon in front of the name in the target frame
and the group frames.

You choose which of the eight markers is used (blue square, gold star, green circle, orange
triangle, pink moons, purple Oblivion, red crossed swords, white skull). The default is the red
crossed swords. It is one marker for everybody you registered.

**Where they are, and when they enter Cyrodiil.** For a registered player who is on your **friend
list** or in one of your **guilds**, `/pbtarget where` says where they are right now -- the zone,
the character, the guild, or how long ago they were last online -- and the same line is shown as the
*Location* row of each entry in the settings panel. When such a player **enters Cyrodiil**, or comes
online there, the band and sound announce it. The game reports the **zone**, not the position, so
it cannot say which keep.

**A player who is neither a friend nor in a shared guild is on no roster, so the game does not say
where they are now.** What the add-on can say is where and when it last **came across** them -- and it
keeps that for every registered player, whoever they are:

| Seen in | What it tells you |
| --- | --- |
| The Cyrodiil **kill feed** | They killed someone or were killed, **near a named keep**. |
| A **fight** with you or your group | Close by. |
| **/say, /yell, an emote** | Close by. |
| **Zone chat** | In your zone. |
| Under your **reticle** | Right there, then. |

`where` shows the latest, e.g. `last seen 4 min ago: killed someone  [Chalman Keep]`. A sighting is
about this session and is not saved.

**Why not "travel to player"?** The game's own *Travel to Player* is offered only for friends, guild
members and group members -- the same people the rosters cover (`JumpToFriend`, `JumpToGuildMember`,
`JumpToGroupMember`, `JumpToGroupLeader`; the slash commands are the same four). There is no jump to
anybody else, so there is no hidden "where is this player" answer behind it. Travelling is also an
action, not a lookup: it would move you.

**For a player who is merely around**, the add-on tells you instead: when a registered player turns
up in the Cyrodiil **kill feed**, in a **fight** with you or your group, or **speaks or emotes near
you** (/say, /yell, emote), a band across the top of the screen says so and a sound plays. From the kill feed it also says where (the keep). It does not
point at them -- it says they are here. (`/pbtarget test` shows the band and plays the sound once.)

A player is identified by **any** of their three names: the `@account`, the console ID (PSN /
Xbox) or the character name. Case does not matter, the leading `@` is optional, and the
character's `^Fx` gender suffix is ignored. Type whichever you know.

## What it cannot do

**It cannot mark a player who is not under your reticle.** The call that sets a marker takes no
player, only "the reticle target", and nothing in the game's API lists the players around you or
reports that one has come into view. So each registered player is marked **the first time you
look at them**; after that the marker is the game's own, shown wherever the game shows target
markers. Whether it stays on the player while they are out of your sight is the game's behaviour,
not something this add-on controls. See [FINDINGS.md](FINDINGS.md).

It also cannot recolour or box the name floating above a character's head: that is drawn by the
game engine and the API has no setter for it.

The alert is the answer to the same limit: a player who is not in your group and not under your
reticle has no unit tag and no position, so the most an add-on can know is that they are around.

Limits that come from the game's marker:

- A marker type sits on **one player at a time**. One marker for every registered player means it
  moves to whichever of them you looked at last.
- A player who already carries somebody else's marker is left alone. A marker this add-on set
  earlier in the session is replaced when you change the mark.
- Deleting a player does not take the marker off them. Nothing in the API removes a marker from
  a player who is not under the reticle; the game clears it on its own.
- **The game's rules for who can be marked are not known here.** The client has an alert, "Not a
  valid target for target markers", for targets it refuses. `/pbtarget status` shows what the
  add-on saw.

### Only in Cyrodiil

Markers are set **only while you are in Cyrodiil**. Anywhere else -- a trial, a dungeon, where the group
leader has markers of his own -- the add-on sets none and clears none. It is asked again at the moment of
each request, not when the reticle lands, because you can zone out in the quarter second between the two.

- "In Cyrodiil" is `IsInCyrodiil()`. The **Imperial City does not count** (the game says no there), and a
  **Battleground is excluded** by its own test, because the documentation does not say what `IsInCyrodiil`
  returns inside one. If the client cannot answer, the answer is no.
- Everything that does not write a marker carries on everywhere: sightings, the alert band and sound,
  `/pbtarget where`, the Cyrodiil-entry notice. `/pbtarget unmark` is your own act and is not limited.
- Switch: *Mark only in Cyrodiil* (on by default); `/pbtarget cyroonly on|off`. Off marks anywhere.
  `/pbtarget status` shows the switch, where the add-on thinks you are, and how many marks it skipped.

### Not marking the wrong person

The game's marker call names no player: the marker goes to whoever is under the reticle **when the game
acts**, not when the add-on asked. In a crowd those can differ -- most clearly when a marked player dies and
respawns elsewhere. The player falls with the reticle on them, the marker leaves them, and a naive add-on
(seeing a registered player with no marker) asks again; by the time the game acts the player has respawned
and the reticle is on a bystander who is then marked. So:

- **Nothing is set on a dead target**, nor on a registered player who died in the last ten seconds (the
  kill feed and the target's own death event both tell the add-on).
- **The marker is not set the instant the reticle lands.** The target must still be the same registered
  player a quarter of a second later, or the request is dropped.
- **A stray is taken off.** A marker of the kind the add-on sets, found on a player who is not registered,
  not in your group and not you, is cleared -- right after the add-on set one, and whenever the reticle meets
  such a player. Clearing asks for "no marker" (`TARGET_MARKER_TYPE_NONE`), which **has not been tried on a
  console**: if the marker is still there a second later, the add-on gives up clearing for the session and
  says so (`/pbtarget status`). Switch: *Remove stray markers*, `/pbtarget cleanup on|off`.
- **Markers that land on a group member are put right.** Group members have unit tags, so the add-on can see
  where its marker went without aiming at anyone. Within three seconds of asking for a marker it looks at the
  group: if one who is not registered carries it, it says so in chat -- who, how many milliseconds after the
  request, which player it was meant for, how far apart they stand -- and puts it right. If the reticle is still
  on the intended player it asks again, which moves the marker off the group member (a marker sits on one unit
  at a time); if the reticle has moved away it asks the moment you look at that player again, ignoring the
  three-second wait. One repair per request, then it gives up. A group member the add-on has just caught
  carrying its marker by mistake is also cleared if the reticle meets them, which an ordinary group member's
  marker never is (that is probably the leader's).
- **A longer wait when a group member stands close.** With a group member within about four metres of the
  target the add-on waits 0.6 s instead of 0.25 s before asking, since the reticle is more likely to slide
  onto them before the game acts.
- `/pbtarget unmark` takes the marker off whoever is under the reticle, whoever put it there, and reports what
  was there before and a second later.

If two people use this add-on in one group, give them **different marks**: whether markers are shared across a
group is not known here, and if they are, two people asking for the same marker move it between them.

### Never called blind

Whether an add-on may set a marker at all is not something the documentation can settle, and
calling a private function raises a UI error that `pcall` does not catch. So the add-on asks the
game first (`IsPrivateFunction` / `IsProtectedFunction`), once, and does not call if the answer
is no, or cannot be had. It then says why in chat and does nothing else. (1.1.0 drew an icon in
the frames instead in that case; 1.2.0 and later do not, so `/pbtarget status` is the first thing to read
if no marker appears: `game marker:` should say `allowed`.)

## Settings

Under **PB's TargetPlayer for AD Stalkers** (LibHarvensAddonSettings).

| Setting | Purpose |
| --- | --- |
| Mark chosen players | Master switch. Off stops marking; your list is kept. |
| Mark | Which of the eight markers is set on registered players. |
| Alert when a registered player turns up | The band and sound for kill-feed and combat events. |
| Alert sound | The sound with it. |
| Alert when a registered player enters Cyrodiil | Friends and guild members only. |
| Remove stray markers | Take the add-on's marker off a bystander it landed on. |
| Mark only in Cyrodiil | Set markers only in Cyrodiil (not the Imperial City, not Battlegrounds). Off: anywhere. |
| 1. ... 20. | One row per slot. Open it to type the **Player ID**, see the **Location**, or **Delete** the entry. Leaving the ID box empty deletes it too. |
| General | Say hello at login; delete every player (asks you to press twice). |

## Commands

| Command | Purpose |
| --- | --- |
| `/pbtarget` | List the commands. (`/pbtp` is the short form.) |
| `/pbtarget add <ID>` | Register a player in the first free slot. |
| `/pbtarget remove <ID or number>` | Delete an entry. |
| `/pbtarget mark <1-8>` | The marker set on registered players. |
| `/pbtarget list` | Show the registered players. |
| `/pbtarget on` / `off` | Master switch. `alert`, `sound`, `cyrodiil`, `cleanup`, `cyroonly` and `banner` take `on` / `off` the same way. |
| `/pbtarget where` | Where each registered player is now (friends and guild members). |
| `/pbtarget unmark` | Take the marker off whoever is under the reticle; reports before and after. |
| `/pbtarget test` | Show the alert once, with the sound. |
| `/pbtarget status` | The game's answer about the marker call, how many times it was made, what happened at the last contact, and what is under the reticle right now. |
| `/pbtarget clear` | Delete every player. |

## How it works

One handler on `EVENT_RETICLE_TARGET_CHANGED`. When the reticle lands on a registered player and rests
there for a quarter of a second, it calls `AssignTargetMarkerToReticleTarget` -- once per contact, never
from a repeating timer, because setting the same marker on the same unit again may toggle it off. A player
who already carries the marker is skipped, a dead one is skipped, and the same player is not marked again
within three seconds.

The marker path writes to no control, hooks nothing and runs no timer. Hooking client code would make
every closure the client builds underneath it untrusted on console. The alert band is the add-on's own
control (`PBsTargetPlayer.xml`), shown through scene fragments the way PB's KillLog's window is, in a
font the console UI already has loaded; its one timer exists only while a message is up.

### Where they are, in detail

- **Sources:** `GetFriendInfo` / `GetFriendCharacterInfo` and `GetGuildMemberInfo` /
  `GetGuildMemberCharacterInfo` give the status, the character, the zone name and the zone id.
  A scan reads the friend list and every guild roster once, for every registered player together,
  and is kept for ten seconds so the settings panel can ask for one row at a time.
- **Matching:** by the roster's `@account`, then by character name (a second pass over the guilds,
  made only if a registered player has not been found by the first). A player registered by console
  ID is matched by the `@account` the add-on learned for them when the reticle was last on them.
- **Cyrodiil** is not a number in the code: the game is asked (`GetCyrodiilMapIndex` ->
  `GetMapInfoByIndex` -> `GetZoneId`). A roster entry is in Cyrodiil if its zone id is that zone or a
  zone inside it, or failing that if its zone name is Cyrodiil's.
- **Arrival:** `EVENT_FRIEND_CHARACTER_ZONE_CHANGED`, `EVENT_GUILD_MEMBER_CHARACTER_ZONE_CHANGED` and the
  two player-status events. Only the step from "not in Cyrodiil" to "in Cyrodiil" is announced, once per
  thirty seconds per player, so a player on both your friend list and a guild is one alert. A scan
  twenty seconds after login records who is already there, so they are not announced as arriving.

### The alert, in detail

- **Kill feed** (`EVENT_PVP_KILL_FEED_DEATH`): names the killer and the victim with the `@account`,
  the character name and the place. A player registered by `@account` matches here at once. The feed
  reports one kill twice; that is one alert (four-second cooldown per player).
- **Combat events** (`EVENT_COMBAT_EVENT`): character names only, and only for what involves you or
  your group; the engine is asked to deliver just the events where the source (or target) is another
  unit. Twenty-second cooldown per player, so a fight is one alert, not one per hit.
- Because combat events carry no `@account`, the add-on **learns each player's character name** the
  first time the reticle is on them or the kill feed names them (up to four per player, kept with the
  entry). Registering a character name directly needs no learning.
- **How far out these events reach is not known.** `/pbtarget status` counts what arrives (`seen:`),
  how many matched, and how many alerts were shown, so a console round can tell "nothing arrives"
  from "arrives but never matches".

## Upgrading from 1.1.0 and earlier

Versions up to 1.1.0 also coloured the name in the target and group frames, drew a box round it
and drew an icon of their own; those were removed. Registered players are kept; the colours,
the frame and box switches and the icon setting are discarded when the add-on loads.

## Layout rules that matter on console

- Folder name, manifest filename and `addon.name` must all match exactly (`PBsTargetPlayer`).
- PlayStation is case-sensitive.
- Console builds are distributed through **Bethesda.net**, not ESOUI -- use the ZOS Console
  AddOn Uploader. The name shown in the in-game browser comes from the uploader entry, not from
  `## Title`.

## Tests

```
lua test/run.lua
```

Runs the whole add-on against a stand-in client (units, the engine's markers and the question of
whether an add-on may set one, the kill feed and filtered combat events, saved variables, the settings
library). It cannot say what the
real console does; `/pbtarget status` is how that gets measured.

## Releasing

The displayed name is fixed in `Main.lua`; the version comes from the manifest. To cut a new
version, edit these two adjacent lines in `PBsTargetPlayer.addon` and nothing else:

```
## Title: |cFF69B4PB's TargetPlayer for AD Stalkers|r 1.7.0
## Version: 1.7.0
```

---

This Add-On is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
