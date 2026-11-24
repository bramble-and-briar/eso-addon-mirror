TMENexus={context="World",settingsGroups={},refreshWanted={},effectBuckets={}}
local N=TMENexus
function N.safe(f,...)
 if type(f)~="function" then return nil end
 local ok,a,b,c,d,e=pcall(f,...); if ok then return a,b,c,d,e end
end
function N.mode()
 local s=N.safe
 if s(IsActiveWorldBattleground) or s(IsInBattleground) then return "Battleground" end
 if s(IsInAvAZone) and not s(IsInImperialCity) then return "Cyrodiil" end
 if s(IsUnitInDungeon,"player") or s(IsUnitInGroupDungeon,"player") or s(IsInDungeon) then return "Dungeon" end
 return "World"
end
function N.gameplay()
 local scene=SCENE_MANAGER and SCENE_MANAGER:GetCurrentScene()
 local name=scene and scene:GetName()
 return not name or name:lower()=="hud" or name:lower()=="hudui" or name:lower()=="hudgamepad" or name:lower()=="huduigamepad"
end
local names={ESOFantasySettings="Battleground Rating",DungeonRatingSettings="Dungeon Buddy",GoldStandard_Options="Gold Standard",CyrodiilMercenaryPanel="Cyrodiil Mercenary"}
N.settingsProxy={}
function N.settingsProxy:RegisterAddonPanel(id,data) N.settingsGroups[id]=N.settingsGroups[id] or {}; N.settingsGroups[id].name=names[id] or data.name; return {} end
function N.settingsProxy:RegisterOptionControls(id,controls) N.settingsGroups[id]=N.settingsGroups[id] or {}; N.settingsGroups[id].controls=controls end
EVENT_MANAGER:RegisterForUpdate("NexusContext",200,function() N.context=N.mode() end)
