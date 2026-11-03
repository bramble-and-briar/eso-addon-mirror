Tamriel Collections - Archive Furnishing Plans
Version: 0.1.5
Author: MajesticMinxi

Loading-speed update based on the confirmed working v0.1.4 family list.
Catalogue preparation uses up to 32 entries per step with the existing
one-millisecond elapsed-time check, or eight entries when no clock is available.
No acquisition database is shipped or loaded. Recipes are read in small batches
only after explicitly opening Furnishing Plans. Focusing the category shows a
placeholder and does not access crafting data. No player-login scan is added.

Middle panel: furnishing families inferred from native names. Unmatched items
use their native recipe category under General. Right panel: individual plans.
X moves into the plans; Circle returns. L3 switches between missing-only and
all plans, including completed families. Families sort by fewest missing first.
Triangle searches names. Acquisition sources and the location chooser are
pending a separate build; source details are marked unverified.

The counter uses the same native recipe entries as the v0.1.3 diagnostic.
It does not declare every exposed recipe currently obtainable. Results are
specific to the character. No recipe result links or furniture metadata APIs
are queried in this build.

Testing: fully restart ESO after updating. First confirm login and normal play.
Then open Collections -> Furnishing Plans and wait for families to appear.
Compare the L3 total with the diagnostic, toggle Show all twice, use X/Circle,
and check another Collections module. Keep v0.1.2 as the recovery fallback.
Desktop simulations cannot guarantee PS5 stability.
