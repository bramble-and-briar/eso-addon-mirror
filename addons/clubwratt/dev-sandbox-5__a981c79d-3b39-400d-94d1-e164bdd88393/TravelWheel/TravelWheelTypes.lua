---@meta TravelWheelTypes
-- TravelWheelTypes.lua: Centralized type definitions for TravelWheel

---@alias TravelWheelKind "node"|"house"|"campaign"|"activity"|"unstuck"

---@class TravelWheelDestination One saved destination; one LibRadialMenu entry
---@field id string Stable entry id ("d0001"); LibRadialMenu stores it per wheel slot
---@field kind TravelWheelKind
---@field name string Shown on the wheel; the player may change it
---@field icon string Shown on the wheel; the player may change it
---@field defaultName string The name the addon gave it
---@field defaultIcon string The icon the addon gave it
---@field nodeIndex integer|nil node: fast travel node (a wayshrine, a dungeon or trial entrance)
---@field houseId integer|nil house: 0 is the primary residence, read at travel time
---@field outside boolean|nil house: arrive at the front door (owned houses only)
---@field queues table<integer, boolean>|nil activity: by the finder's set id, false for a queue the entry leaves out; every other is joined
---@field owner string|nil house: display name of the other player who owns it (a House Tours favorite); nil for the player's own house
---@field campaignId integer|nil campaign: 0 is the home campaign, read at travel time

---@class TravelWheelNode
---@field nodeIndex integer
---@field name string
---@field icon string
---@field zoneId integer

---@class TravelWheelZone
---@field zoneId integer
---@field name string

---@class TravelWheelHouse
---@field houseId integer
---@field name string
---@field icon string
---@field owner string|nil Display name of the other player who owns it: a House Tours favorite
---@field ownerName string|nil favorite: the owner's name as the game shows it
---@field nickname string|nil favorite: the owner's name for the house
---@field tags string|nil favorite: the listing's tags, comma separated; "" for none
---@field furnitureCount integer|nil favorite: furnishings placed, when the listing says

---@class TravelWheelCampaign
---@field campaignId integer
---@field name string
---@field imperialCity boolean

---@class TravelWheelQueue A battleground queue the Activity Finder offers
---@field setId integer The finder's activity set
---@field name string
---@field gameTypes string The game types it draws from, comma separated; "" when the game lists none
---@field locked boolean The game will not let the player join it now
---@field lockReason string The game's reason; "" when not locked

---@class TravelWheelNodeFacts What the game reports when a wayshrine trip is asked for
---@field dead boolean
---@field canLeave boolean The game allows travel out of where the player stands
---@field known boolean The node is discovered on this character
---@field cost integer Recall fee in gold
---@field gold integer Gold carried

---@alias TravelWheelQueueKind "campaign"|"battleground"|"dungeon"

---@class TravelWheelSavedVars
---@field destinations TravelWheelDestination[]
---@field nextId integer
---@field accept table<TravelWheelQueueKind, integer> Per kind of queue: seconds to wait before accepting a ready one; -1 never, 9999 the last moment

---@class TravelWheelState
---@field savedVars TravelWheelSavedVars
---@field pendingAccepts table<string, table> Ready prompts being waited on or already dealt with, by prompt
---@field unstuckAsked boolean The game's Get Me Unstuck prompt was opened from the wheel and the game has not begun it yet
