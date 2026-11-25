Reef Guardian Helper
====================

Helper for the Dreadsail Reef trial (hard mode).

First boss (Lylanar and Turlassil)
----------------------------------
Small window with the health of both bosses and marks at 80 % and 20 %.
Only visible while both bosses are present.

Second boss (Reef Guardian)
---------------------------
  - Health and status of all 5 guardians (Large, Medium 1, Medium 2, Small 1, Small 2),
    guardians that have not spawned yet are shown as "Soon"
  - Mark at 80 %, bar turns orange from 85 % until the guardian has charged
  - Status: Replication, CHARGE (countdown to reef), Acid Reflux, Reef placed, dead
  - Reef square: remaining time of the open reef (60 s), then 10 s vulnerability (green)
  - Kill lock: "DON'T KILL" / "KILL OK" until Medium 2 has placed its reef
  - Center alerts on the platform: "STOP DAMAGE" (Large / Medium 1 below 10 % while
    Medium 2 has no reef yet) and "KILL THE GUARDIANS" (Medium 2 reef is up)
  - Center alert inside a reef: "REEF n: KILL THE HEART"; in the reef of Medium 2
    "REEF 3: WAIT" while Large or Medium 1 is alive, at the latest after 35 s "KILL"

The add-on only displays information. It does not perform any actions in game.

Dependencies
------------
None.

Installation
------------
Copy the folder "ReefGuardianHelper" to
  Documents\Elder Scrolls Online\live\AddOns\
and enable it in game under "Add-Ons".

Commands
--------
  /rgh                   help
  /rgh test              test sequence with 15 scenes
  /rgh test <nr>         show one scene for 20 s
  /rgh test twins        show the first boss window for 20 s
  /rgh test reef         show the reef alert (WAIT, then KILL)
  /rgh reefwait <s>      reef of Medium 2: "KILL" at the latest after <s> seconds (default 35)
  /rgh unlock | lock     move / lock both windows
  /rgh alert all|dd|off  center alerts for everyone / DDs only / off (default: everyone)
  /rgh stop <pct>        threshold for "STOP DAMAGE" (default 10 %)
  /rgh killlock          toggle kill lock display
  /rgh debug             print detected casts and assignments to chat
  /rgh reset             reset window positions

Credits
-------
The height values used to detect whether you are inside a reef come from
"Qcell's Dreadsail Reef Helper" by Qcell.

AI disclosure
-------------
The code of this add-on was written with the help of an AI assistant (Claude by Anthropic).

Author: Ratpack X

Disclaimer
----------
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls(R) and related logos are registered trademarks or trademarks
of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
