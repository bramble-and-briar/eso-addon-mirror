if RPM_LOCALE and RPM_LOCALE.english then setfenv(1,RPM_LOCALE.environment) end
local B=IHR_Runtime.Beta
local A=IHR_Runtime.Base
local function choice(text,callback) return {text=text,callback=callback} end
local oldShowPlace=B.ShowPlace
local oldShowSocial=B.ShowSocial

function B.ShowPersuasion()
    local success,text=B.Persuade(B.npc)
    B.Show("Faire connaissance",text,{
        choice(success and "Merci. J’aurais justement une question." or "Je comprends. Je ne vais pas vous retenir.",function() B.ShowHome() end),
        choice("(Relire mes notes.)",function() B.ShowNotebook() end),
    })
end
function B.ShowReputation()
    local points,lines=B.Reputation(B.npc)
    local text=points>0 and (#lines>0 and B.Line("reputation",lines) or "On commence à entendre parler de vos services dans le coin.") or "Votre nom ne me dit rien. Peut-être que nous aurons l’occasion de faire connaissance."
    B.Show("Les nouvelles du pays",text,{
        choice("Je cherche simplement à me rendre utile.",function()
            B.ChangeTrust(B.npc,"courtesy",1)
            B.Show("Conversation","Alors, voyez ce qu’il y a à faire dans les environs.",{
                choice("Avez-vous entendu parler de quelqu’un qui aurait besoin d’aide ?",function() B.ShowQuestRumors() end),
            })
        end),
    })
end
function B.ShowHome()
    if not B.npc then return end
    local choices={}
    if B.Willing(B.npc) then
        choices[#choices+1]=choice("J’aurais besoin d’un renseignement.",function() B.ShowQuests() end)
        choices[#choices+1]=choice("Quelqu’un aurait besoin d’aide dans les environs ?",function() B.ShowQuestRumors() end)
        choices[#choices+1]=choice("Que pouvez-vous me dire sur les environs ?",function() B.ShowRumor() end)
    else
        choices[#choices+1]=choice("Je ne vous retiendrai pas longtemps. Puis-je vous poser une question ?",function() B.ShowPersuasion() end)
    end
    choices[#choices+1]=choice("Je cherche un marchand ou un service.",function() B.ShowServices() end)
    choices[#choices+1]=choice("Vous avez un moment pour parler ?",function() B.ShowSocial() end)
    choices[#choices+1]=choice("On vous a peut-être parlé de ce que j’ai fait ici ?",function() B.ShowReputation() end)
    choices[#choices+1]=choice("(Consulter mon carnet.)",function() B.ShowNotebook() end)
    B.Show("Conversation",B.Greeting(B.npc),choices)
end
function B.ShowSocial()
    if not B.saved.speechcraftEnabled then return oldShowSocial() end
    if not B.Willing(B.npc) then
        B.Show("Conversation",B.Line("social-refus",{"Pas maintenant. Une autre fois, peut-être.","Je préfère vous laisser à vos affaires, et retourner aux miennes."}),{
            choice("Bien sûr. Bonne journée à vous.",function()
                B.ChangeTrust(B.npc,"courtesy",1)
                B.ShowHome()
            end),
            choice("Je voulais seulement me présenter.",function() B.ShowPersuasion() end),
        })
        return
    end
    oldShowSocial()
end
function B.ShowReferral(referral)
    SetMapToPlayerLocation()
    if not A.SamePlace(referral.locality,A.SubZone()) then
        B.Show("Se renseigner","Nous nous sommes éloignés de l’endroit dont je vous parlais.",{})
        return
    end
    local direction,_,dist=A.ServiceDirections(referral.x,referral.y)
    local text=referral.name.." ? "
    if dist<.045 then text=text.."Cherchez tout près d’ici."
    else text=text.."Cherchez du côté "..direction..". Vous trouverez "..referral.name.." auprès du service : "..A.ServiceLabel(referral.service).."." end
    B.Show("Trouver "..referral.name,text,{choice("Merci du renseignement.",function() B.ShowHome() end)})
end
function B.ShowPlace(place)
    if not B.saved.speechcraftEnabled then return oldShowPlace(place) end
    local text=B.PlaceAnswer(place)
    local referral=B.npc.lastReferral
    local choices={}
    if referral then choices[#choices+1]=choice("Où puis-je trouver "..referral.name.." ?",function() B.ShowReferral(referral) end) end
    if B.EffectiveTrust(B.npc)<3 then
        choices[#choices+1]=choice("Je ne cherche pas d’ennuis. Pouvez-vous m’aider ?",function() B.ShowPersuasion() end)
    end
    choices[#choices+1]=choice("(Relire le passage qui parle de cet endroit.)",function()
        B.Show(place.kind,place.source,{choice("Revenir à ma question.",function() B.ShowPlace(place) end)},true)
    end)
    choices[#choices+1]=choice("(Noter cette piste.)",function()
        B.Remember(place)
        B.Show("Mes pistes","J’ai noté le nom de cet endroit et le renseignement qui m’y conduit.",{choice("Revenir à la conversation.",function() B.ShowQuest(place.quest) end)},true)
    end)
    choices[#choices+1]=choice("Parler d’un autre endroit.",function() B.ShowQuest(place.quest) end)
    B.Show("À propos de "..place.name,text,choices)
end
function B.ShowQuestRumors()
    if not B.Willing(B.npc) then
        B.Show("Les nouvelles du pays","Je ne partage pas les affaires des autres avec le premier venu.",{choice("Je veux seulement proposer mon aide.",function() B.ShowPersuasion() end)})
        return
    end
    local rumors=B.UnstartedRumors()
    local choices={}
    for _,entry in ipairs(rumors) do
        local rumor=entry
        choices[#choices+1]=choice(rumor.title,function()
            local text=B.HearRumor(rumor)
            if not text then B.ShowQuestRumors();return end
            B.Show("Une occasion de rendre service",text,{
                choice("Je vais aller voir. Merci.",function() B.ShowHome() end),
                choice("Avez-vous entendu d’autres nouvelles ?",function() B.ShowQuestRumors() end),
            })
        end)
    end
    local text=#choices>0 and B.Line("rumeurs",{"Il y a toujours quelqu’un qui a besoin d’un coup de main. De quoi voulez-vous parler ?","Quelques noms me viennent à l’esprit. Vous cherchez à vous rendre utile ?"}) or B.Line("pas-rumeurs",{"Rien qui me vienne à l’esprit, pour le moment.","Je n’ai pas entendu parler de quelqu’un à aider tout près d’ici. Essayez plus loin."})
    B.Show("Les nouvelles du pays",text,choices)
end
