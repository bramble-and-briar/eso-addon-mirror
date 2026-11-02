Jesus de Platre - Cyber Taunt Reticle 0.8.3 (experimental)

Replace the entire JesusDePlatre_PrivateMarker folder with this one.
Keeps the previous multi-enemy taunt tracker (/jdptaunt).

NEW: a true circular segmented reticle texture, not rectangular mockup brackets.
NEW: anchors to ESO's ZO_ReticleContainerReticle / RETICLE.reticleTexture, with
screen-center fallback if the native reticle isn't exposed.

Quick test:
 /jdpcross demo green
 /jdpcross probe
 /jdpcross demo off

Controls:
 /jdpcross anchor native       Follow ESO's native crosshair control (default)
 /jdpcross anchor screen       Use screen center fallback
 /jdpcross x 0 /jdpcross y 0  Fine-tune relative position
 /jdpcross size 124           Scale circular ring
 /jdpcross textpos left       Default status position
 /jdpcross textoffset 22      Change label spacing
 /jdpcross vanilla off        Hide original crosshair texture (if found)
 /jdpcross vanilla on         Restore original reticle
 /jdpcross shownotarget off   Hide overlay while not aiming at an enemy
 /jdpcross reset              Restore defaults
 /jdpcross off                Disable custom reticle

Green YOUR TAUNT, Blue OTHER TAUNT, Red NO TAUNT, Yellow UNKNOWN.
White-gray when there is no enemy.

Limitations: the concept rendering was more detailed than the real in-game
version; this uses a white DXT5 texture tinted by Lua. ESO may vary how the
reticle texture is positioned or its visibility. Please report /jdpcross probe.


v0.8.4 OPTIONAL IN-GAME GOLD DONATION
 /jdpdonate  Open an optional donation panel
 Or click Donate at the upper-right of the multi-taunt tracker.
 Recipient: @Evokation
 Clicking OPEN MAIL TO @Evokation opens ESO's mail composer when available.
 Pick any amount of gold in Mail; nothing is sent by the add-on.
 The player reviews and manually sends mail.
