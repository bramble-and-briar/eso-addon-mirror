-- Current native justice state only: a settled debt is not a six-hour crime memory.
-- Load after CommunityReputationFR.lua and CompanionTrustFR.lua.
local R=RolePlayMod
local B=IHR_Runtime.Beta
local P=B.Personality
local S=R.Speechcraft
local D=B.Dice
local C={version=1};B.CrimeState=C
local function number(v) return math.max(0,tonumber(v) or 0) end
local function call(name,...)
    local fn=_G[name]
    if type(fn)~='function' then return end
    local ok,a,b=pcall(fn,...)
    if ok then return a,b end
end
function C.Read()
    local heat,bounty=call('GetPlayerInfamyData')
    local rawBounty=call('GetBounty')
    local payoff=call('GetFullBountyPayoffAmount')
    if type(payoff)~='number' then payoff=rawBounty end
    if type(payoff)~='number' then payoff=bounty end
    local legal=call('IsJusticeEnabled')~=false
    local zone=call('GetUnitZoneIndex','player')
    if call('IsJusticeEnabledForZone',zone)==false then legal=false end
    local state={legal=legal,gold=number(payoff),heat=number(heat),kill=call('IsKillOnSight')==true,
        nativeBounty=math.max(number(bounty),number(rawBounty))}
    state.tier=state.kill and 9 or state.gold>=1000 and 6 or state.gold>=100 and 4 or state.gold>0 and 2 or 0
    -- Justice notifications may precede the other getters by a frame. A
    -- remaining native bounty still prevents a false "debt settled" transition.
    if state.nativeBounty>0 then state.tier=math.max(2,state.tier) end
    if state.heat>0 then state.tier=math.max(6,state.tier) end
    return state
end
local function people()
    return B.saved and B.saved.personality160 and B.saved.personality160.people or {}
end
local function speechPeople()
    return R.saved and R.saved.speechcraftV1 and R.saved.speechcraftV1.people or {}
end
local function clearRefusals(tier,legacy)
    local rolls=B.saved and B.saved.diceV1 and B.saved.diceV1.rolls or {}
    for key,result in pairs(rolls) do
        -- Successful information and learned hints are never removed.
        if type(result)=='table' and not result.success and
            ((result.crimeTier and result.crimeTier>tier) or legacy) then rolls[key]=nil end
    end
    for _,state in pairs(people()) do
        if state.daily and ((state.daily.crimeTier and state.daily.crimeTier>tier) or legacy) then state.daily=nil end
    end
    for _,state in pairs(speechPeople()) do
        if (state.answerCrimeTier and state.answerCrimeTier>tier) or legacy then
            state.answerExpires=nil;state.answerTrust=nil;state.answerCrimeTier=nil
        end
    end
end
function C.Poll()
    local nextState=C.Read()
    if C.polling then return nextState end
    C.polling=true
    if B.saved and not B.saved.crimeCurrentState1 then
        -- Old saves lack a cause on refusals. Repair them once only when there
        -- is evidence of the retired criminal-memory system and no current debt.
        local oldMemory=B.saved.socialCrime and next(B.saved.socialCrime)~=nil
        if oldMemory and nextState.tier==0 then clearRefusals(0,true) end
        B.saved.socialCrime=nil
        B.saved.crimeCurrentState1=true
    end
    local old=C.snapshot
    if not old or old.tier~=nextState.tier or old.legal~=nextState.legal then
        clearRefusals(nextState.tier,false)
        if S.InvalidateSocialReport then S.InvalidateSocialReport() end
    end
    C.snapshot=nextState;C.polling=false
    return nextState
end
function B.JusticeState() return C.Poll() end
function B.ObserveJustice() return C.Poll() end
function B.CrimePenalty(npc)
    if C.ignorePenalty or not B.saved or B.saved.crimeInfluence==false then return 0,'' end
    local role=B.Normalize(npc and npc.caption or '')
    if role:find('receleur',1,true) or role:find('fence',1,true) then return 0,'' end
    local state=C.Poll()
    if not state.legal or state.tier==0 then return 0,'' end
    local label=state.kill and 'À vue par la garde' or state.heat>0 and 'Poursuivi par la garde' or 'Prime en cours'
    return -state.tier,label
end
-- A stale caller may still request the old "crime" greeting. Re-evaluate it.
local dialogue=B.DialogueLine
function B.DialogueLine(kind,npc)
    local state=C.Poll()
    if kind=='crime' and (not state.legal or B.CrimePenalty(npc or B.npc)==0) then kind='greeting' end
    return dialogue(kind,npc)
end
local roll=D.Roll
function D.Roll(subject,npc)
    local state=C.Poll()
    local result,err,cached=roll(subject,npc)
    if result and (not cached or result.crimeTier==nil and not result.success) then
        result.crimeTier=B.CrimePenalty(npc)<0 and state.tier or 0
    end
    local profile=npc and P.Profile(npc)
    local own=profile and people()[profile.id]
    if own and own.daily and B.CrimePenalty(npc)<0 then own.daily.crimeTier=state.tier end
    return result,err,cached
end
local finish=P.FinishAttempt
function P.FinishAttempt(subject,result,npc)
    local native=C.Poll()
    local out=finish(subject,result,npc)
    if result and B.CrimePenalty(npc)<0 then
        local profile=npc and P.Profile(npc)
        local own=profile and people()[profile.id]
        if own and own.daily then own.daily.crimeTier=native.tier end
        if result.speechcraft and result.refused then
            local speech=profile and speechPeople()[profile.id]
            if speech and speech.answerExpires then speech.answerCrimeTier=native.tier end
        end
    end
    return out
end
local report=S.Report
local function cleanCap(details)
    -- All terms remain identical, except the explicitly separated crime term.
    local before=tonumber(details.before)
    local crime=tonumber(details.crime) or 0
    if not before or crime>=0 then return details.cap end
    return math.max(details.cap,math.max(0,math.min(100,math.floor(math.min(
        math.max(before-crime,details.cooperationFloor or 0),details.hardCap or 100)))))
end
function S.Report(npc)
    C.Poll()
    local details=report(npc)
    local protection=C.protectedState
    if not protection or protection.npc~=npc then return details end
    -- The inner state writers must retain newly earned aid/community points
    -- until this outer wrapper can separate them from the temporary crime cap.
    local copy={};for key,value in pairs(details) do copy[key]=value end
    copy.cap=cleanCap(details)
    return copy
end
local firstTrust=S.FirstTrust
function S.FirstTrust(npc,profile)
    local ordinary=firstTrust(npc,profile)
    local protection=C.protectedState
    if not protection or protection.npc~=npc then return ordinary end
    local previous=C.ignorePenalty;C.ignorePenalty=true
    local ok,clean=pcall(firstTrust,npc,profile)
    C.ignorePenalty=previous
    if not ok then error(clean) end
    protection.initialReduction=math.max(0,number(clean)-number(ordinary))
    return clean
end
local state=S.State
function S.State(npc)
    C.Poll()
    if B.CompanionTrust and B.CompanionTrust.Info(npc) then return state(npc) end
    local profile=P.Profile(npc)
    local previous=speechPeople()[profile.id]
    local held=previous and number(previous.crimeHeldTrust) or 0
    local details=S.Report(npc)
    local penalty=B.CrimePenalty(npc)
    -- Release only when the ceiling improves. Repeated reads cannot heal a
    -- real loss played on the wheel while wanted.
    if previous and held>0 then
        local room=penalty==0 and held or math.max(0,details.cap-(previous.crimeLastCap or details.cap))
        local release=math.min(held,room,math.max(0,cleanCap(details)-number(previous.trust)))
        previous.trust=number(previous.trust)+release;held=held-release
    end
    local outerProtection=C.protectedState
    local protection=penalty<0 and {npc=npc} or nil
    C.protectedState=protection
    local ok,own=pcall(state,npc)
    C.protectedState=outerProtection
    if not ok then error(own) end
    local actual=S.Report(npc)
    if penalty<0 then
        local initial=math.min(number(own.trust),protection.initialReduction or 0)
        own.trust=number(own.trust)-initial;held=held+initial
        local withheld=math.max(0,own.trust-actual.cap)
        own.trust=math.min(own.trust,actual.cap)
        held=math.min(held+withheld,math.max(0,cleanCap(actual)-own.trust))
    end
    own.crimeHeldTrust=penalty<0 and held or nil
    own.crimeLastCap=penalty<0 and actual.cap or nil
    return own,actual
end
-- Recheck before quota checks and before opening a fresh conversation.
for _,name in ipairs({'Limited','CanAsk'}) do
    local original=P[name]
    P[name]=function(...) C.Poll();return original(...) end
end
for _,name in ipairs({'Open','ShowHome'}) do
    local original=B[name]
    if type(original)=='function' then B[name]=function(...) C.Poll();return original(...) end end
end
local ask=D.Ask
if type(ask)=='function' then function D.Ask(...) C.Poll();return ask(...) end end
local function changed() C.Poll() end
for _,name in ipairs({'EVENT_JUSTICE_BOUNTY_PAYOFF_AMOUNT_UPDATED','EVENT_JUSTICE_INFAMY_UPDATED',
    'EVENT_JUSTICE_GOLD_REMOVED','EVENT_JUSTICE_NOW_KOS','EVENT_JUSTICE_NO_LONGER_KOS',
    'EVENT_JUSTICE_BEING_ARRESTED','EVENT_PLAYER_DEAD','EVENT_PLAYER_ACTIVATED'}) do
    local event=_G[name]
    if event~=nil then EVENT_MANAGER:RegisterForEvent('RPMCurrentCrime'..name,event,changed) end
end
-- Death/arrest never clears the addon's state by assumption: only the getters
-- can report that the remaining bounty, heat and KOS status have ended.
EVENT_MANAGER:RegisterForUpdate('RPMCurrentCrimeWatch',1000,changed)
