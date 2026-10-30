# Tamriel Text Studio 2.3.6

ESO console-oriented message composer by CRY.

## Version 2.3.6
- **Output handoff:** selecting **QUEUE OUTPUT FOR SELECT / COPY** saves the generated markup and waits for the normal HUD scene to return. It then requests ESO's console chat text-entry API with the markup prefilled. The player must back out without sending chat after copying.
- **Color picker:** uses LibHarvensAddonSettings' documented RGB callback, persists the selected target color, accepts normalized or byte-range channels, and avoids rebuilding the settings panel inside the picker callback.
- Image-size presets and custom sizing from 8–256 px are retained; default size is 32 px.

## Important platform limitation
ESO add-ons cannot write directly to the PS5 system clipboard. The output workflow uses ESO's native console text-entry UI; selection/copy options are controlled by the PS5/ESO interface. This release has been syntax-checked and unit-tested against the add-on's handoff/color logic, but it has **not** been run on a physical PS5, so a 100% live-console guarantee would be dishonest.

## Install
Install the ZIP with its included `TamrielTextStudio/` folder. It contains exactly one `.addon` manifest. If the output button is selected in Add-ons settings, back out to the normal HUD so the queued keyboard request can run.
