---@meta TravelWheelTypes
-- TravelWheelTypes.lua: Centralized type definitions for TravelWheel

---@alias TravelWheelKind "node"|"house"|"campaign"|"activity"

---@class TravelWheelDestination One saved destination; one LibRadialMenu entry
---@field id string Stable entry id ("d0001"); LibRadialMenu stores it per wheel slot
---@field kind TravelWheelKind
---@field name string Shown on the wheel
---@field icon string
---@field nodeIndex integer|nil node: fast travel node (a wayshrine, a dungeon or trial entrance)
---@field houseId integer|nil house: 0 is the primary residence, read at travel time
---@field outside boolean|nil house: arrive at the front door (owned houses only)
---@field campaignId integer|nil campaign: 0 is the home campaign, read at travel time
---@field activityType integer|nil activity: LFGActivity of the finder entry
---@field activityId integer|nil activity: id of the finder entry
---@field isSet boolean|nil activity: the id is an activity set (a random queue)

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
---@field owned boolean

---@class TravelWheelCampaign
---@field campaignId integer
---@field name string
---@field imperialCity boolean

---@class TravelWheelActivity
---@field activityType integer
---@field activityId integer
---@field isSet boolean
---@field name string

---@class TravelWheelNodeFacts What the game reports when a wayshrine trip is asked for
---@field dead boolean
---@field canLeave boolean The game allows travel out of where the player stands
---@field known boolean The node is discovered on this character
---@field cost integer Recall fee in gold
---@field gold integer Gold carried

---@alias TravelWheelQueueKind "campaign"|"battleground"|"dungeon"

---@alias TravelWheelLocation "battleground"|"campaign"|"dungeon"|"house"|"world"

---@class TravelWheelLocationFacts What the game reports about where the player stands
---@field inBattleground boolean
---@field inAvAWorld boolean Cyrodiil or the Imperial City
---@field campaignId integer The campaign the player stands in; 0 outside one
---@field houseId integer 0 outside a house
---@field houseOwner string Display name of the house's owner; "" outside a house or in a preview
---@field inGroupInstance boolean A dungeon, trial or arena instance

---@class TravelWheelPlace The last arrival, kept to know what an instance was entered from
---@field location TravelWheelLocation
---@field campaignId integer

---@class TravelWheelOrigin Where the player stood before the instance, when the game does not put him back there itself
---@field kind "house"|"campaign"
---@field houseId integer|nil house
---@field owner string|nil house
---@field campaignId integer|nil campaign: left for a battleground or dungeon

---@class TravelWheelReturnTarget Where the trip after an instance goes
---@field kind "house"|"campaign"|"destination"
---@field name string
---@field toHouse boolean The trip is house travel (the game gates it separately from wayshrine travel)
---@field houseId integer|nil house
---@field owner string|nil house
---@field campaignId integer|nil campaign
---@field id string|nil destination: its saved id

---@class TravelWheelPendingReturn A trip after an instance that has been asked for and has not left the zone yet
---@field target TravelWheelReturnTarget
---@field requests integer Travel requests made so far
---@field maxRequests integer
---@field announce boolean Tell the player on screen when the trip is given up
---@field fromScoreboard boolean Asked for inside a finished battleground: given up, the battleground is left instead
---@field seq integer Bumped on every scheduled follow-up; a timer acts only on the seq it was given

---@class TravelWheelSavedVars
---@field destinations TravelWheelDestination[]
---@field nextId integer
---@field afterInstance string "off", "house" (the house the player left), or a destination id
---@field fromScoreboard boolean Leave a battleground by itself when its match ends
---@field requeueCampaign boolean Join the campaign's queue again after a battleground or dungeon entered from it
---@field accept table<TravelWheelQueueKind, integer> Per kind of queue: seconds to wait before accepting a ready one; -1 never, 9999 the last moment

---@class TravelWheelState
---@field savedVars TravelWheelSavedVars
---@field returnCampaigns table<integer, boolean> Campaigns queued to bring the player back; their queue is accepted at once
---@field pendingAccepts table<string, table> Ready prompts being waited on or already dealt with, by prompt
---@field armed boolean The player has been in an instance and has not yet landed outside one
---@field origin TravelWheelOrigin|nil
---@field lastPlace TravelWheelPlace|nil
---@field pendingReturn TravelWheelPendingReturn|nil
