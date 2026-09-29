local SF = LibSFUtils

RidingSchool = {
    name = "RidingSchool",
    version = "1.4.22",
    settingName = "RidingSchool",
    settingDisplayName = "RidingSchool",
    author = "Shadowfen",
    savedVars = "RidingSchoolVars",
	savedVarVersion = 1,
}

RidingSchool.defaults = {
    Order = {
        [1] = RIDING_TRAIN_SPEED,
        [2] = RIDING_TRAIN_CARRYING_CAPACITY,
        [3] = RIDING_TRAIN_STAMINA,
    },
    threshold = {
        [RIDING_TRAIN_SPEED] = 50,
        [RIDING_TRAIN_STAMINA] = 50,
        [RIDING_TRAIN_CARRYING_CAPACITY] = 50,
    },
    disables = {
        [RIDING_TRAIN_SPEED] = false,
        [RIDING_TRAIN_STAMINA] = false,
        [RIDING_TRAIN_CARRYING_CAPACITY] = false,
    },
}


RidingSchool.settingDisplayName = SF.GetIconized(RidingSchool.settingDisplayName, SF.colors.gold.hex)
RidingSchool.version = SF.GetIconized(RidingSchool.version, SF.colors.gold.hex)
RidingSchool.author = SF.GetIconized(RidingSchool.author, SF.colors.purple.hex)

SF.LoadLanguage(RidingSchool_localization_strings, "en")
