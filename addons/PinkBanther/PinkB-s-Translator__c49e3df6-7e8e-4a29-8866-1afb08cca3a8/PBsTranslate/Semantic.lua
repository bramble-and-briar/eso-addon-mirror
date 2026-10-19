-- English -> semantic frame -> Japanese. Only complete, high-confidence readings
-- are selected. The general grammar remains the fallback for unsupported clauses.
-- No cache, online services, persistent context, or copies of the large dictionary.
local T = PBsTranslate
local S = { MAX_ITEMS = 64, MIN_SCORE = 90, MARGIN = 5 }
T.Semantic = S
local BE = {am=true,is=true,are=true,was=true,were=true,be=true}
local PAST = {was=true,were=true,had=true,did=true}
local HAVE = {have=true,has=true,had=true}
local NEG = {['not']=true,never=true}
local TIME = {now=true,yet=true,already=true,still=true,today=true,yesterday=true,tomorrow=true,tonight=true}
local PLACE = {at='に',['in']='に',near='の近くに',behind='の後ろに',['in front of']='の前に'}
local RESOURCES = {['マジカ']=true,['スタミナ']=true,['体力']=true,['マナ']=true,['ポーション']=true,
 ['魂石']=true,['ゴールド']=true,['お金']=true,['アルティメット']=true}
local COMBATANTS = {['ヒーラー']=true,['タンク']=true,['敵']=true,['ボス']=true,['プレイヤー']=true,['仲間']=true}
local STRUCTURES = {['門']=true,['正門']=true,['裏門']=true,['扉']=true,['壁']=true,['内壁']=true,['外壁']=true}
local function word(items,i) return items[i] and items[i].w end
local function np(items,a,b)
 if a>b then return nil end
 local n=T.ReadNominal(items,a,b)
 if n and (n.head or n.pronoun) and not n.adjective and not n.gerund then return n end
end
local function clone(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function node(kind,score) return {kind=kind,score=score,form={},times={}} end
-- All tails must parse: a location, a temporal modifier, or nothing. No word is dropped.
local function tail(items,start,plan)
 local i=start
 while i<=#items do
  local w=word(items,i);local e=items[i].entry
  if TIME[w] and e and e.pos=='adv' then
   plan.times[#plan.times+1]=e.ja;i=i+1
  elseif e and e.pos=='adv' and e.place and not plan.location then
   plan.location=e.ja..'に';i=i+1
  elseif PLACE[w] and not plan.location then
   local last=#items
   while last>i and TIME[word(items,last)] do last=last-1 end
   local place=np(items,i+1,last)
   if not place or place.negative then return false end
   plan.location=place.ja..PLACE[w];i=last+1
  else return false end
 end
 return true
end
-- Read a subject plus be, preserving tense/negation. Subjectless reports are valid.
local function statePrefix(items,stop,plan)
 if stop==0 then return true end
 local i=stop
 if NEG[word(items,i)] then plan.form.negative=true;i=i-1 end
 if BE[word(items,i)] then
  plan.form.past=PAST[word(items,i)];i=i-1
  if i==0 then return false end
 end
 if i==0 then return false end
 local subject=np(items,1,i)
 if not subject or subject.negative then return false end
 plan.subject=subject
 return true
end
local function resource(items)
 local plans={}
 for i=1,#items do
  local w=word(items,i);local kind,start
  if w=='out of' then kind,start='depleted',i+1
  elseif (w=='low' or w=='short') and word(items,i+1)=='on' then kind,start='low',i+2 end
  if kind then
   local p=node(kind,98)
   if statePrefix(items,i-1,p) then
    local last=start
    while last<#items and not PLACE[word(items,last+1)] and not TIME[word(items,last+1)] do last=last+1 end
    local resource=np(items,start,last)
    if resource and resource.head and RESOURCES[resource.head.ja] and not resource.negative then
     p.entity=resource
     if tail(items,last+1,p) then plans[#plans+1]=p end
    end
   end
  end
 end
 return plans
end
local function remaining(items)
 local plans={}
 for i=2,#items do
  if word(items,i)=='left' then
   local p=node('remaining',96);local first=1
   if word(items,first)=='only' then p.only=true;first=first+1 end
   if word(items,first)=='there' and BE[word(items,first+1)] then
    p.explicit=true;p.form.past=PAST[word(items,first+1)];first=first+2
   else
    for j=first,i-1 do
     if HAVE[word(items,j)] then
      p.subject=np(items,first,j-1)
      if not p.subject or p.subject.negative then return plans end
      p.form.past=PAST[word(items,j)];p.explicit=true;first=j+1;break
     end
    end
   end
   local last=i-1
   if BE[word(items,last)] then p.form.past=PAST[word(items,last)];last=last-1 end
   local entity=np(items,first,last)
   if entity and (entity.countSuffix or entity.negative or p.explicit) then
    p.entity=entity;p.form.negative=entity.negative
    if tail(items,i+1,p) then plans[#plans+1]=p end
   end
  end
 end
 return plans
end
local function structuralState(items)
 local plans={}
 for i=2,#items do
  if BE[word(items,i)] then
   local p=node('structure',95);p.subject=np(items,1,i-1);p.form.past=PAST[word(items,i)]
   if not p.subject or not p.subject.head or not (STRUCTURES[p.subject.head.ja] or COMBATANTS[p.subject.head.ja]) then return plans end
   p.combatant=COMBATANTS[p.subject.head.ja]
   p.form.negative=p.subject.negative
   local j=i+1
   if NEG[word(items,j)] then p.form.negative=not p.form.negative;j=j+1 end
   if word(items,j)=='almost' then p.almost=true;j=j+1 end
   if word(items,j)=='down' then
    if tail(items,j+1,p) then plans[#plans+1]=p end
   end
   return plans
  end
 end
 return plans
end
local function recruitment(items)
 local plans={}
 for i=1,#items do
  if word(items,i)=='need' or word(items,i)=='needed' or word(items,i)=='needs' then
   local p=node('recruitment',94);local stop=i-1
   p.form.past=items[i].infl=='past'
   if NEG[word(items,stop)] then p.form.negative=true;stop=stop-1 end
   if word(items,stop)=='do' or word(items,stop)=='does' or word(items,stop)=='did' then
    p.form.past=p.form.past or PAST[word(items,stop)];stop=stop-1
   end
   if stop>0 then p.subject=np(items,1,stop);if not p.subject or p.subject.negative then return plans end end
   -- Explicit recipient of an action, not "need X for Y" or an embedded assertion.
   for j=i+2,#items-1 do
    if word(items,j)=='to' then
     local actorEnd=j-1;local actionIndex=j+1
     local actionNegative=word(items,actorEnd)=='not' or word(items,actionIndex)=='not'
     if word(items,actorEnd)=='not' then actorEnd=actorEnd-1 end
     if word(items,actionIndex)=='not' then actionIndex=actionIndex+1 end
     local actor=np(items,i+1,actorEnd);local action=items[actionIndex];local verb=action and T.As(action.entry,'v')
     if actor and not actor.negative and verb and not action.infl then
      local last=actionIndex
      while last<#items and not PLACE[word(items,last+1)] and not TIME[word(items,last+1)] do last=last+1 end
      local object=actionIndex+1<=last and np(items,actionIndex+1,last) or nil
      if actionIndex==last or object and not object.negative then
       local candidate=clone(p);candidate.times={}
       candidate.actor=actor;candidate.verb=verb;candidate.object=object;candidate.actionNegative=actionNegative
       if tail(items,last+1,candidate) then plans[#plans+1]=candidate end
      end
     end
    end
   end
   return plans
  end
 end
 return plans
end
local function embeddedLocation(items)
 local plans={};local first=1;local p=node('ask_location',97)
 local w=word(items,first)
 if w=='can' or w=='could' or w=='will' or w=='would' then
  local addressee=np(items,2,2)
  if not addressee or not ({you=true,someone=true,somebody=true,anyone=true,anybody=true})[addressee.pronoun] then return plans end
  p.addressee=addressee;p.request=true;first=3
 end
 if word(items,first)~='tell' then return plans end
 local recipient=np(items,first+1,first+1)
 if not recipient or not ({me=true,us=true})[recipient.pronoun] then return plans end
 p.recipient=recipient
 if word(items,first+2)~='where' then return plans end
 local last=#items
 if not BE[word(items,last)] then return plans end
 local target=np(items,first+3,last-1)
 if not target or target.negative then return plans end
 p.target=target;p.embeddedPast=PAST[word(items,last)]
 plans[1]=p;return plans
end
local function needEntity(items)
 local plans={}
 for i=1,#items do
  if word(items,i)=='need' or word(items,i)=='needs' or word(items,i)=='needed' then
   local p=node('need_entity',92);local stop=i-1
   p.form.past=items[i].infl=='past'
   if NEG[word(items,stop)] then p.form.negative=true;stop=stop-1 end
   if word(items,stop)=='do' or word(items,stop)=='does' or word(items,stop)=='did' then
    p.form.past=p.form.past or PAST[word(items,stop)];stop=stop-1
   end
   if stop>0 then p.subject=np(items,1,stop);if not p.subject or p.subject.negative then return plans end end
   local last=i+1
   while last<#items and not PLACE[word(items,last+1)] and not TIME[word(items,last+1)] do last=last+1 end
   local entity=np(items,i+1,last)
   if entity then
    p.entity=entity;p.form.negative=p.form.negative or entity.negative
    if tail(items,last+1,p) then plans[1]=p end
   end
   return plans
  end
 end
 return plans
end
local READERS={resource,remaining,structuralState,recruitment,embeddedLocation,needEntity}
function S.Analyze(items,options)
 if #items==0 or #items>S.MAX_ITEMS then return nil end
 -- User meanings are authoritative, including words inside a matched phrase.
 for _,item in ipairs(items) do
  if item.kind~='word' and item.kind~='num' then return nil end
  if T.userLexicon[item.w] or T.userLexicon[item.base] then return nil end
  for part in (item.w or ''):gmatch('%S+') do if T.userLexicon[part] then return nil end end
 end
 local best,runner
 for _,reader in ipairs(READERS) do
  for _,plan in ipairs(reader(items)) do
   if not (options and options.subordinate and plan.kind=='ask_location') then
   if not best or plan.score>best.score then runner=best;best=plan
   elseif not runner or plan.score>runner.score then runner=plan end
   end
  end
 end
 if not best or best.score<S.MIN_SCORE or runner and best.score-runner.score<S.MARGIN then return nil end
 return best
end
-- A missing comma is accepted only after a complete structured condition.
function S.FindBoundary(items)
 if #items>S.MAX_ITEMS then return nil end
 local boundary
 for i=3,#items do
  local token=items[i];local e=token.entry
  if e and e.pos=='v' and not token.infl and e.class~='i' and e.class~='na'
   and not T.userLexicon[token.w] and not e.ja:match('ている$') then
   local prefix={};for j=1,i-1 do prefix[j]=items[j] end
   local p=S.Analyze(prefix,{subordinate=true})
   if p and (p.kind=='depleted' or p.kind=='low' or p.kind=='remaining' or p.kind=='structure' or p.kind=='need_entity') then
    if boundary then return nil end
    boundary=i
   end
  end
 end
 return boundary
end
-- Quantity placement is generated from the parsed noun, never by replacing a
-- finished sentence (which might contain a player's custom text or an item link).
local COUNTERS = {
 ['DPS']='人', ['DD']='人', ['ヒーラー']='人', ['タンク']='人', ['プレイヤー']='人', ['仲間']='人', ['敵']='人',
 ['ポーション']='本', ['魂石']='個', ['破城槌']='台', ['バリスタ']='台', ['カタパルト']='台',
}
local function quantity(n)
 local counter=n.head and COUNTERS[n.head.ja]
 local count=n.countSuffix and n.countSuffix:match('^×(%d+)$')
 if not counter or not count or n.ja:sub(-#n.countSuffix)~=n.countSuffix then return n.ja end
 local noun=n.ja:sub(1,-#n.countSuffix-1)
 local more=noun:sub(1,#'あと')=='あと'
 if more then noun=noun:sub(#'あと'+1) end
 return noun,count..counter,more
end
function S.Render(p,options)
 options=options or {};local form=clone(p.form)
 for k,v in pairs(options.form or {}) do
  if k=='negative' then form.negative=not not (form.negative~=v) else form[k]=v end
 end
 if options.invertNegation then form.negative=not form.negative end
 local subject=p.subject and p.subject.ja or ''
 local omitSpeaker=p.subject and (p.subject.pronoun=='i' or p.subject.pronoun=='we' and (p.kind=='need_entity' or p.kind=='recruitment'))
  and not options.subordinate and not options.questionMark and not options.keepSubject
 local lead=subject~='' and (subject..(options.subordinate and 'が' or 'は')) or ''
 if omitSpeaker and (p.kind=='depleted' or p.kind=='low' or p.kind=='need_entity') then lead='' end
 local body
 if p.kind=='depleted' or p.kind=='low' then
  local pred=p.kind=='depleted' and {ja='尽きている',class='1'} or {ja='少ない',class='i'}
  if options.subordinate and subject~='' then lead=subject..'の' end
  local location=(p.location or ''):gsub('に$', 'で')
  body=table.concat(p.times)..location..lead..p.entity.ja..'が'..T.Predicate(pred,form)
 elseif p.kind=='remaining' then
  lead=subject~='' and subject..'には' or ''
  local negative=p.entity.negative
  local noun,count=quantity(p.entity)
  if count and not negative then
   if omitSpeaker then lead='' end
   local pred={ja='残っている',class='1'}
   local remaining=''
   if not form.negative and not p.only and not options.subordinate and T.IsAnimateEntry(p.entity.head) then
    pred={ja='いる',class='1'};remaining='あと'
   end
   body=lead..table.concat(p.times)..(p.location or '')..noun..'が'..remaining..count..(p.only and 'だけ' or '')..T.Predicate(pred,form)
  else
   body=lead..table.concat(p.times)..(p.location or '')..p.entity.ja..(p.only and 'だけ' or '')
    ..(negative and p.entity.pronoun and '' or negative and not p.subject and 'は' or 'が')..T.Predicate({ja='残っている',class='1'},form)
  end
 elseif p.kind=='structure' then
  local ja=p.combatant and (p.almost and '倒れそう' or '倒れている') or (p.almost and '破られそう' or '破られている')
  local pred={ja=ja,class=p.almost and 'na' or '1'}
  body=lead..table.concat(p.times)..(p.location or '')..T.Predicate(pred,form)
 elseif p.kind=='need_entity' then
  if options.subordinate and subject~='' then lead=subject..'に'
  elseif options.questionMark and p.subject and ({anyone=true,anybody=true,someone=true,somebody=true})[p.subject.pronoun] then lead=subject..'、' end
  local noun,count,more=quantity(p.entity)
  body=lead..table.concat(p.times)..(p.location or ''):gsub('に$', 'で')..noun..'が'
   ..(count and ((more and 'あと' or '')..count) or '')..T.Predicate({ja='必要',class='na'},form)
 elseif p.kind=='recruitment' then
  local action=(p.object and p.object.ja..(p.verb.particle or 'を') or '')..(p.actionNegative and T.PlainPredicate(p.verb,{negative=true})..'ようにして' or T.TeForm(p.verb.ja,p.verb.class))
  body=lead..p.actor.ja..'に'..table.concat(p.times)..(p.location or ''):gsub('に$', 'で')..action..'もらう必要'..(form.negative and 'は' or 'が')
   ..T.Predicate({ja='ある',class='5'},form)
  -- A present direct appeal from the speaker to "you" is a request in chat.
  -- Keep past necessity, questions, third parties and negated necessity explicit.
  if omitSpeaker and p.actor.pronoun=='you' and not form.negative and not form.past then
   local action=(p.object and p.object.ja..(p.verb.particle or 'を') or '')
    ..(p.actionNegative and T.PlainPredicate(p.verb,{negative=true})..'で' or T.TeForm(p.verb.ja,p.verb.class))
   body=table.concat(p.times)..(p.location or ''):gsub('に$', 'で')..action..'ほしいです'
  end
 end
 if p.kind=='ask_location' then
  local target=p.target
  local where=target.ja..'がどこに'..T.Predicate({ja=T.IsAnimateEntry(target.head) and 'いる' or 'ある',class=T.IsAnimateEntry(target.head) and '1' or '5'}, {past=p.embeddedPast,plain=true})..'か'
  local who=p.addressee and p.addressee.pronoun~='you' and p.addressee.ja..'、' or ''
  local to=p.recipient.pronoun=='us' and p.recipient.ja..'に' or ''
  body=who..to..where..(p.request and '教えてもらえます' or '教えてください')
 end
 local question=not options.subordinate and (p.request or options.questionMark)
 if question then body=body..'か' end
 return body,question
end
