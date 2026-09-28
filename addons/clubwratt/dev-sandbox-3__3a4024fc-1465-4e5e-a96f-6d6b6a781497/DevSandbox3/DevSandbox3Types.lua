---@meta DevSandbox3Types
-- DevSandbox3Types.lua: Centralized type definitions for DevSandbox3

---@class DevSandbox3Node
---@field gx number Global (Tamriel-normalized) X from LibGPS
---@field gy number Global (Tamriel-normalized) Y from LibGPS
---@field name string Interactable name that was matched
---@field zoneId integer Zone id the node was recorded in
---@field firstSeen integer Unix timestamp of first sighting
---@field lastSeen integer Unix timestamp of latest sighting
---@field seenCount integer Number of times the node was sighted
---@field looted boolean True once the recipe was actually looted here
---@field candidate boolean True if recorded only because the harvest node name was unrecognized

---@class DevSandbox3SavedVars
---@field nodes DevSandbox3Node[]
---@field filters table LibMapPins filter state
---@field debug boolean Log every reticle target name (to discover exact node names)
---@field extraPatterns string[] Temporary extra name patterns for testing (/ds3 match)
---@field ignoredNames table<string, boolean> Lowercase harvest-node names to treat as ordinary materials (/ds3 ignore)
---@field recordUnknown boolean Record unrecognized harvest nodes as candidates (default false; testing)
---@field settings DevSandbox3Settings
---@field activeAlert DevSandbox3Alert|nil Persistent on-screen alert (survives reloadui until dismissed)
---@field coverage table<integer, table<string, boolean>> zoneId -> set of covered cell keys ("cx:cy")

---@class DevSandbox3Settings
---@field alertEnabled boolean
---@field alertFontSize integer
---@field alertAutoDismissSeconds integer 0 = never
---@field alertSound boolean
---@field alertOnCandidates boolean Also raise the big alert for unrecognized-node candidates (testing)
---@field showPlayerRadius boolean
---@field playerRadiusMeters integer
---@field trackCoverage boolean Record covered ground while riding
---@field showCoverage boolean Draw covered ground on the Cyrodiil map
---@field probeAllTypes boolean Also react to LOCATION/VENDOR/TRAINER/NPC_FOLLOWER compass pins (noisy, testing only)

---@class DevSandbox3Alert
---@field text string
---@field candidate boolean
---@field at integer timestamp

---@class DevSandbox3State
---@field savedVars DevSandbox3SavedVars
---@field pinTypeId integer|nil Numeric pin type id returned by LibMapPins
---@field candidatePinTypeId integer|nil Pin type id for unrecognized-node candidates
---@field lastReticleName string|nil Last interactable name seen on the reticle
---@field lastRecordTime integer Timestamp of the last node write (throttle)
