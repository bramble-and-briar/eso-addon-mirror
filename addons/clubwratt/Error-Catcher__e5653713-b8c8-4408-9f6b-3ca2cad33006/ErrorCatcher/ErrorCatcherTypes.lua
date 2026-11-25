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
---@field poolAtStart number|nil The add-on pool when the scan began, in MB
---@field ownMB number What the scan's own steps grew the Lua heap by, in MB
---@field stepHeap number|nil The Lua heap when the step under way began

---@class ErrorCatcherSavedVars
---@field scanDigests table<string, string> Digest of the last scan listed in full, by character id
---@field watchNames string[] The untrusted names of the last scan, followed on the next UI load
---@field session ErrorCatcherSessionRecord|nil The record of the UI load that last saved
---@field loadCount number|nil UI loads on record
---@field enabled ErrorCatcherEnabledRecord|nil The add-ons enabled on the UI load before
---@field loadOrder ErrorCatcherLoadOrder|nil The load order of the UI load before
---@field prioritySave boolean|nil false when "/ec save off" stopped the priority saves
---@field prioritySaveTrying boolean|nil Set while the priority save call is made; left set by a call that never returned

---@class ErrorCatcherMoment
---@field wall number Wall clock, seconds
---@field gameClock number Seconds since the game started

---@class ErrorCatcherSessionRecord One UI load as it stood at its last save
---@field loadNumber number
---@field version string
---@field character string
---@field zone string
---@field loadWall number Wall clock at this add-on's load event
---@field wall number Wall clock at the last change
---@field gameClock number
---@field age number Seconds since the UI load began
---@field used number|nil Add-on pool, MB
---@field capacity number|nil
---@field high number|nil Highest pool reading
---@field heap number|nil Lua heap, MB
---@field pinsActive number|nil
---@field pinsBuilt number|nil
---@field activatedWall number|nil When the world or a zone was last entered
---@field deactivatedWall number|nil When a zone was last left
---@field logoutWall number|nil When a logout was asked for
---@field logoutQuit boolean|nil
---@field reloadWall number|nil When ReloadUI was called
---@field savesStarted number Save data writes begun
---@field savesCompleted number

---@class ErrorCatcherEnabledRecord
---@field character string
---@field names string[]

---@class ErrorCatcherMemorySample One reading of the game
---@field used number Add-on pool, MB
---@field capacity number|nil
---@field heap number|nil Lua heap, MB
---@field pinsActive number|nil Map pins shown
---@field pinsBuilt number|nil Map pin controls built since the UI loaded
---@field wall number
---@field gameClock number
---@field age number Seconds since the UI load began
---@field zone string
---@field scene string
---@field rangeLow number Lowest pool reading of the last minute
---@field rangeHigh number

---@class ErrorCatcherMemoryRing The pool readings of the last minute
---@field values number[]
---@field next number

---@class ErrorCatcherMemoryMark What the last memory line written said
---@field high number The high growth is counted from
---@field used number|nil
---@field age number
---@field pinsBuilt number

---@class ErrorCatcherLoadCost What memory gained at one add-on's load event
---@field name string
---@field delta number MB, of the Lua heap when it can be read, else of the pool
---@field heap number|nil
---@field pool number

---@class ErrorCatcherDiskUse
---@field name string
---@field megabytes number

---@class ErrorCatcherMemory
---@field startClock number The game's clock when this UI load began
---@field atFileScope number|nil The pool before this add-on, MB
---@field heapAtFileScope number|nil The Lua heap before this add-on, MB
---@field loadPool number|nil The pool at the last load event
---@field loadHeap number|nil The Lua heap at the last load event
---@field byHeap boolean The per add-on figure is the Lua heap's
---@field byAddon ErrorCatcherLoadCost[]
---@field worldSeen boolean
---@field sample ErrorCatcherMemorySample
---@field ring ErrorCatcherMemoryRing
---@field rangeFull boolean
---@field mark ErrorCatcherMemoryMark
---@field lines number Memory lines written this UI load
---@field noticed table<number, boolean> Low memory warnings already written, by their figure

---@class ErrorCatcherSession
---@field record ErrorCatcherSessionRecord|nil This UI load's record, the table the saved variables hold
---@field saveAskedAt number|nil The game's clock at the last priority save request
---@field saveCallFailed boolean
---@field saveStartedAt number|nil The game's clock when a save data write began that has not completed
---@field slowSaves number
---@field saveErrors number
---@field forceDisabled string The force-disabled add-ons last written, joined

---@class ErrorCatcherWrapGroup Functions first seen untrusted at one moment of the load
---@field title string
---@field names string[]

---@class ErrorCatcherLoad
---@field after string[] Add-ons whose load event came after this one's, in order
---@field previous string|nil The add-on loaded last
---@field enabled string[]|nil Add-ons the game has enabled; nil when it gave no list
---@field pending string[] Followed names still trusted at the last check
---@field watched table<string, boolean> Every name followed on this UI load
---@field following boolean The last scan left names to follow
---@field groups ErrorCatcherWrapGroup[]
---@field listNumber table<string, number> An enabled add-on's number in the game's add-on list
---@field early table<string, boolean> Whether an add-on loaded after this one last time had its global at this add-on's own load event
---@field previousOrder ErrorCatcherLoadOrder|nil The load order of the UI load before

---@class ErrorCatcherLoadOrder Where this add-on stood in one UI load
---@field character string
---@field position number Its load event was the position-th
---@field total number Add-ons enabled
---@field after string[] Add-ons loaded after it, in order

---@class ErrorCatcherDialogShow The last dialog asked for
---@field name string
---@field summary string Who was on the stack and which hooks it went through

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
---@field load ErrorCatcherLoad
---@field memory ErrorCatcherMemory
---@field session ErrorCatcherSession
---@field wrappedBeforeLoad table<string, boolean> Followed game functions that read untrusted before this add-on hooked them
---@field hookersByFn table<string, string[]> Add-ons seen hooking a function, by the function's bare name
---@field lastDialogShow ErrorCatcherDialogShow|nil
---@field counters ErrorCatcherCounters
