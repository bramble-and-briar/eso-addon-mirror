if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Questions describe the kind of evidence actually available, never a fictional method.
local B=IHR_Runtime.Beta
local D=B.Dice
local C={};D.Coherence=C
local function norm(s) return B.Normalize(s or '') end
function C.MethodQuestion(question)
    local q=norm(question)
    if not q:find('^comment ') then return false end
    for _,word in ipairs({'rejoindre','trouver','retrouver','aller','acceder','se rendre'}) do
        if q:find('^comment '..word..' ') or q:find('^comment puis je '..word..' ') or q:find('^comment peut on '..word..' ') then return false end
    end
    return true
end
local plurals={ruines='ruines',cascades='cascades',catacombes='catacombes',egouts='égouts',montagnes='montagnes',iles='îles'}
local articles={comptoir='le',site='le',fort='le',camp='le',campement='le',temple='le',port='le',palais='le',village='le',reliquaire='le',promontoire='le',bois='le',longere='la',mine='la',forteresse='la',grotte='la',caverne='la',tour='la',salle='la',ville='la',capitale='la',auberge='l’',oratoire='l’',autel='l’'}
function D.PlaceName(name)
    name=B.Name(name or '')
    local first=norm(name):match('^([^ ]+)')
    if first=='le' or first=='la' or first=='les' then return (name:gsub('^Le ','le '):gsub('^La ','la '):gsub('^Les ','les ')) end
    if plurals[first] then return 'les '..plurals[first]..(name:match('^[^ ]+(.*)$') or '') end
    local article=articles[first]
    if article then
        local noun=zo_strlower(name:match('^[^ ]+') or '')..(name:match('^[^ ]+(.*)$') or '')
        return article..(article=='l’' and '' or ' ')..noun
    end
    return name
end
function D.OfPlace(name)
    name=D.PlaceName(name)
    if name:find('^le ') then return 'du '..name:sub(4) end
    if name:find('^les ') then return 'des '..name:sub(5) end
    if name:find('^[AEIOUYaeiouy]') or name:find('^É') or name:find('^Î') then return 'd’'..name end
    return 'de '..name
end
function D.GeographicQuestion(name,kind)
    if not name or name=='' then return nil end
    if kind~='place' then return 'Savez-vous où je pourrais trouver '..name..' ?' end
    name=D.PlaceName(name)
    local text=norm(name)
    local first=text:match('^([^ ]+)')
    local plural=text:find('^les ') or text:find('^des ')
    if plurals[first] then
        local rest=name:match('^[^ ]+(.*)$') or ''
        name='les '..plurals[first]..rest;plural=true
    end
    return 'Où se '..(plural and 'trouvent ' or 'trouve ')..name..' ?'
end
-- Method facts require a separate, reviewed source, current-stage match and a named witness.
-- No procedural authority is inferred from a location hint or the objective's imperative.
local methods={
 [49140008]={speaker='Danys',answer='Les Crocs du Chaos sont détruits. Il reste le moissonneur qui garde l’Ancre : abattez-le, puis détruisez l’ancrage.',
 source='Client FR : objectifs 7949764/36128 et 36129, dialogues 200879108/33230 et 33232 ; ESOAZ https://esoaz.com/2025/01/11/quetes-secondaires-bois-graht-centre-teso/ — L’obscurité éveillée, dernière étape'}
}
-- These questions ask about a destination/referral rather than pretending a place is a method.
local wording={
 [48930009]='Où se trouve le reliquaire ?',
 [49080007]='Où se trouve le pot en terre cuite ?',
 [42210001]='Où dois-je chercher pour résoudre l’énigme ?',
 [44050005]='Où dois-je me rendre pour préparer les ingrédients ?',
 [43360006]='Par où passe-t-on pour rejoindre l’autel suivant ?',
 [42090001]='À qui pourrais-je demander comment entrer dans le manoir de Valano ?',
 [42660019]='Où se trouve l’entrée de la grotte ?',
 [48680015]='Par où peut-on sortir des catacombes ?'
}
C.replaced={}
C.audit={records=0,methods=0,geographic=0,withheld=0}
for _,q in pairs(IHR_RegionalKnowledgeData.quests) do
    for _,r in ipairs(q.records) do
        C.audit.records=C.audit.records+1
        local fact=methods[r.id]
        if fact then
            C.replaced[tostring(r.id)]=norm(r.hint)
            r.hint=fact.answer;r.source=fact.source;r.method=true;r.methodVerified=true;r.methodSpeaker=fact.speaker
            r.coherenceRevision='coherence161-method';C.audit.methods=C.audit.methods+1
        elseif C.MethodQuestion(r.question) or r.method then
            r.method=nil;r.methodVerified=nil;r.coherenceRevision='coherence161-location'
            if C.MethodQuestion(r.question) then
                r.question=wording[r.id] or D.GeographicQuestion(r.target,r.kind)
                -- Some older hints merely say to fight a named foe. They prove neither a
                -- mechanism nor its position; keep them out until properly documented.
                if not r.hint or r.id==42610001 or (r.id>=43610006 and r.id<=43610008) then
                    r.silent=true;C.audit.withheld=C.audit.withheld+1
                else C.audit.geographic=C.audit.geographic+1 end
            end
            if r.localQuestion and C.MethodQuestion(r.localQuestion) then r.localQuestion=r.question end
            if r.selfQuestion and C.MethodQuestion(r.selfQuestion) then r.selfQuestion=r.question end
        end
        if wording[r.id] then r.question=wording[r.id] end
        if r.id==49080007 then r.target='le pot en terre cuite';r.kind='object' end
    end
end

-- Verified person location for both visible delivery/talk stages. The route to
-- the stronghold is not a substitute for a local answer about Moramat.
do
 local quest=IHR_RegionalKnowledgeData.quests[4984]
 for _,record in ipairs(quest and quest.records or {}) do
  if record.id==49840001 or record.id==49840002 then
   record.hint='Moramat ? Cherchez dans la longère du chef, à Mordécorce.'
   record.source='ESOAZ — Les quêtes secondaires du Bois de Graht [Nord], Un plan lucratif : https://esoaz.com/2025/01/10/quetes-secondaires-bois-graht-nord-teso/ ; géographie recoupée avec https://en.uesp.net/wiki/Online:Moramat'
   record.coherenceRevision='coherence111-moramat-local'
  end
 end
end
