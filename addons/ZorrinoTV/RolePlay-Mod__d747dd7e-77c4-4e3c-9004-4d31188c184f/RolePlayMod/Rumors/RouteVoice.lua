-- French route wording. Callers supply the facts; this module only voices them.
local B=IHR_Runtime.Beta
local V={};B.RouteVoice=V
local lastChoice={}
local function clean(s)
 return type(s)=='string' and (s:gsub('[ \t\r\n]+',' '):gsub('^ +',''):gsub(' +$','')) or ''
end
local function norm(s) return B.Normalize(clean(s)) end
local function finite(n) return type(n)=='number' and n==n and n>=0 and n<math.huge end
local function place(name)
 name=clean(name)
 if B.Dice and B.Dice.PlaceName then return B.Dice.PlaceName(name) end
 return name:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')
end
function V.At(name)
 name=place(name)
 if name=='' then return '' end
 local n=norm(name)
 if n:find('^le ') then return 'au '..name:sub(4) end
 if n:find('^les ') then return 'aux '..name:sub(5) end
 return 'à '..name
end
function V.Of(name)
 name=place(name)
 if name=='' then return '' end
 local n=norm(name)
 if n:find('^le ') then return 'du '..name:sub(4) end
 if n:find('^les ') then return 'des '..name:sub(5) end
 if name:find('^[AEIOUYaeiouy]') or name:find('^É') or name:find('^Î') or name:find('^é') then return 'd’'..name end
 return 'de '..name
end
function V.NormalizeBearing(value)
 local n=norm(value)
 n=n:gsub('^direction ',''):gsub('^vers le ',''):gsub('^vers l ',''):gsub('^au ',''):gsub('^a l ',''):gsub('^a ','')
 local bearings={nord='au nord',sud='au sud',est='à l’est',ouest='à l’ouest',
  ['nord est']='au nord-est',['nord ouest']='au nord-ouest',['sud est']='au sud-est',['sud ouest']='au sud-ouest'}
 return bearings[n]
end
local function speaker(npc)
 if B.DialogueFirstName then return B.DialogueFirstName(npc) end
 return clean(npc and npc.name or ''):match('^(%S+)') or 'Ce Khajiit'
end
local function khajiit(npc) return B.IsKhajiitSpeaker and B.IsKhajiitSpeaker(npc) or false end
local function choose(kind,lines,o)
 local npc=o.npc or B.npc
 local identity=npc and (npc.name or '')..':'..tostring(npc.zoneId or '') or 'voyageur'
 local key=kind..':'..identity
 local topic=o.targetKey or o.destination or o.subject or ''
 local hash=B.Hash(identity..':'..kind..':'..topic..':'..tostring(o.bearing or ''))
 local index=hash%#lines+1
 -- A formatter is sometimes called repeatedly while planning. Alternate the
 -- surface wording without changing a destination, bearing or knowledge gate.
 if lastChoice[key]==index and #lines>1 then index=index%#lines+1 end
 lastChoice[key]=index
 return lines[index]
end
local ordinary={
 near={
  'C’est juste ici. Regardez autour de vous.','Vous êtes tout près. Cherchez à quelques pas.',
  'Ce que vous cherchez est juste à côté.','C’est là, tout près de vous.'},
 relative={
  'C’est {where}.','Il faut chercher {where}.','Regardez {where}.',
  'Vous devriez chercher {where}.','C’est de ce côté : {where}.'},
 direction={
  'C’est {bearing} d’ici.','Dirigez-vous {bearing}.','Il faut aller {bearing}.',
  'Cherchez {bearing} d’ici.','Prenez la direction {ofBearing}.',
  'Il faut partir {towardBearing}.'},
 subject={
  '{subject} se {find} {bearing} d’ici.','Cherchez {lowerSubject} {bearing} d’ici.',
  'C’est {bearing} d’ici que vous trouverez {lowerSubject}.',
  '{subject} ? C’est {bearing} d’ici.',
  '{subject} {be} de ce côté-là, {bearing}.',
  'Il faut aller {bearing} d’ici pour trouver {lowerSubject}.'},
 area={
  'Cherchez dans les environs, {bearing} d’ici.','Regardez plutôt {bearing}. C’est dans ce secteur.',
  'Il faut chercher {bearing} d’ici, dans les alentours.','Vous devriez chercher {bearing}, dans les environs.'},
 entrance={
  'Pour continuer, dirigez-vous {bearing}.','L’accès se trouve {bearing} d’ici.',
  'Pour y entrer, allez {bearing}.','Le passage est {bearing} d’ici.',
  'Vous pourrez poursuivre en allant {bearing}.','Pour passer de l’autre côté, cherchez {bearing} d’ici.'},
 destination={
  'Cherchez {at}.','Renseignez-vous {at}.','Vous devriez chercher {at}.',
  'Allez voir {at}.','Essayez {at}.','Il faut chercher {at}.'},
 destinationBearing={
  'Cherchez {at}, {bearing} d’ici.','Allez {bearing} : vous trouverez {destination} de ce côté-là.',
  '{destination} se {destinationFind} {bearing} d’ici.','Pour rejoindre {destination}, dirigez-vous {bearing}.',
  '{destination} ? Prenez la direction {ofBearing}.','Vous cherchez {destination} ? C’est {bearing} d’ici.'},
}
local cats={
 near={
  '{speaker} vous le dit : c’est juste ici.','Regardez autour de vous. {speaker} vous assure que c’est tout près.',
  'Quelques pas, pas davantage. {speaker} vous indique les alentours immédiats.',
  'C’est là, juste à côté. {speaker} ne vous envoie pas bien loin.'},
 relative={
  '{speaker} vous dirait de chercher {where}.','Cherchez {where}. C’est là que {speaker} vous envoie.',
  '{speaker} vous conseille de regarder {where}.','Ce que vous cherchez est {where}. {speaker} vous indique ce côté-là.',
  'Pour {speaker}, il faut chercher {where}.'},
 direction={
  '{speaker} vous dirait de chercher {bearing} d’ici.','{speaker} vous conseille d’aller {bearing}.',
  'C’est {bearing} d’ici. {speaker} connaît les alentours.',
  'Cherchez {bearing}. C’est le côté que {speaker} vous indique.',
  'De ce côté-là, {bearing}. Voilà ce que peut vous dire {speaker}.'},
 subject={
  '{speaker} vous dirait de chercher {lowerSubject} {bearing} d’ici.',
  '{subject} se {find} {bearing} d’ici. {speaker} connaît les alentours.',
  'Pour {speaker}, il faut chercher {lowerSubject} {bearing} d’ici.',
  '{subject} ? {speaker} vous dirait d’aller {bearing}.',
  '{speaker} vous conseille d’aller {bearing} pour trouver {lowerSubject}.'},
 area={
  '{speaker} chercherait dans les environs, {bearing} d’ici.',
  'Regardez plutôt {bearing}. {speaker} vous indique ce secteur.',
  '{speaker} vous conseille de chercher {bearing}, dans les alentours.',
  'Vous devriez chercher {bearing} d’ici. {speaker} ne peut désigner un point précis.'},
 entrance={
  '{speaker} vous indique l’accès, {bearing} d’ici.',
  'Pour continuer, {speaker} vous conseille d’aller {bearing}.',
  'Cherchez le passage {bearing}. C’est par là que {speaker} vous envoie.',
  'Vous pourrez poursuivre {bearing}. {speaker} vous montre ce côté-là.'},
 destination={
  '{speaker} vous dirait de chercher {at}.','{speaker} vous conseille de vous renseigner {at}.',
  'Essayez {at}. C’est là que {speaker} vous enverrait.',
  'Allez voir {at}. Voilà ce que peut vous conseiller {speaker}.'},
 destinationBearing={
  '{speaker} vous indique {destination}, {bearing} d’ici.',
  'Pour rejoindre {destination}, {speaker} vous conseille d’aller {bearing}.',
  '{destination} se {destinationFind} {bearing} d’ici. {speaker} connaît les alentours.',
  'Cherchez {at}, {bearing} d’ici. C’est là que {speaker} vous envoie.'},
}
local distances={
 close={'C’est tout près.','Ce n’est pas loin d’ici.','Ce n’est vraiment pas loin d’ici.','C’est juste à côté.'},
 near={'Ce n’est pas bien loin.','Il vous reste un peu de chemin.','Vous n’en avez plus pour très loin.','C’est encore un peu plus loin.'},
 middle={'Vous avez encore du chemin à faire.','Il vous reste un bon bout de marche.','Ce n’est pas juste à côté.','Comptez encore un peu de marche.'},
 far={'Il y a de la route à faire. Prenez de quoi tenir en chemin.','Préparez quelques provisions avant de partir : c’est loin d’ici.',
  'Vous avez un bon bout de route devant vous. Mieux vaut partir préparé.','Ne partez pas sans provisions : il reste du chemin.'},
}
function V.DistanceText(o)
 o=o or {}
 local meters=o.distanceMeters
 local band
 if finite(meters) then
  band=meters<=75 and 'close' or meters<=300 and 'near' or meters>=2000 and 'far' or 'middle'
 elseif o.near==true then band='close' end
 -- A fraction of a map is not a length: a town and a province have different
 -- scales. Never infer a long trip from distanceMap/worldDistance alone.
 if not band then return '' end
 return choose('distance-'..band,distances[band],o)
end
local function lowerSubject(value)
 return value:gsub('^Sa ','sa '):gsub('^Son ','son '):gsub('^Ses ','ses '):gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')
end
local function plural(value) local n=norm(value);return n:find('^les ') or n:find('^ses ') or n:find('^des ') end
function V.RelativePosition(o)
 o=o or {}
 local anchor=clean(o.anchor)
 local bearing=V.NormalizeBearing(o.bearing)
 if bearing and anchor~='' then return bearing..' '..V.Of(anchor) end
 local part=clean(o.part)
 if part~='' and anchor~='' then
  local raw=norm(part):gsub('^le ',''):gsub('^la ',''):gsub('^l ',''):gsub('^partie ','')
  local compass=V.NormalizeBearing(raw)
  if compass then return 'dans la partie '..compass:gsub('^au ',''):gsub('^à l’','')..' '..V.Of(anchor) end
  return 'dans '..part..' '..V.Of(anchor)
 end
 local parent=place(o.parent)
 if parent~='' then
  return ({inside='à l’intérieur '..V.Of(parent),under='sous '..parent,near='près '..V.Of(parent),
   outside='à l’extérieur '..V.Of(parent)})[o.relation] or V.At(parent)
 end
 local region=clean(o.region)
 if region~='' then return 'dans la région '..V.Of(region) end
end
function V.Format(kind,o)
 o=o or {}
 local bearing=V.NormalizeBearing(o.bearing)
 local destination=place(o.destination)
 local subject=clean(o.subject)
 local where=kind=='relative' and V.RelativePosition(o) or nil
 if kind=='relative' and not where then return nil end
 if kind=='local' then
  -- Never paraphrase an authored clue into a different fact. Local room/tree/
  -- crate details supplied by a verified source remain literal.
  local detail=clean(o.detail)
  if detail~='' then return detail end
  kind=subject~='' and 'direction' or 'destination'
 end
 if kind=='direction' and subject~='' then kind='subject' end
 if kind=='destination' and bearing and destination~='' then kind='destinationBearing' end
 if not bearing and (kind=='direction' or kind=='subject' or kind=='area' or kind=='entrance') then
  if destination~='' then kind='destination' else return nil end
 end
 if (kind=='destination' or kind=='destinationBearing') and destination=='' then return nil end
 local bank=khajiit(o.npc or B.npc) and cats or ordinary
 local lines=bank[kind]
 if not lines then return nil end
 local text=choose(kind,lines,o)
 local bareBearing=(bearing or ''):gsub('^au ',''):gsub('^à l’','')
 local values={speaker=speaker(o.npc or B.npc),bearing=bearing or '',bareBearing=bareBearing,where=where,
  ofBearing=(bearing or ''):find('^à l’') and ('de l’'..bareBearing) or ('du '..bareBearing),
  towardBearing=(bearing or ''):find('^à l’') and ('vers l’'..bareBearing) or ('vers le '..bareBearing),
  destination=destination,at=V.At(destination),subject=subject,lowerSubject=lowerSubject(subject),
  find=plural(subject) and 'trouvent' or 'trouve',be=plural(subject) and 'sont' or 'est',destinationFind=plural(destination) and 'trouvent' or 'trouve'}
 text=text:gsub('{([%w]+)}',function(key) return values[key] or '' end)
 text=text:gsub('^([a-z])',string.upper)
 if o.includeDistance~=false and kind~='relative' and kind~='near' then
  local distance=V.DistanceText(o)
  if distance~='' then text=text..' '..distance end
 end
 return text
end
