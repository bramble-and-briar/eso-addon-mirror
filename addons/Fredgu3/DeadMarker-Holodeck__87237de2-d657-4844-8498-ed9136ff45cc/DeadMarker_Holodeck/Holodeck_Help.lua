--=====================================================================
-- Holodeck_Help.lua — /hd help card (own 200-local chunk).
-- Shown on the legend panel so console players are not stuck in chat.
--=====================================================================

Holodeck = Holodeck or {}

function Holodeck.HelpCardText()
    return table.concat({
        "|cAADDFFHOLODECK|r   v" .. tostring(Holodeck.version or ""),
        "Puts the fight on the house floor. Ghosts walk the log; you walk with them.",
        "",
        "|cFFFFFF1.|r  |cC0E0FF/hd plant|r     center at your feet, facing = camera",
        "|cFFFFFF2.|r  |cC0E0FF/hd list|r      then  |cC0E0FF/hd load 1|r",
        "|cFFFFFF3.|r  |cC0E0FF/hd play|r",
        "",
        "Wrong size or facing:",
        "  |cC0E0FF/hd scale 150|r     bigger  (100 = 1 file unit per meter, 25–400)",
        "Cyan ring = how far the boss walked, not the room wall.",
        "  |cC0E0FF/hd rot 90|r        turn it  (try 88 if 90 is a hair off)",
        "  |cC0E0FF/hd flip z|r        they orbit the wrong way",
        "",
        "|cC0E0FF/hd pause|r   |cC0E0FF/hd halt|r   |cC0E0FF/hd replay|r",
        "|cC0E0FF/hd names important|all|off|r",
        "|cC0E0FF/hdsettings|r",
        "",
        "|c888888/hd help|r again to close this.",
    }, "\n")
end
