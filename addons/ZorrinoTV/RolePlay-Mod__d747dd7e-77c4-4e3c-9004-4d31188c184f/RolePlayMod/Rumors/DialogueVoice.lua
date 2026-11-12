if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
-- Dialogue variants change tone, never the underlying geographic facts.
local B=IHR_Runtime.Beta
local ordinary={
 no_news={'C’est tout ce que je peux vous dire pour le moment.','Non, je n’ai rien entendu d’autre.','Rien d’autre ne me vient à l’esprit.'},
 unknown={'Je ne saurais pas vous dire où chercher.','Je n’ai rien entendu à ce sujet.'},
 greeting={'Bonjour. Vous cherchez quelque chose ?','Je vous écoute.','Oui ? Je peux vous aider ?'},
 crime={'Faites vite. Je ne veux pas d’ennuis.','Baissez la voix. Qu’est-ce que vous voulez ?'},
 question={'Que cherchez-vous ?','Dites-moi.','De quoi s’agit-il ?'},
 finished={'J’espère que vous trouverez ce que vous cherchez.','Bonne chance pour la suite.','Vous vouliez me parler d’autre chose ?'},
 refusal={'Je préfère ne pas me mêler de vos affaires.','Non. Je n’ai rien à vous dire.','Adressez-vous à quelqu’un d’autre.'},
}
local khajiit={
 no_news={'{name} n’a rien entendu d’autre.','C’est tout ce que {name} peut vous dire pour le moment.'},
 unknown={'{name} ne sait pas où chercher.','{name} n’a rien entendu à ce sujet.'},
 greeting={'{name} vous écoute. Que cherchez-vous ?','Vous avez une question pour {name} ?'},
 crime={'{name} ne veut pas d’ennuis. Parlez vite.','Parlez moins fort. {name} vous écoute.'},
 question={'Que voulez-vous demander à {name} ?','Dites à {name} ce que vous cherchez.'},
 finished={'{name} vous souhaite bonne route.','Avez-vous autre chose à demander à {name} ?'},
 refusal={'{name} préfère garder cela pour lui.','Non. {name} n’a rien à vous dire.','Cette affaire ne regarde pas {name}.'},
}
function B.DialogueFirstName(npc)
 return B.Name(npc and npc.name or 'Khajiit'):match('^([^ \t\r\n]+)') or 'Khajiit'
end
function B.IsKhajiitSpeaker(npc)
 return npc and B.SocialRace(npc.race or '')=='khajiit'
end
function B.DialogueLine(kind,npc)
 npc=npc or B.npc
 local lines=B.IsKhajiitSpeaker(npc) and khajiit[kind] or ordinary[kind]
 return (B.Line('dialogue-'..kind,lines or ordinary.question,npc):gsub('{name}',B.DialogueFirstName(npc)))
end
function B.SpokenAnswer(subject,text,npc)
 if not B.IsKhajiitSpeaker(npc) or not text or text=='' then return text end
 local name=B.DialogueFirstName(npc)
 -- A cached answer has already been spoken; do not accumulate introductions.
 if text:sub(1,#name)==name then return text end
 local intro=subject.kind=='route' and (name..' connaît le chemin. ') or (name..' peut vous renseigner. ')
 return intro..text
end
