-- ErrorCatcherTypes.lua: central type definitions

---@class ErrorCatcherFrame One frame of a stack trace
---@field source string Path as the trace prints it; "[C]" for a C function
---@field file string Last path segment of source
---@field line number|nil
---@field fn string Function name as the trace prints it; "anonymous" when it has none
---@field addon string|nil Add-on folder the source lies in; nil for the game's own files

---@class ErrorCatcherHookRecord One ZO_PreHook / ZO_PostHook (or Handler variant) call made by an add-on
---@field addon string
---@field kind string "ZO_PreHook" | "ZO_PostHook" | "ZO_PreHookHandler" | "ZO_PostHookHandler"
---@field target table|nil The table hooked, kept until it is named; nil once named
---@field targetName string|nil
---@field fnName string

---@class ErrorCatcherScan
---@field running boolean
---@field done boolean
---@field force boolean List everything even when nothing changed since the last UI load
---@field globalsRead boolean The pass over the globals reached its end
---@field functions string[] Untrusted global game functions
---@field members string[] Untrusted function members of game tables ("TABLE.Member")
---@field tableNames string[] Tables still to read
---@field tables table[] Parallel to tableNames
---@field next number Index of the next table to read

---@class ErrorCatcherSavedVars
---@field lastScanDigest string Digest of the last scan listed in full

---@class ErrorCatcherCounters
---@field errors number
---@field dialogs number
---@field hooks number
---@field untrustedButtons number

---@class ErrorCatcherState
---@field savedVars ErrorCatcherSavedVars
---@field trustApi boolean IsTrustedFunction can be called
---@field checkedCallbacks table<function, boolean> Button callbacks already judged (weak keys)
---@field poolConfirmed boolean A dialog button was seen trusted this UI load
---@field loggedKeys table<string, boolean> Lines written once this UI load
---@field loggedCount number
---@field hooks ErrorCatcherHookRecord[] Hook calls seen before the summary
---@field hooksSummarized boolean
---@field tableNames table<table, string> Global name of a game table (weak keys)
---@field scan ErrorCatcherScan
---@field counters ErrorCatcherCounters
