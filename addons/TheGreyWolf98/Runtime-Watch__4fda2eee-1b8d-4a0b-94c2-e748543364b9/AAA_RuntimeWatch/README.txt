RUNTIME WATCH 0.1.0 — XBOX TEST BUILD
By @TheGreyWolf98

WHAT IT DOES
A standalone controller page for short native script-profiler captures. It ranks captured exclusive CPU time by add-on source folder and function, provides a saved baseline comparison, and records supporting load-event intervals, Lua errors, restricted-API messages, FPS samples and timer gaps.
No external libraries. No add-on disabling, callback replacement, forced garbage collection or automatic network/chat sending. Normal use is quiet after the one-shot capture finishes.

UPLOAD
Upload AAA_RuntimeWatch/AAA_RuntimeWatch.addon with the Bethesda uploader.
The early-sorting internal folder is intentional, but alphabetical names do not guarantee the actual load order. Keep the folder and manifest names together. Capture starts at Runtime Watch's own initialization; anything earlier is outside coverage.

FIRST USE
1. Enable Runtime Watch on the character you want to investigate and reload the UI or log in. Its first enable arms one startup capture automatically.
2. Let the capture finish. It stops three seconds after player activation, after 12 seconds from capture start, or at 600 profiler frames, whichever comes first. Long loading screens may outlast that window. Analysis then runs in small batches.
3. Open /runtime or /diag. The Add-on CPU page shows the largest captured script users. Functions shows file names and line numbers. Read the mode indicator: NATIVE CPU means actual profiler records; LIMITED means per-add-on CPU is unavailable.
4. Photograph the Add-on CPU page and the busiest function details if you want help interpreting them. No external viewer is required.

TESTING LAZY WRIT OR ANOTHER SUSPECT
Use the same character and a matching activity each time; different characters can have different crafting knowledge, inventory and saved data.
- Capture startup with your healthy add-on selection. Press Y to save that completed report as the baseline.
- Press X to arm the next login/reload. Change ONE suspected add-on in ESO's own add-on settings, then reload or relog.
- After the new report finishes, use Baseline comparison. Rates are milliseconds of captured script CPU per elapsed second. The different capture lengths and startup coverage still matter.
- Look at both the add-on and its libraries. Native/ESO helper time is assigned to a traceable calling add-on; library source code remains separate.
Do not treat a single run as proof. Repeat with the same settings/activity to check whether the change is consistent.

MANUAL CAPTURES
A starts a five-second capture now. Close the panel with B and reproduce the hitch, open a crafting station or perform the activity you want to inspect. /runtime stop ends a capture early. Closing the panel does not cancel recording.
/runtime start — five-second capture
/runtime stop — stop and analyze
/runtime arm — toggle one capture for the next login/reload; it does not reload automatically
/runtime baseline — save the most recent completed report
/runtime or /diag — open the page

CONTROLLER
LB/RB switches Add-on CPU, Functions, Baseline comparison, Load intervals, Errors and Help. D-pad selects rows; LT/RT pages. A captures, X arms the next login, Y saves a baseline, left-stick click opens Socials, B returns/closes.
The report and baseline are retained account-wide on the same server. Startup arming is consumed after one attempt, so it does not record every login indefinitely.

HOW TO READ THE NUMBERS
CPU is derived from ESO's native nanosecond script records, converted to milliseconds. For each completed record, direct child durations are subtracted before aggregation, avoiding nested double-counting. Libraries keep their own bucket. Native and ESO helper calls inherit a traceable calling add-on. Untraceable engine work stays ESO / unattributed. The Runtime Watch bucket is diagnostic overhead.
Function Calls means profiler function records, not update-loop registration counts. Maximums are the largest exclusive function record, not the slowest rendered frame.
The comparison uses exclusive CPU per elapsed second; the FPS samples, server latency and 100ms timer gaps are supporting context, not direct add-on attribution. Rendering, loading screens, scheduling, the network and other scripts can affect them.
Load intervals are wall-clock gaps BEFORE named load events. The named add-on did not necessarily cause the gap. These startup intervals can predate a later manual capture. Never read them as a per-add-on CPU ranking.
Error text is local, bounded and shortened. It may show a failing function rather than the root cause. A timeout can abort before a useful completed timing record exists.

LIMITS AND XBOX AVAILABILITY
The native profiler APIs are documented by ESO. Their availability and behavior on a live Xbox build must be confirmed. Missing, blocked or unreadable APIs switch to a clearly labelled limited mode; timings are never invented. If another profiler is already active, Runtime Watch refuses to take over or stop it. Use one profiler at a time.
Profiling itself adds CPU and temporary memory overhead. Keep captures short and disable Runtime Watch after diagnosing if desired. A profiler-stop failure is shown explicitly; reload the UI before further captures if that occurs.
Analysis runs every 10ms with a soft 2ms / 300-operation limit. Individual native calls cannot be interrupted. Analysis considers at most 250,000 records, omits frames above 50,000 records, and discards an incomplete frame at the record cap. Such reports are labelled PARTIAL. Large excluded startup frames can hide the culprit; use another short, controlled capture rather than treating a partial report as a clean bill of health.
Only 128 add-on buckets and 80 function rows are retained for display, along with bounded errors, load intervals and inventory metadata. Function collection is limited to 1,000 distinct entries plus an aggregate overflow entry. Native profiler buffers are owned by the game; Runtime Watch does not force garbage collection. The saved report is a compact summary rather than a raw profiler dump.

VALIDATION
Local tests cover nested exclusive CPU attribution, library/native ownership, profiler conflicts, automatic stop, baseline retention, record/frame limits, unreadable/unsupported fallbacks, six-page navigation and social/back/close cleanup. These are mocked API tests, not live Xbox validation.

API REFERENCES
ESO UI documentation and source:
https://github.com/esoui/esoui
https://raw.githubusercontent.com/esoui/esoui/master/ESOUIDocumentation.txt
Profiler API: StartScriptProfiler, StopScriptProfiler, IsScriptProfilerEnabled, GetScriptProfilerNumFrames, GetScriptProfilerFrameNumRecords, GetScriptProfilerRecordInfo, GetScriptProfilerClosureInfo and GetScriptProfilerCFunctionInfo.
Original implementation; no third-party profiler code or libraries included.

SOCIALS
Ko-fi: https://ko-fi.com/thegreywolf98
Instagram: https://www.instagram.com/thegreywolf_98/
Discord: https://discord.gg/Fp9RSaeU8h
Support is optional; the add-on is free.
