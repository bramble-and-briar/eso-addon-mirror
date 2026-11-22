# Teleport

One chat command, `/tp`, for every kind of travel in ESO. Type the start of where you want to go and you're on your way, without clicking through the map, the friends list or the guild roster.

```
/tp deshaan        a zone, free, through anyone you know who is there
/tp vka            Kyne's Aegis on veteran
/tp maps           your next survey or treasure map
/tp @fren snug     a friend's house
```

Teleport always takes the free option when there is one. It jumps to a group member, friend or guildmate first and only pays for a wayshrine when it has to. When a teleport costs gold, the price is shown in chat. Like any teleport, it is cancelled if you move or use a skill before the loading screen.

There is no window and no settings menu, only the command. If you prefer clicking, have a look at [BeamMeUp](https://www.esoui.com/downloads/info2143-BeamMeUp-TeleporterFastTravel.html) or [Traveller](https://www.esoui.com/downloads/info1744-Traveller-FastTravelRedesigned.html); Teleport borrows a few ideas from both.

## How names are matched

- Names are not case-sensitive.
- Type the **start** of the name: `desh`, `DES` and `deshaan` all mean Deshaan.
- If several names start with what you typed, the alphabetically first one wins: `/tp gr` is *Grahtwood*, not *Greenshade*. Type a little more, or make an [alias](#aliases), for the others.
- "The" can be left out: `/tp reach` is *The Reach*, `/tp dread cellar` is *The Dread Cellar*.

What you type is checked against these lists, in this order:

1. your own [aliases](#aliases)
2. the commands: `--help`, `--aliases`, `--add`, `--remove`, `--list`, `leader`, `maps…`, `quest…`
3. `@` names: players and their houses
4. [dungeon, trial and arena short names](#dungeon-trial-and-arena-aliases) (exact match)
5. names: zones, dungeons/trials/arenas, your houses, wayshrines

While the wayshrine menu is open, step 5 goes the other way round (wayshrines, dungeons, houses, zones), since that's where you are most likely going, and travel from a wayshrine is free.

You can only travel to wayshrines, dungeons and houses that the current character has discovered or owns. A jump to a player or to someone's house works anywhere.

`/tp --help` prints a short list of examples in chat.

## Zones

```
/tp deshaan
/tp crag
/tp weald          West Weald
```

Teleport jumps to someone in your group, friends list or guilds who is in that zone. If nobody is there, it tells you so; zone travel never costs gold. Sub-zones such as Fargrave count too.

## Dungeons, trials and arenas

```
/tp fg1            Fungal Grotto I
/tp ka             Kyne's Aegis
/tp crypt of h     Crypt of Hearts I
```

Every instance has short names made from the first letters of its name (Kyne's Aegis → `ka`, White-Gold Tower → `wgt`), plus a few common community abbreviations. Short names must be typed in full: `hr` does not mean `hrc`. `/tp --aliases` lists them all in game, and the tables [at the end of this page](#dungeon-trial-and-arena-aliases) do the same.

Put **n**, **v** or **r** in front of a short name to set the difficulty first:

```
/tp vhrc           veteran Hel Ra Citadel
/tp ndsa           normal Dragonstar Arena
/tp rbrp           reset the instance, then travel
```

Only the group leader can change the difficulty, and the game's usual rules apply. If something blocks it, Teleport shows the game's own reason. If a group member is inside a dungeon, `n`/`v` won't change the difficulty, because that would kick them out; change it yourself in the group menu if you really want to. A reset switches the difficulty to the other one and back (normal → veteran → normal), which gives the group a fresh instance.

If a group member is already inside, Teleport jumps to them for free. Otherwise it travels to the entrance, paying unless you're at a wayshrine.

## Wayshrines

```
/tp vivec city
/tp solitude wayshrine
```

The " Wayshrine" at the end of the name is optional and ignored when sorting, so `/tp solitude` is *Solitude Wayshrine*, not *Solitude Docks Wayshrine*. Adding "wayshrine" to the name helps when a zone or dungeon would match first. Wayshrine travel costs gold unless you're standing at one.

## Your houses

```
/tp snugpod
/tp outside snugpod
```

`outside` takes you to the house's front door instead of inside. A house you don't own opens in preview mode.

## Players

```
/tp @fren          the first group member, friend or guildmate whose account name starts with "fren"
/tp leader         your group leader
```

Players are searched by account name (with `@`), not by character name: group members first, then friends, then guildmates. ESO only lets you jump to people in your group, friends list or guilds.

`/tp leader` does the same as the game's `/jumptoleader`, but shorter, and it says in chat where the leader is.

## Other players' houses

```
/tp @fren snug             fren's Snugpod
/tp @fren primary          fren's primary residence (also: main)
/tp @@exactname snugpod    anyone's house, exact account name required
```

For people you know, the first word is the start of their account name and the rest is the start of the house name. For anyone else, use `@@` and their full account name. Account names are not case-sensitive.

Feel free to visit `/tp @@schrodingerscatgirl snugpod`.

## Survey and treasure maps

```
/tp maps           free if possible, paid otherwise
/tp maps free      only free options: players, then your houses
/tp maps paid      the closest wayshrine or house of yours
```

Teleport looks through your bags and takes you to your next map:

- Maps in your current zone come first, so you don't sit through a zone-to-zone loading screen while there's still something to dig up nearby.
- Then the zone you have the most maps for.
- Free options win over paying for a wayshrine. First a jump to a player in any of those zones. If there's nobody, the outside of a house you own close to a map (jumping outside your own house is free from anywhere). Only then a paid wayshrine.
- At a wayshrine, travel is free anyway, so it takes whichever wayshrine or house of yours is closest to a map.
- If you're already closer to a map than any wayshrine or house of yours is (by at least ~150 m), you won't be teleported; Teleport tells you how far away the map is instead.

Wayshrines and houses need **LibTreasure** to know where the maps are. Tip: make an alias, e.g. `/tp --add s maps`, then just `/tp s`.

## Tracked quest

```
/tp quest
/tp quest free
/tp quest paid
```

Same rules as maps, for the quest you're tracking. All of its open objective markers are considered (quests with several markers, "talk to A or B", delves, quest endings), and you end up at the wayshrine closest to any of them. The world map is never opened.

## Aliases

Anything you can type after `/tp` can be saved under a shorter name:

```
/tp --add s maps
/tp --add home @@myaccount primary
/tp --add hof vhof
/tp --list
/tp --remove s
```

- Alias names are a single word and not case-sensitive.
- An alias must match exactly; it is not a prefix.
- Aliases are checked before anything else, so you can even replace a built-in short name.
- They are saved account-wide.

## Requirements

- Optional: **LibTreasure**, for paid travel to survey and treasure maps.
- Optional: **LibGPS**, for exact distances to maps and quest objectives. Without it the distances are estimates.

## Known issues

- Now and then a jump fails with "No suitable location found to jump to". This happens when the player you're jumping to has just changed zones and the game still has them in the old one. Wait a few seconds and try again.
- Resetting an instance or changing difficulty depends on the server answering in time and occasionally doesn't go through. Teleport retries once and then gives up after a few seconds instead of sending you in on the wrong difficulty; just run the command again.

## Changelog

See [changelog.md](changelog.md).

## Maintenance

The game provides all zone, dungeon, wayshrine and house names, so new content works without an update. Only the hand-picked short names in `Aliases.lua` might need attention when a new instance gets a popular abbreviation that the generated one doesn't cover.

The tables below are generated from `Aliases.lua` and `tools/instances.txt`. After changing either, run `make` (needs Lua 5.1 or LuaJIT). For a new instance, add its name to `tools/instances.txt`.

## Dungeon, trial and arena aliases

Put **n**, **v** or **r** in front of any of these for normal, veteran or reset. In game, `/tp --aliases` shows the list that is actually in effect.

<!--splitter-->

### Trials

[https://en.uesp.net/wiki/Online:Trials](https://en.uesp.net/wiki/Online:Trials)

| Name | Aliases |
|-|-|
| Aetherian Archive | `aa` |
| Hel Ra Citadel | `hrc` |
| Sanctum Ophidia | `so` |
| Maw of Lorkhaj | `mol` |
| Halls of Fabrication | `hof` |
| Asylum Sanctorium | `as` |
| Cloudrest | `cr` |
| Sunspire | `ss` |
| Kyne's Aegis | `ka` |
| Rockgrove | `rg` |
| Dreadsail Reef | `dr`, `dsr` |
| Sanity's Edge | `se` |
| Lucent Citadel | `lc` |
| Ossein Cage | `oc` |

### Arenas

[https://en.uesp.net/wiki/Online:Arenas](https://en.uesp.net/wiki/Online:Arenas)

| Name | Aliases |
|-|-|
| Dragonstar Arena | `da`, `dsa` |
| Maelstrom Arena | `ma` |
| Blackrose Prison | `bp`, `brp` |
| Vateshran Hollows | `vh` |
| Infinite Archive | `ia` |

### Base game dungeons

[https://en.uesp.net/wiki/Online:Group_Dungeons](https://en.uesp.net/wiki/Online:Group_Dungeons)

| Name | Aliases |
|-|-|
| Arx Corinium | `ac` |
| Blackheart Haven | `bh` |
| Blessed Crucible | `bc` |
| City of Ash I | `coa`, `coa1` |
| City of Ash II | `coa2` |
| Crypt of Hearts I | `coh`, `coh1` |
| Crypt of Hearts II | `coh2` |
| Darkshade Caverns I | `dc1` |
| Darkshade Caverns II | `dc2` |
| Direfrost Keep | `dk` |
| Elden Hollow I | `eh`, `eh1` |
| Elden Hollow II | `eh2` |
| Fungal Grotto I | `fg`, `fg1` |
| Fungal Grotto II | `fg2` |
| Selene's Web | `sw` |
| Spindleclutch I | `s1`, `sc`, `sc1` |
| Spindleclutch II | `s2`, `sc2` |
| Tempest Island | `ti` |
| The Banished Cells I | `bc1`, `tbc`, `tbc1` |
| The Banished Cells II | `bc2`, `tbc2` |
| Vaults of Madness | `vom` |
| Volenfell | `vf` |
| Wayrest Sewers I | `ws`, `ws1` |
| Wayrest Sewers II | `ws2` |

### DLC dungeons

[https://en.uesp.net/wiki/Online:Group_Dungeons](https://en.uesp.net/wiki/Online:Group_Dungeons)

| Name | Aliases |
|-|-|
| Imperial City Prison | `icp` |
| White-Gold Tower | `wgt` |
| Cradle of Shadows | `cos` |
| Ruins of Mazzatun | `rom` |
| Bloodroot Forge | `bf`, `brf` |
| Falkreath Hold | `fh` |
| Fang Lair | `fl` |
| Scalecaller Peak | `sp`, `scp` |
| March of Sacrifices | `mos` |
| Moon Hunter Keep | `mk`, `mhk` |
| Depths of Malatar | `dom` |
| Frostvault | `fv` |
| Lair of Maarselok | `lom` |
| Moongrave Fane | `mf`, `mgf` |
| Icereach | `ir` |
| Unhallowed Grave | `ug` |
| Castle Thorn | `ct` |
| Stone Garden | `sg` |
| Black Drake Villa | `bdv` |
| The Cauldron | `cd`, `tc` |
| Red Petal Bastion | `rpb` |
| The Dread Cellar | `dc`, `tdc` |
| Coral Aerie | `ca` |
| Shipwright's Regret | `sr` |
| Earthen Root Enclave | `ere` |
| Graven Deep | `gd` |
| Bal Sunnar | `bs` |
| Scrivener's Hall | `sh` |
| Oathsworn Pit | `op` |
| Bedlam Veil | `bv` |
| Exiled Redoubt | `er` |
| Lep Seclusa | `ls` |
| Naj-Caldeesh | `nc` |
| Black Gem Foundry | `bgf` |

### Zone short names

Zones starting with "The " or a "Something: " label also work without it (The Reach → Reach, Blackreach: Greymoor Caverns → Greymoor Caverns). Additionally:

| Short name | Zone |
|-|-|
| Elsweyr | Northern Elsweyr |
| Skyrim | Western Skyrim |
| Weald | West Weald |
