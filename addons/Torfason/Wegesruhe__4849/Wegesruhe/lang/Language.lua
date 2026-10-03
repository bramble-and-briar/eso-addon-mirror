local WR = Wegesruhe

local language = GetCVar("language.2")
WR.L = WR.Localization[language] or WR.Localization.en

ZO_CreateStringId("SI_BINDING_NAME_WEGESRUHE_SHOW_HELP", WR.L.BINDING_SHOW_HELP)
ZO_CreateStringId("SI_BINDING_NAME_WEGESRUHE_TOGGLE", WR.L.BINDING_TOGGLE)
ZO_CreateStringId("SI_WEGESRUHE_BINDING_CATEGORY", WR.L.BINDING_CATEGORY)
