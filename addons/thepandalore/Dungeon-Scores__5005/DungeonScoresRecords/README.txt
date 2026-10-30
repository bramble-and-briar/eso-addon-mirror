Dungeon Scores Records 0.5.15-data (optional PC beta)
===================================================

INSTALL
Extract the DungeonScoresRecords folder directly into:
    Documents/Elder Scrolls Online/live/AddOns/

The bundled Records.lua and Delivery.lua start empty. They show captured
community records and local submission status after the separately installed
companion runs. Reload the ESO UI to see later file updates in-game.
Dungeon Scores continues to score locally without this folder.

AI-assisted development was reviewed and is maintained by @thepandalore.
The companion control-panel concept was inspired by Tamriel Trade Centre
by cyxui; no Tamriel Trade Centre code or assets are bundled.

To enable record refresh and manual score sending, open Companion inside this
folder and run the installer matching your operating system:
    Windows: Install-DungeonScores-Windows.cmd
    macOS:   Install-DungeonScores-macOS.command
    Linux:   Install-DungeonScores-Linux.sh

The free Microsoft .NET 8 runtime is required. Installing or loading an ESO
addon cannot start a desktop program; run this installer once yourself.
The installer opens local Companion controls in your browser. To reopen them,
run the matching Open-Controls file in Companion. Start and Stop control the
current watcher, "Start at login" controls future sign-ins, and Sync processes
the most recently saved ESO data.
Afterward, press Send selected score in ESO for each score you choose to
publish. ESO must save its addon data before the companion can send it;
logout, quit, or /reloadui performs that save.

Companion/README.txt explains setup and startup controls. Companion/PRIVACY.txt
details local file access, public account names, and correction requests.
Complete C# source is in Companion/Source.

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media
Inc. or its affiliates. The Elder Scrolls® and related logos are registered
trademarks or trademarks of ZeniMax Media Inc. in the United States and/or
other countries. All rights reserved.
