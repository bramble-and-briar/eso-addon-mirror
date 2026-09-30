Ardy's OB Tracker  v1.4.0
=========================

INSTALL
  Copy the whole "ArdysOBTracker" folder into:
    Documents\Elder Scrolls Online\live\AddOns\
  Then enable "Ardy's OB Tracker" in the in-game Add-Ons menu (or /reloadui).
  Requires LibAddonMenu-2.0 (Minion installs it automatically). Settings are in
  Settings > Add-Ons > Ardy's OB Tracker.

WHAT IT DOES
  Markers  - When the enemy under your crosshair is Off Balance from YOU and within
             8 m, it gets the next free target marker (1-8). Look at it again after
             Off Balance ends and the marker is removed. If all markers are in use,
             expired ones are reassigned (this moves them off the old enemy).
             Your crosshair must hold on the enemy briefly (300 ms by default)
             before it is marked. Friendlies are never marked on purpose; if lag
             puts one of this add-on's markers on a friendly, it is moved to your
             next target or removed when you look at them.
  Tracker  - A small window lists every enemy you have put Off Balance with a
             countdown. When Off Balance ends, the row turns grey and counts down
             their 15 s Off Balance Immunity. Drag it where you want, then /obt lock.
             Change the text size with /obt size <12-36> or the settings slider.
