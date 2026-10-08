-- DevSandbox3Types.lua: annotations only

---@class DevSandbox3Node                 a located harvest node (from a compass pin)
---@field control userdata                the engine's compass pin control
---@field x number                        HarvestMap world frame metres (= raw world cm / 100), horizontal axis 1
---@field z number                        horizontal axis 2
---@field samplesX number[]               while locating
---@field samplesZ number[]
---@field pinTypeId integer|nil           HarvestMap pin type once named by the reticle

---@class DevSandbox3Slot                  a known spawn location (from HarvestMap-Data)
---@field x number                        HarvestMap world frame metres
---@field z number
---@field h number                        height metres
---@field pinTypeId integer

---@class DevSandbox3Color
---@field r number
---@field g number
---@field b number
---@field a number

---@class DevSandbox3Settings
---@field markWarTorte boolean
---@field markPsijic boolean
---@field dotSizeCm integer                apparent size at 10 m
---@field farScalePct integer              size at farScaleM as % of near size (100 = no shrink)
---@field farScaleM integer
---@field outline boolean                  black ring behind each dot
---@field cyrodiilOnly boolean             nothing is loaded, judged or drawn outside Cyrodiil (default on)
---@field unknownM integer                 unknown starts here (closer = confirmed empty)
---@field unknownLimitM integer            unknown dots not drawn beyond this
---@field checkedM integer                 coming within this distance marks a slot checked
---@field checkedMin integer               minutes checkpoints and verdicts are remembered; 0 = until cleared
---@field checkedColor DevSandbox3Color
---@field warTorteColor DevSandbox3Color
---@field psijicColor DevSandbox3Color
---@field markUnknown boolean
---@field unknownColor DevSandbox3Color
---@field debugNodes boolean
---@field debug boolean

---@class DevSandbox3State
---@field savedVars { settings: DevSandbox3Settings, checkpoints: table<integer, table<integer, number>>, verdicts: table<integer, table<integer, { e: integer, x: number }>> }
