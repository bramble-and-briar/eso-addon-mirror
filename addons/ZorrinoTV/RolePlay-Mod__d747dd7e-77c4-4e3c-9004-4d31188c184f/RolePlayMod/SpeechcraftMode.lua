if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local R=RolePlayMod
local B=IHR_Runtime.Beta
local D=B.Dice
local P=B.Personality
local S=R.Speechcraft
local W=S.Wheel
local diceLabel=D.InquiryLabel
function D.InquiryLabel(subject,text)
 if not S.Enabled() then return diceLabel(subject,text) end
 if not subject then return text end
 text=text:gsub(' |c%x%x%x%x%x%x%[DD %+%d+%]|r','')
 return text
end
local diceAsk=D.Ask
local confidence,attitude,behaviour,limited,canAsk,finish,enter=B.Confidence,B.Attitude,P.Behaviour,P.Limited,P.CanAsk,P.FinishAttempt,P.EnterConversation
function B.Confidence(npc) if S.Enabled() then return S.Current(npc) end;return confidence(npc) end
function P.Behaviour(npc) if S.Enabled() then return S.Behaviour(npc) end;return behaviour(npc) end
function P.Limited(npc) if S.Enabled() then return S.Limited(npc) end;return limited(npc) end
function P.CanAsk(npc,subject) if S.Enabled() then return not S.Limited(npc) end;return canAsk(npc,subject) end
function P.EnterConversation() if S.Enabled() then P.newConversation=false;return end;return enter() end
function P.FinishAttempt(subject,result,npc)
 if result and result.speechcraft then
  if result.refused and (result.socialBehaviour=='hostile' or result.socialBehaviour=='mefiant') then
   local state=S.State(npc);state.answerExpires=GetTimeStamp()+86400;state.answerTrust=state.trust
  end
  return
 end
 return finish(subject,result,npc)
end
function B.Attitude(npc)
 if not S.Enabled() then return attitude(npc) end
 return '' -- Numeric relationship information belongs exclusively to the wheel.
end
local show,close=B.Show,B.Close
function B.Show(title,text,choices,...)
 W.Hide()
 if S.Enabled() and title=='Conversation' and B.npc and S.CanPersuade(B.npc) then
  local next={};for _,choice in ipairs(choices or {}) do next[#next+1]=choice end
  table.insert(next,1,{text='Prenons un moment pour parler.',callback=function() S.pendingSubject=nil;W.Show() end});choices=next
 end
 return show(title,text,choices,...)
end
function B.Close(...) W.Hide();S.pendingSubject=nil;return close(...) end
function D.Ask(subject)
 if not S.Enabled() then return diceAsk(subject) end
 if not B.npc then return end
 local key=subject and (subject.kind=='rumor' and 'rumors' or subject.kind=='service' and 'services' or 'questions')
 if not key or not R.Enabled(key) then return B.ShowHome() end
 subject=D.RefreshSubject(subject)
 if not subject then return B.ShowHome() end
 if S.Limited(B.npc) then return B.Show('Conversation',B.DialogueLine('daily'),{}) end
 local current=S.Current(B.npc);local required=S.Threshold(subject);local report=S.Report(B.npc)
 if current<required then
  S.pendingSubject=subject
  local choices={}
  if report.cap>=required then choices[#choices+1]={text='Prenons le temps de discuter.',callback=W.Show} end
  choices[#choices+1]={text='Je vais demander ailleurs.',callback=function() S.pendingSubject=nil;B.ShowHome() end}
  local text=B.DialogueLine('refusal')
  B.Show(subject.title,text,choices)
  return
 end
 S.pendingSubject=nil
 if S.SocialAnswer and S.SocialAnswer(subject,current,required,report) then return end
 local zone,x,_,z=GetUnitWorldPosition('player')
 D.DeliverResult(subject,{speechcraft=true,automatic=true,die=20,dd=required,confidence=current,success=true,
  knowledgeUnavailable=not not (subject.unresolved or not subject.answer or subject.answer==''),answer=subject.answer,source=subject.source,level=subject.level,
  npc=B.npc.name,locality=B.npc.locality,time=GetTimeStamp(),originZone=zone,originX=x,originZ=z,scopeRadius=subject.scopeRadius,
  inquiryDepth=subject.inquiryDepth,socialBehaviour=S.Behaviour(B.npc)},false)
end
function S.Options()
 local function slider(key,name,min,max,default,rank)
  return {type='slider',name=name,min=min,max=max,step=1,default=default,
   getFunc=function() return rank and S.Config()[key][rank] or S.Config()[key] end,
   setFunc=function(value) S.SetConfig(key,value,rank) end,disabled=function() return not S.Enabled() end}
 end
 local options={
  {type='description',text='Mode indépendant : confiance et préférences propres à Speechcraft. Les gains de la roue ne changent pas la confiance du mode Jet de dés. Les barres deviennent colorées après avoir testé les approches ; les pictogrammes au survol représentent les réactions du PNJ.'},
  slider('baseCap','Base du plafond',0,100,50),slider('threshold','Confiance requise pour les renseignements',0,100,40),
  {type='description',text='Le seuil reste identique pour toutes les questions d’un même PNJ, y compris les précisions. Les amicaux coopèrent plus facilement et les radicaux demandent davantage de persuasion. Demander un renseignement ne dépense pas de confiance. Les suppléments par question concernent uniquement le mode Jet de dés.'},
  slider('persuasiveBonus','Volonté persuasive : bonus au plafond',0,30,15),slider('intimidationBonus','Présence intimidante : bonus au plafond',0,30,10),slider('clemencyBonus','Clémence : bonus au plafond',0,30,5),
  slider('decayInterval','Délai avant perte — secondes',1,30,4),slider('persuasiveInterval','Délai avec Volonté persuasive — secondes',1,60,7),slider('decayAmount','Confiance perdue à chaque délai',0,5,1),
 }
 for rank=1,4 do options[#options+1]=slider('haggling','Marchandage '..rank..' : bonus au plafond',0,30,rank*3,rank) end
 for rank=1,4 do options[#options+1]=slider('reputation','Réputation régionale — palier '..rank,0,30,rank*5,rank) end
 options[#options+1]={type='description',text='La commande /rpmspeechdebug affiche le calcul détaillé du plafond pendant une conversation. Le chrono commence au premier clic de chaque manche : aucune perte pendant l’observation initiale, la rotation ou les chargements. Fermer la roue conserve les actions, préférences et pertes déjà enregistrées.'}
 return options
end
if SLASH_COMMANDS then SLASH_COMMANDS['/rpmspeechdebug']=function() if B.npc then B.Show('Speechcraft — calcul du plafond',S.Debug(B.npc),{},true) end end end
