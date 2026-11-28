TME Horizon 0.2.1 | Camera Laboratory | PS5 experimental
Requires LibHarvensAddonSettings. Disable other automatic camera addons while testing.
This is NOT a proven extended zoom addon. The native slider experiments from 0.1.2
remain available but are reset to OFF on upgrade. Reset any experimental values
manually through native Camera settings before testing. No SetSetting writes.

TEST ORDER (flat open terrain, stationary, same facing, out of combat)
1. Add-Ons > TME Horizon > API availability; close menus. Screenshot report.
2. Zoom to normal maximum using controller. Capture native max; close menus.
3. Zoom in x1 (calibration); close menus. Check whether range actually decreases.
4. Zoom out x1; close menus. Check whether range increases back to native max.
5. At native max, Zoom out x12; close menus. Screenshot result. This is 12
   separate calls spaced 250 ms apart, not 12x camera distance.
6. Try Framing distance factor x2, Third-person preview, Interface FOV +15%
   individually. Temporary tests auto-restore after 2 seconds (4 seconds for framing) or on interruption.
   These may alter UI framing only. Normal zoom tests leave zoom changed;
   restore with native controller input. Do not move during samples.
7. Compare with native max captures current range against saved baseline;
   useful after manual native slider experiments. Keep the same facing/stance.
8. Cancel test / hide report when done. Disable addon if any unexpected camera
   behavior persists; reload UI and restore camera manually.

Report is visible in gameplay only. Each action waits 1.5 s after menu closure.
Range uses Set3DRenderSpaceToCurrentCamera, Get3DRenderSpaceOrigin and player raw
world position converted into render space. It is a camera-to-player-origin
estimate (includes height), not the internal zoom scalar. Validate using the
calibration steps. Horizontal FOV is inferred from the depth-1 frustum width;
this may represent UI projection rather than actual gameplay FOV. Settings
readback is not proof of rendered changes. N/A means unavailable, not zero.
The report refuses range comparisons if player moved >25 raw units or changed
zone. Keep camera angle, stance and terrain unchanged. Runtime private/protected
or unknown permission functions are skipped. Gamepad zoom down/up and SetSetting
are never called. No automated protected API bypass. No persistent framing override.
Framing experiments reset factor to native nil and framing off; use in normal HUD
only, not interaction scenes. No network access or telemetry.

NEW: Reciprocal framing tests 0.5 and 0.25. Test 0.5 first, in open terrain.
Framing reports capture baseline, active frame after four seconds, and restored
frame after another three seconds. The inverse relationship is a hypothesis,
not a guarantee of additional range. All existing permissions checks remain.
