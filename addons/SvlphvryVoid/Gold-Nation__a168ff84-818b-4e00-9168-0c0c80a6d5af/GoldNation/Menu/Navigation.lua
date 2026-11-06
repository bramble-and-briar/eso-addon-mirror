
GoldNation.Menu = GoldNation.Menu or {}

GoldNation.Menu.sections = {
    "Automation",
    "Money Making",
    "Guild",
    "Settings",
}

GoldNation.Menu.currentSection = nil

function GoldNation.Menu.OpenSection(sectionName)

    GoldNation.Menu.currentSection = sectionName

    d("Gold Nation: Selected " .. sectionName)

end
