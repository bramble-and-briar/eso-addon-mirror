-- The active companion's native rapport replaces a simulated stranger profile.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local S=R.Speechcraft
local D=B.Dice
local C={};B.CompanionTrust=C
local function clamp(n) return math.max(0,math.min(100,n)) end
local function key(name) return B.Normalize(B.Name(name or '')) end
local levels={
 {'RAPPORT_LEVEL_MAXIMUM_DISLIKE',5},{'RAPPORT_LEVEL_HIGH_DISLIKE',15},
 {'RAPPORT_LEVEL_SLIGHT_DISLIKE',30},{'RAPPORT_LEVEL_SLIGHT_AFFINITY',50},
 {'RAPPORT_LEVEL_MODERATE_AFFINITY',65},{'RAPPORT_LEVEL_HIGH_AFFINITY',80},
 {'RAPPORT_LEVEL_VERY_HIGH_AFFINITY',90},{'RAPPORT_LEVEL_MAXIMUM_AFFINITY',100},
}
function C.Info(npc)
 if not npc or type(GetActiveCompanionDefId)~='function' or type(GetCompanionName)~='function' then return end
 local id=GetActiveCompanionDefId()
 if type(id)~='number' or id<=0 then return end
 local name,other=key(GetCompanionName(id)),key(npc.name)
 if name=='' or other=='' or name~=other then return end
 local level=type(GetActiveCompanionRapportLevel)=='function' and GetActiveCompanionRapportLevel() or nil
 for _,row in ipairs(levels) do
  if _G[row[1]]~=nil and level==_G[row[1]] then return {id=id,trust=row[2],level=level} end
 end
 if type(GetActiveCompanionRapport)~='function' or type(GetMinimumRapport)~='function' or type(GetMaximumRapport)~='function' then return end
 local value,low,high=GetActiveCompanionRapport(),GetMinimumRapport(),GetMaximumRapport()
 if type(value)~='number' or type(low)~='number' or type(high)~='number' or low>=0 or high<=0 then return end
 local trust=value<0 and 50+50*value/(-low) or 50+50*value/high
 return {id=id,trust=math.floor(clamp(trust)+.5),level=level}
end
local report=S.Report
function S.Report(npc)
 local info=C.Info(npc);local old=report(npc)
 if not info then return old end
 local out={};for k,v in pairs(old) do out[k]=v end
 out.cap=100;out.activeHelp=0;out.companionRapport=info.trust;out.stubborn=false
 out.contextInfo={recognition=0}
 return out
end
local threshold=S.Threshold
function S.Threshold(subject)
 if B.npc and C.Info(B.npc) then return clamp(S.Config().threshold) end
 return threshold(subject)
end
local state=S.State
function S.State(npc)
 local info=C.Info(npc)
 if not info then return state(npc) end
 local saved=S.Saved();saved.companions122=saved.companions122 or {}
 local own=saved.companions122[info.id]
 if not own then
  local previous=state(npc)
  own={};for k,v in pairs(previous) do own[k]=v end
  own.legacyCompanionTrust122=previous.trust;own.trust=info.trust
  own.nativeCompanionRapport122=info.trust
  saved.companions122[info.id]=own
 end
 own.trust=clamp(own.trust+info.trust-own.nativeCompanionRapport122)
 own.nativeCompanionRapport122=info.trust
 return own,S.Report(npc)
end
local current=S.Current
function S.Current(npc)
 if C.Info(npc) then return S.State(npc).trust end
 return current(npc)
end
local canPersuade=S.CanPersuade
function S.CanPersuade(npc)
 if C.Info(npc) then return S.Enabled() and S.Current(npc)<100 end
 return canPersuade(npc)
end
local limited=P.Limited
function P.Limited(npc)
 if C.Info(npc) then return false end
 return limited(npc)
end
local speechLimited=S.Limited
function S.Limited(npc)
 if C.Info(npc) then return false end
 return speechLimited(npc)
end
local confidence=B.Confidence
function B.Confidence(npc)
 local info=C.Info(npc)
 return info and info.trust or confidence(npc)
end
local difficulty=D.Difficulty
function D.Difficulty(npc)
 local info=C.Info(npc)
 if not info then return difficulty(npc) end
 if B.saved.speechcraftEnabled==false or B.saved.trustEnabled==false then return 12,50 end
 local trust=info.trust
 return trust<20 and 18 or trust<40 and 15 or trust<60 and 12 or trust<80 and 9 or 6,trust
end
local function manner(trust)
 return trust>=80 and 'cooperatif' or trust>=60 and 'amical' or trust>=40 and 'distant' or trust>=20 and 'mefiant' or 'hostile'
end
local behaviour=P.Behaviour
function P.Behaviour(npc)
 local info=C.Info(npc)
 if info then return manner(S.Enabled() and S.Current(npc) or info.trust) end
 return behaviour(npc)
end
local speechBehaviour=S.Behaviour
function S.Behaviour(npc)
 if C.Info(npc) then return manner(S.Current(npc)) end
 return speechBehaviour(npc)
end
local decision=S.Decision
function S.Decision(npc,subject,current,details)
 if C.Info(npc) then
  -- Rapport decides willingness, never supplies missing geographical knowledge.
  return current>=S.Threshold(subject) and 'truth' or 'refuse'
 end
 return decision(npc,subject,current,details)
end
local debug=S.Debug
function S.Debug(npc)
 local info=C.Info(npc)
 if not info then return debug(npc) end
 local description=type(GetActiveCompanionRapportLevelDescription)=='function' and info.level and GetActiveCompanionRapportLevelDescription(info.level) or ''
 return 'Relation réelle du compagnon : '..info.trust..'/100\n\n'..(description or '')..'\n\nConfiance actuelle : '..S.Current(npc)..'/100\nLes gains de persuasion restent propres au mod ; ils ne modifient pas la relation du jeu.'
end
