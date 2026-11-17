---@meta HomeAfterPvPTypes
-- HomeAfterPvPTypes.lua: Centralized type definitions for HomeAfterPvP

---@class HomeAfterPvPSavedVars
---@field enabled boolean Travel home when PvP returns the player to the main world
---@field fromScoreboard boolean Start the trip from the battleground scoreboard where the game allows it

---@alias HomeAfterPvPLocation "pvp"|"house"|"dungeon"|"world"

---@class HomeAfterPvPLocationFacts What the game reports about where the player stands
---@field inBattleground boolean
---@field inAvAWorld boolean Cyrodiil or the Imperial City
---@field houseId integer 0 outside a house
---@field inDungeon boolean

---@class HomeAfterPvPPendingTrip A trip home that has been asked for and has not left the zone yet
---@field houseId integer
---@field requests integer Travel requests sent so far
---@field maxRequests integer
---@field announce boolean Tell the player on screen when the trip starts or is given up
---@field seq integer Bumped on every scheduled follow-up; a timer acts only on the seq it was given

---@class HomeAfterPvPState
---@field savedVars HomeAfterPvPSavedVars
---@field armed boolean The player has been in a PvP world and has not yet landed outside one
---@field pending HomeAfterPvPPendingTrip|nil
