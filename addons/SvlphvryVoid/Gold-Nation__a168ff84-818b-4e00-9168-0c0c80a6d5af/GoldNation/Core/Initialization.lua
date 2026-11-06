
GoldNation = GoldNation or {}

GoldNation.name = "GoldNation"
GoldNation.version = "1.0"

GoldNation.initialized = false

function GoldNation.Initialize()

    if GoldNation.initialized then
        return
    end

    GoldNation.initialized = true

    d("|cD6A84BGold Nation|r: Initializing...")

    -- Initialize addon modules
    if GoldNation.Modules then
        GoldNation.Modules.Initialize()
    end

    -- Initialize menu
    if GoldNation.Menu then
        GoldNation.Menu.Initialize()
    end

    d("|cD6A84BGold Nation|r: Ready!")

end
