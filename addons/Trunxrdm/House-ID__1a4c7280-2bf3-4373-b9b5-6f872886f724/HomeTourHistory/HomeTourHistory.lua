HomeTourHistory = {}
local HTH = HomeTourHistory

HTH.name = "HomeTourHistory"
HTH.version = "1.0"

HTH_Saved = HTH_Saved or { history = {} }

-- ===============================
-- MASTER HOUSE DATABASE
-- ===============================
HTH.MASTER_HOUSES = {
    ["Ancient Anchor Berth"]={id=95},
    ["The Ebony Flask Inn Room"]={id=3},
    ["Golden Gryphon Garret"]={id=58},
    ["Journey's End Lodgings"]={id=100},
    ["Mara's Kiss Inn Room"]={id=1},
    ["Pilgrim's Rest"]={id=87},
    ["Rosewine Retreat"]={id=109},
    ["The Rosy Lion"]={id=2},
    ["Saint Delyn Penthouse"]={id=42},
    ["The Sleepy Sloth"]={id=118},
    ["Snowmelt Suite"]={id=77},
    ["Sugar Bowl Suite"]={id=68},
    ["Barbed Hook Private Room"]={id=4},
    ["Flaming Nix Deluxe Garret"]={id=6},
    ["Sisters of the Sands Apartment"]={id=5},
    ["Autumn's-Gate"]={id=28},
    ["Black Vine Villa"]={id=7},
    ["Captain Margaux's Place"]={id=16},
    ["Cyrodilic Jungle House"]={id=25},
    ["Hammerdeath Bungalow"]={id=31},
    ["Humblemud"]={id=10},
    ["Kragenhome"]={id=19},
    ["Moonmirth House"]={id=22},
    ["Snugpod"]={id=13},
    ["Twin Arches"]={id=34},
    ["Ald Velothi Harbor House"]={id=44},
    ["The Ample Domicile"]={id=11},
    ["Bouldertree Refuge"]={id=14},
    ["Cliffshade"]={id=8},
    ["Domus Phrasticus"]={id=26},
    ["Exorcised Coven Cottage"]={id=49},
    ["Grymharth's Woe"]={id=29},
    ["House of the Silent Magnifico"]={id=35},
    ["Mournoth Keep"]={id=32},
    ["Ravenhurst"]={id=17},
    ["Sleek Creek House"]={id=23},
    ["Velothi Reverie"]={id=20},
    ["Alinor Crest Townhouse"]={id=59},
    ["Amaya Lake Lodge"]={id=43},
    ["Bismuth Steam Baths"]={id=117},
    ["Dawnshadow"]={id=24},
    ["Emissary's Enclave"]={id=101},
    ["Forsaken Stronghold"]={id=33},
    ["Gardner House"]={id=18},
    ["The Gorinir Estate"]={id=15},
    ["Haven of the Five Companions"]={id=112},
    ["Hunding's Palatial Hall"]={id=36},
    ["Kelesan'ruhn"]={id=104},
    ["Mathiisen Manor"]={id=9},
    ["Merryvine Estate"]={id=110},
    ["Old Mistveil Manor"]={id=30},
    ["Proudspire Manor"]={id=78},
    ["Quondam Indorilia"]={id=21},
    ["Stay-Moist Mansion"]={id=12},
    ["Strident Springs Demesne"]={id=27},
    ["Water's Edge"]={id=88},
    ["Coldharbour Surreal Estate"]={id=47},
    ["Daggerfall Overlook"]={id=38},
    ["Doomchar Plateau"]={id=90},
    ["Ebonheart Chateau"]={id=39},
    ["Grand Gallery of Tamriel"]={id=114},
    ["Hakkvild's High Hall"]={id=48},
    ["Hall of the Lunar Champion"]={id=70},
    ["Serenity Falls Estate"]={id=37},
    ["Wildgrown Chapel of Julianos"]={id=121},
    ["Agony's Ascent"]={id=93},
    ["Antiquarian's Alpine Gallery"]={id=81},
    ["Bastion Sanguinaris"]={id=79},
    ["Castle Skingrad"]={id=116},
    ["Colossal Aldmeri Grotto"]={id=60},
    ["Cradle of the Worm Colossus"]={id=122},
    ["Druidspring Conservatory"]={id=123},
    ["Earthtear Cavern"]={id=41},
    ["Elinhir Private Arena"]={id=66},
    ["Enchanted Snow Globe Home"]={id=63},
    ["The Erstwhile Sanctuary"]={id=56},
    ["The Fair Winds"]={id=99},
    ["Fogbreak Lighthouse"]={id=98},
    ["Forgemaster Falls"]={id=75},
    ["Frostvault Chasm"]={id=65},
    ["Gladesong Arboretum"]={id=105},
    ["Grand Psijic Villa"]={id=62},
    ["Grand Topal Hideaway"]={id=40},
    ["Hiddenspring Cottage"]={id=120},
    ["Highhallow Hold"]={id=96},
    ["Hunter's Glade"]={id=61},
    ["Jode's Embrace"]={id=69},
    ["Kthendral Deep Mines"]={id=113},
    ["Kushalit Sanctuary"]={id=85},
    ["Lakemire Xanmeer Manor"]={id=64},
    ["Linchal Grand Manor"]={id=46},
    ["Lucky Cat Landing"]={id=73},
    ["Moon-Sugar Meadow"]={id=71},
    ["The Orbservatory Prior"]={id=55},
    ["Ossa Accentium"]={id=92},
    ["Pantherfang Chapel"]={id=89},
    ["Pariah's Pinnacle"]={id=54},
    ["Potentate's Retreat"]={id=74},
    ["Princely Dawnlight Palace"]={id=57},
    ["Seabloom Villa"]={id=111},
    ["Seaveil Spire"]={id=94},
    ["Shadow Queen's Labyrinth"]={id=102},
    ["Shalidor's Shrouded Realm"]={id=82},
    ["Shattered Mirror Isle"]={id=115},
    ["Stillwaters Retreat"]={id=80},
    ["Stone Eagle Aerie"]={id=83},
    ["Sweetwater Cascades"]={id=91},
    ["Sword-Singer's Redoubt"]={id=103},
    ["Tel Galen"]={id=45},
    ["Theater of the Ancestors"]={id=119},
    ["Thieves' Oasis"]={id=76},
    ["Tower of Unutterable Truths"]={id=106},
    ["Varlaisvea Ayleid Ruins"]={id=86},
    ["Willowpond Haven"]={id=107},
    ["Wraithhome"]={id=72},
    ["Zhan Khaj Crest"]={id=108},
    ["Buccaneer Bay"]={id=125},
    ["Night's Den"]={id=124},
}

-- ===============================
-- UI CREATION with ScrollList
-- ===============================
HTH.controls = {}

function HTH:CreateWindow()
    local wm = WINDOW_MANAGER

    local win = wm:CreateTopLevelWindow("HTH_Window")
    win:SetDimensions(1000, 700)
    win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    win:SetHidden(true)
    win:SetMovable(true)
    win:SetMouseEnabled(true)

    local bg = wm:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0,0,0,0.85)

    local title = wm:CreateControl(nil, win, CT_LABEL)
    title:SetAnchor(TOP, win, TOP, 0, 20)
    title:SetFont("ZoFontGamepadHuge")
    title:SetScale(3.5)
    title:SetText("Home Tour History")

    -- Scroll list container
    local scroll = wm:CreateControlFromVirtual(nil, win, "ZO_ScrollContainer")
    scroll:SetAnchor(TOPLEFT, win, TOPLEFT, 20, 80)
    scroll:SetDimensions(960, 580)
    local content = scroll:GetNamedChild("ScrollChild")
    content:SetAnchor(TOPLEFT)
    content:SetWidth(960)

    self.controls.window = win
    self.controls.scroll = scroll
    self.controls.content = content
end

-- ===============================
-- Master List Population using ZO_ScrollList
-- ===============================
function HTH:UpdateMasterListWindow()
    if not self.controls.scroll then return end

    local scrollList = self.controls.scroll
    local content = self.controls.content

    -- Remove old labels (clean up)
    for _, lbl in ipairs(self.controls.labels or {}) do
        lbl:SetHidden(true)
        lbl:SetParent(nil)
    end
    self.controls.labels = {}

    -- Sort house names alphabetically
    local houseNames = {}
    for name,_ in pairs(HTH.MASTER_HOUSES) do table.insert(houseNames, name) end
    table.sort(houseNames)

    local y = 0
    local lineHeight = 40

    for _, houseName in ipairs(houseNames) do
        local data = HTH.MASTER_HOUSES[houseName]
        local lbl = WINDOW_MANAGER:CreateControl(nil, content, CT_LABEL)
        lbl:SetAnchor(TOPLEFT, content, TOPLEFT, 0, y)
        lbl:SetFont("ZoFontGamepad")
        lbl:SetScale(1.5)
        lbl:SetWidth(940)
        lbl:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        lbl:SetText(string.format("%s | ID: %d", houseName, data.id))

        table.insert(self.controls.labels, lbl)
        y = y + lineHeight
    end

    -- Update scroll child height for scrolling
    content:SetHeight(y)
end

-- ===============================
-- HISTORY FUNCTIONS
-- ===============================
function HTH:SaveCurrentHouse()
    local hid = GetCurrentZoneHouseId()
    if not hid or hid == 0 then
        d("[HTH] Not inside a house.")
        return
    end

    table.insert(HTH_Saved.history, 1, {
        id = hid,
        time = GetTimeStamp(),
    })

    if #HTH_Saved.history > 50 then
        table.remove(HTH_Saved.history)
    end

    d("[HTH] House saved.")
end

function HTH:ShowHistory()
    d("---- Home Tour History ----")
    if #HTH_Saved.history == 0 then
        d("No houses saved yet.")
        return
    end

    for i=1, math.min(6, #HTH_Saved.history) do
        local h = HTH_Saved.history[i]
        local name = "Unknown House"

        -- Look up name from MASTER_HOUSES
        for houseName, data in pairs(HTH.MASTER_HOUSES) do
            if data.id == h.id then
                name = houseName
                break
            end
        end

        d(string.format("%d) %s |H1:housing:%d|hID %d|h", i, name, h.id, h.id))
    end
end

function HTH:ClearHistory()
    HTH_Saved.history = {}
    d("[HTH] History cleared.")
end

-- ===============================
-- SLASH COMMANDS
-- ===============================
SLASH_COMMANDS["/hth"] = function(arg)
    arg = arg and arg:lower() or ""

    if arg == "save" then
        HTH:SaveCurrentHouse()
    elseif arg == "history" then
        HTH:ShowHistory()
    elseif arg == "clear" then
        HTH:ClearHistory()
    else
        local win = HTH.controls.window
        if win:IsHidden() then
            HTH:UpdateMasterListWindow()
            win:SetHidden(false)
        else
            win:SetHidden(true)
        end
    end
end

-- ===============================
-- AUTO-SAVE ON FIRST ENTRY
-- ===============================
local function RegisterAutoSave()
    local hasSavedHouse = {}

    EVENT_MANAGER:RegisterForEvent(
        HTH.name,
        EVENT_PLAYER_ACTIVATED,
        function()
            -- Safety check: HTH exists and function exists
            if HTH and HTH.SaveCurrentHouse and IsInHouse() then
                local hid = GetCurrentZoneHouseId()
                if hid and hid ~= 0 and not hasSavedHouse[hid] then
                    HTH:SaveCurrentHouse()
                    hasSavedHouse[hid] = true
                end
            end
        end
    )
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= HTH.name then return end
    EVENT_MANAGER:UnregisterForEvent(HTH.name, EVENT_ADD_ON_LOADED)

    -- Ensure HTH exists globally before we do anything
    HTH.controls = HTH.controls or {}
    HTH:CreateWindow()
    HTH:UpdateMasterListWindow()

    -- Register auto-save only now
    zo_callLater(RegisterAutoSave, 1000)  -- Delay slightly to guarantee all functions exist
end

EVENT_MANAGER:RegisterForEvent(HTH.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)


-- ===============================
-- INIT
-- ===============================
local function OnAddonLoaded(event, name)
    if name ~= HTH.name then return end
    EVENT_MANAGER:UnregisterForEvent(HTH.name, EVENT_ADD_ON_LOADED)
    HTH:CreateWindow()
end

EVENT_MANAGER:RegisterForEvent(HTH.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
