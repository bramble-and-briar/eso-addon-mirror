ZO_CreateStringId("SI_BINDING_NAME_CRAFTPAWNS_TOGGLE","Toggle CraftPawns")
ZO_CreateStringId("SI_BINDING_NAME_CRAFTPAWNS_AUTO_RESEARCH","Auto Research Prepared Item")
ZO_CreateStringId("SI_BINDING_NAME_CRAFTPAWNS_ATTACH_WRIT_MAIL","Attach Decon Rewards")

function CraftPawns_ToggleBinding()
    if CraftPawns and CraftPawns.UI then CraftPawns.UI:Toggle() end
end

function CraftPawns_AutoResearchBinding()
    if CraftPawns and CraftPawns.AutoResearch then CraftPawns.AutoResearch:ProcessNext(true) end
end

function CraftPawns_AttachWritMailBinding()
    if CraftPawns and CraftPawns.MailTransfer then CraftPawns.MailTransfer:AttachWritLoot() end
end
