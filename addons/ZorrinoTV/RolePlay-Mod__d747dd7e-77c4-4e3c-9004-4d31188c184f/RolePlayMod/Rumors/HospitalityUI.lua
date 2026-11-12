if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local B=IHR_Runtime.Beta
local A=IHR_Runtime.Base
local function choice(text,callback) return {text=text,callback=callback} end
function B.ShowHome()
    if not B.npc then return end
    local choices={}
    if B.Willing(B.npc) then
        choices[#choices+1]=choice("J’aurais besoin d’un renseignement.",function() B.ShowQuests() end)
        choices[#choices+1]=choice("Que connaissez-vous des environs ?",function() B.ShowRumor() end)
        if B.HospitalityContext(B.npc) then choices[#choices+1]=choice("Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?",function() B.ShowQuestRumors() end) end
    else
        choices[#choices+1]=choice("Permettez-moi au moins de me présenter.",function() B.ShowSocial() end)
    end
    choices[#choices+1]=choice("Je cherche un marchand ou un service.",function() B.ShowServices() end)
    if B.IsInnkeeper(B.npc) and B.Lodging.Available() then choices[#choices+1]=choice("Je voudrais vous louer une chambre.",function() B.ShowLodging() end) end
    choices[#choices+1]=choice("Faisons un peu connaissance.",function() B.ShowSocial() end)
    if B.Reputation(B.npc)>0 then choices[#choices+1]=choice("On vous a peut-être parlé de mon aide dans la région ?",function() B.ShowReputation() end) end
    choices[#choices+1]=choice("(Consulter mon carnet.)",function() B.ShowNotebook() end)
    B.Show("Conversation",B.Willing(B.npc) and B.Greeting(B.npc) or (B.SocialRefusal and B.SocialRefusal(B.npc)) or B.Line("etranger",{"Nous ne nous connaissons pas. Je préfère en rester là.","Je ne confie pas les affaires du pays à n’importe quel passant.","Avant de vous répondre, j’aimerais savoir à qui j’ai affaire."}),choices)
end
function B.ShowSocial()
    local npc=B.npc
    local player=B.Name(GetUnitName("player"))
    local choices={
        choice("Je m’appelle "..player..". Je cherche à mieux connaître ce pays.",function()
            local gained=B.ChangeTrust(npc,"introduction",2)
            B.Show("Faire connaissance",gained and "Bien. C’est déjà un début. Qu’est-ce qui vous amène ici ?" or "Oui, vous me l’avez déjà dit. Je vous écoute.",{
                choice("J’aimerais connaître les gens d’ici avant de reprendre la route.",function()
                    B.ChangeTrust(npc,"conversation",1)
                    B.Show("Faire connaissance","Prenez le temps de regarder et d’écouter. Vous comprendrez mieux le pays comme ça.",{
                        choice("Merci. Je ne vais pas vous retenir davantage.",function() B.ChangeTrust(npc,"courtesy",1);B.ShowHome() end),
                        choice("Puis-je maintenant vous poser une question ?",function() B.ShowHome() end),
                    })
                end),
                choice("Je respecte ceux qui vivent ici. Je ne cherche pas d’ennuis.",function()
                    B.ChangeTrust(npc,"respect",1)
                    B.Show("Faire connaissance","Alors nous devrions pouvoir nous entendre.",{choice("Merci de m’avoir écouté.",function() B.ShowHome() end)})
                end),
            })
        end),
        choice("Je ne cherche qu’à me rendre utile. Laissez-moi une chance.",function() B.ShowPersuasion() end),
        choice("Je vois. Bonne journée à vous.",function() B.ChangeTrust(npc,"courtesy",1);B.ShowHome() end),
        choice("Vous pourriez faire un effort pour être aimable.",function()
            B.ChangeTrust(npc,"pressure",-1)
            B.Show("Conversation","Je n’ai pas à vous rendre de comptes. Surveillez votre ton.",{choice("Reprenons calmement.",function() B.ShowHome() end)})
        end),
    }
    B.Show("Faire connaissance",B.Willing(npc) and "Je peux vous accorder un moment. Je vous écoute." or "Parlez. Mais ne me faites pas perdre mon temps.",choices)
end
function B.ShowReputation()
    local points,lines=B.Reputation(B.npc)
    local text=points>0 and (#lines>0 and B.Line("faits-reconnus",lines) or "Oui, j’ai entendu dire que vous aviez rendu service dans le coin.") or "Votre nom ne me dit rien pour le moment."
    B.Show("Les nouvelles du pays",text,{
        choice("J’espère que mes actes parlent pour moi.",function() B.ShowHome() end),
        choice("(Consulter les faits reconnus.)",function()
            local entries={}
            for id,entry in pairs(B.saved.reputationLedger) do
                local name=type(GetQuestName)=="function" and GetQuestName(id) or ""
                if name~="" then entries[#entries+1]=B.Name(name).." : "..entry.reason end
            end
            table.sort(entries)
            B.Show("Ma réputation",#entries>0 and table.concat(entries,"\n\n") or "Aucun fait n’a encore été reconnu.",{},true)
        end),
    })
end
function B.ShowPlace(place)
    local text=B.PlaceAnswer(place)
    local informant=B.npc.name
    local referral=B.npc.lastReferral
    local choices={}
    if referral then choices[#choices+1]=choice("Où puis-je trouver "..referral.name.." ?",function() B.ShowReferral(referral) end) end
    if not B.Willing(B.npc) then choices[#choices+1]=choice("Faisons d’abord connaissance.",function() B.ShowSocial() end) end
    choices[#choices+1]=choice("(Noter sa réponse et ses indications.)",function()
        B.Remember(place,text,informant)
        B.Show("Mon carnet","J’ai conservé la réponse de "..informant..".",{choice("Revenir à la conversation.",function() B.ShowQuest(place.quest) end)},true)
    end)
    choices[#choices+1]=choice("(Relire ce qui m’avait mis sur cette piste.)",function()
        B.Show("Mon journal",place.source,{choice("Revenir à la conversation.",function() B.ShowPlace(place) end)},true)
    end)
    choices[#choices+1]=choice("Poser une autre question.",function() B.ShowQuest(place.quest) end)
    B.Show("À propos de "..place.name,text,choices)
end
function B.ShowQuestRumors()
    if not B.HospitalityContext(B.npc) then
        B.Show("Conversation","Vous devriez demander dans une auberge. C’est là qu’on entend les nouvelles.",{})
        return
    end
    if not B.Willing(B.npc) then B.ShowSocial();return end
    local choices={}
    for _,entry in ipairs(B.KnownRumors(B.npc)) do
        local rumor=entry
        choices[#choices+1]=choice(rumor.title,function()
            local text=B.HearRumor(rumor)
            if not text then B.ShowQuestRumors();return end
            local informant=B.npc.name
            B.Show("Une rumeur",text,{
                choice("(Noter la rumeur et les indications.)",function()
                    B.Remember({name=rumor.title,rumorId=rumor.quest},text,informant)
                    B.Show("Mon carnet","J’ai conservé ce que "..informant.." m’a raconté.",{},true)
                end),
                choice("Avez-vous entendu autre chose ?",function() B.ShowQuestRumors() end),
                choice("Merci. Je vais me renseigner.",function() B.ShowHome() end),
            })
        end)
    end
    B.Show("Les nouvelles du pays",#choices>0 and "J’ai peut-être entendu quelque chose qui pourrait vous intéresser." or B.Line("rien-pour-moi",{"Non, je n’ai rien entendu de particulier. Essayez de parler aux autres.","Je n’ai pas de nouvelle à vous donner. Quelqu’un ici en saura peut-être davantage."}),choices)
end
function B.ShowNotebook()
    local choices={}
    for _,entry in ipairs(B.saved.notebook) do
        local note=entry
        local legacy=note.origin~="npc"
        choices[#choices+1]=choice(note.name..(legacy and " — ancienne note du journal" or (" — "..note.informant)),function()
            local heading=legacy and "Ancienne note recopiée du journal ; ce n’est pas un renseignement reçu d’un PNJ." or ("Propos de "..note.informant..(note.locality~="" and (" · "..note.locality) or ""))
            B.Show(note.name,heading.."\n\n« "..note.source.." »",{},true)
        end)
    end
    B.Show("Mon carnet",#choices>0 and "Les réponses et les rumeurs que j’ai choisi de conserver." or "Je n’ai encore noté aucun renseignement.",choices,true)
end
-- Fictional hospitality phrasing; names and locality remain client/catalogue data.
local lodgingVoices={
    bosmer={'Vous avez assez couru les chemins. Il me reste une chambre pour la nuit.','Posez vos affaires. Vous trouverez bien le temps de reprendre la route après avoir dormi.','Une chambre ? Il en reste une. Un peu de repos vous fera du bien.'},
    khajiit={'{name} a encore une chambre. Posez vos affaires et reposez-vous.','Un lit et un peu de calme ? {name} peut vous proposer cela.','{name} vous garde une place à l’abri. Vous avez assez marché pour aujourd’hui.'},
    orc={'Une chambre ? Il en reste une. Installez-vous et reposez-vous.','Vous voulez repartir du bon pied ? Prenez le temps de dormir.','Entrez. On trouve toujours une place pour quelqu’un qui a besoin de dormir.'},
    dunmer={'La route use tout le monde. Il me reste une chambre, si vous voulez.','Vous pouvez passer la nuit ici. Vos affaires attendront bien quelques heures.','Une chambre est libre. Vous y serez tranquille.'},
    altmer={'Une chambre est disponible. Vous pourrez vous y reposer tranquillement.','Bien sûr. Posez vos affaires et accordez-vous un peu de repos.','Je peux vous proposer un couchage pour la nuit. Vous serez au calme.'},
    argonian={'Restez à l’abri cette nuit. Vous reprendrez la route après vous être reposé.','Posez votre fardeau. Il me reste une place pour dormir.','Vous cherchez le repos ? Vous pouvez passer la nuit ici.'},
    nord={'Un lit au chaud, voilà ce qu’il vous faut. Vous pouvez rester.','Il reste une chambre. Demain, vos jambes vous remercieront.','Entrez donc. Vous avez assez marché pour aujourd’hui.'},
    breton={'Il me reste un couchage. Une bonne nuit vous remettra d’aplomb.','Une chambre pour la nuit ? Bien sûr. Prenez le temps de souffler.','Vous pouvez vous installer. Vos affaires seront encore là après une bonne nuit.'},
    redguard={'Même les voyageurs les plus endurants ont besoin de repos. Une chambre est libre.','Faites halte ici pour la nuit. Vous reprendrez la route reposé.','Vous trouverez un couchage ici. Ménagez vos forces pour demain.'},
    imperial={'Une chambre pour la nuit ? Je peux vous proposer cela.','Il me reste une chambre. Vous pourrez y dormir sans être dérangé.','Installez-vous. Une bonne nuit vous fera du bien.'},
}
local plainLodging={'Une chambre pour la nuit ? Il m’en reste une.','Vous pouvez passer la nuit ici. Posez vos affaires.','Entrez. Vous trouverez une place pour vous reposer.'}
local lodgingRegions={
    ['bois de graht']='forest',['grahtwood']='forest',['prasin']='forest',['greenshade']='forest',['malabal tor']='forest',
    ['desert d alik r']='dust',['alik r desert']='dust',['elsweyr']='dust',
    ['auridia']='coast',['auridon']='coast',['perchoir de khenarthi']='coast',['khenarthi s roost']='coast',['couchant']='coast',['summerset']='coast',
    ['fangeombre']='marsh',['shadowfen']='marsh',['tourbevase']='marsh',['murkmire']='marsh',
}
local lodgingContext={
    forest={'Les sentiers ne manquent pas par ici. Vous les retrouverez après avoir dormi.','Pour cette nuit, laissez donc les chemins aux bêtes de la forêt.'},
    dust={'Vous avez assez affronté la poussière pour aujourd’hui.','Un peu de repos à l’abri vaut mieux qu’une nuit sur les chemins.'},
    coast={'Vous serez mieux ici que dehors, avec le vent du large.','Vous aurez bien le temps de retrouver la côte après avoir dormi.'},
    marsh={'Pour cette nuit, restez donc au sec.','Mieux vaut dormir ici que passer la nuit dans la boue.'},
}
function B.LodgingDialogue(npc)
    local race=B.SocialRace(npc.race or '')
    local cat=B.IsKhajiitSpeaker(npc)
    local mood=B.Personality.Behaviour(npc)
    local lines=lodgingVoices[race] or plainLodging
    if mood=='hostile' then
        lines=cat and {'{name} peut vous laisser une chambre. Ne faites pas d’histoires.','Une chambre, soit. {name} ne veut pas d’ennuis sous son toit.'}
            or {'Il reste une chambre. Pas de bruit et pas d’ennuis.','Vous pouvez dormir ici. Je ne veux pas d’histoires sous mon toit.'}
    end
    local text=B.Line('lodging-voice-'..tostring(race)..'-'..mood,lines,npc)
    local _,region=B.SocialZone(npc)
    region=B.Normalize(region or ''):gsub('^le ',''):gsub('^la ',''):gsub('^les ','')
    local context=lodgingContext[lodgingRegions[region]]
    local additions={}
    if mood~='hostile' and context then additions[#additions+1]=B.Line('lodging-region-'..region,context,npc) end
    local _,town=B.TavernTown(npc)
    if town and town~='' and mood~='hostile' then additions[#additions+1]=town..' sera encore là à votre réveil.' end
    if #additions>0 then text=text..'\n\n'..table.concat(additions,' ') end
    local free=cat and {'{name} vous offre le couchage pour la nuit.','Pour cette nuit, {name} ne vous demande rien.'}
        or {'Je vous offre le couchage pour la nuit.','Vous ne me devez rien pour cette nuit.'}
    text=text..'\n\n'..B.Line('lodging-offer-'..mood,free,npc)
    return (text:gsub('{name}',function() return B.DialogueFirstName(npc) end))
end

function B.ShowLodging()
    if not B.IsInnkeeper(B.npc) or not B.Lodging.Available() then B.ShowHome();return end
    local npc=B.npc
    B.Show("Louer une chambre", B.LodgingDialogue(npc),{
        choice("Merci. Je vais prendre la chambre.",function()
            if not B.Lodging.Reserve(npc) then B.ShowHome();return end
            local native=B.nativeSession
            B.Close()
            local function start()
                local ok,message=B.Lodging.Start()
                if not ok then d("[RolePlayMod] "..message) end
            end
            if native and type(IsInteracting)=="function" and IsInteracting() then
                if INTERACTION and INTERACTION.CloseChatter then INTERACTION:CloseChatter() end
                zo_callLater(start,250)
            else start() end
        end),
        choice("Pas pour le moment, merci.",function() B.ShowHome() end),
    },false)
end
