Goliath Timer
=============

Shows every DD in your group who has Bone Goliath Transformation, Pummeling Goliath or
Ravenous Goliath slotted on the front or back bar.

  - Ultimate charging: the bar fills to the right until the ultimate cost is reached
    (text shows current / required points)
  - Ultimate ready:    full green bar, "READY"
  - Goliath active:    the bar counts the remaining duration down to the left
                       (purple, red-orange below 5 seconds)

Order: active Goliaths (shortest remaining time first) > ready > by charge progress.


Requirements
------------
Optional: LibGroupCombatStats (with its dependencies LibGroupBroadcast and LibCombat).

Without LibGroupCombatStats the add-on only shows players who are currently transformed.
Ultimate charge of other group members is only visible if they also run LibGroupCombatStats
(for example via Hodor Reflexes).


Data sharing
------------
To show ultimate charge, Goliath Timer registers with LibGroupCombatStats for ultimate data.
This makes your client share your own ultimate type, ultimate cost and ultimate points with
your group via LibGroupBroadcast. No other data is sent.


Commands
--------
  /gol unlock | lock  - move / lock window
  /gol test           - test display (fake entries)
  /gol own            - toggle own character
  /gol roles          - toggle all roles instead of DDs only
  /gol empty          - toggle hiding the window when empty
  /gol ults           - print group ultimate data to chat
  /gol debug          - log Goliath effects with ID to chat
  /gol addid <id>     - track additional ability ID
  /gol delid <id>     - remove additional ability ID
  /gol reset          - reset window position


Disclaimer
----------
This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates.
The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc.
in the United States and/or other countries. All rights reserved.

You can read the full terms at https://account.elderscrollsonline.com/add-on-terms

This add-on is free. No feature is sold or exchanged for gold, crowns or real money.
