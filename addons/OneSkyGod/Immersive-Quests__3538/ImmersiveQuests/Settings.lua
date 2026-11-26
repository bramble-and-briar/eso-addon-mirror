-- Settings menu
local ImmQuests = ImmersiveQuests
local addOnName = ImmQuests.name
local author = ImmQuests.author
local version = ImmQuests.version

-----
-- LAM Panel
-----

local panelData = {
    type = "panel",
    name = GetString(IMMERSIVE_QUESTS_NAME),
    displayName = GetString(IMMERSIVE_QUESTS_NAME),
    author = author,
    version = version
}

local checkboxVal = false
local optionsTable = {
    {
        type = "header",
        name = "recruiting Creative Writers & Playtesters!",
        width = "full"
    }, {
        type = "description",
        title = "|cc00001Want to make ESO more immersive - reminiscent of TES3? Solve quests with lore-friendly journal directions, not just relying on compass or map waypoints. Join us as a Creative Writer or Playtester for the Immersive Quests Addon!\n|rEARN UP TO 500k GOLD|cc00001 per quest and receive Crown Crates, Crown Store Items, Homes, Motifs, Furniture and others as Rewards for your contributions!\n|rAll Donations Go To The Team!|cc00001 |r",
        width = "full"
    }, {
        type = "header",
        name = "|cff00ffVerify Directions & Provide Feedback|r",
        width = "full"
    }, {
        type = "description",
        title = "|cff00ffYou have the opportunity to provide feedback on the accuracy and effectiveness of the quest directions. If you find any misleading information, you may be eligible for a bounty of up to 250,000 Gold, and the writers would also love to hear where they excelled!|r",
        width = "full"
    }, {
        type = "header",
        name = "|cff8555Zones That Are Being Written For & Playtested|r",
        width = "full"
    }, {
        type = "description",
        title = "|cff8555Murkmire - Northen Elsweyr - West Weald - Blackwood - Telvanni Penisula - Apocrypha |r",
        width = "full"
    }, {type = "divider", width = "full"},

    {
        type = "header",
        name = "|c3CB371Zones That Are Finished|r",
        width = "full"
    }, {
        type = "description",
        title = "|c3CB371Tutorial - Aldmeri Dominion - Ebonheart Pact - Daggerfall Covenant - Coldharbour - Craglorn - Cyrodiil - Imperial City - Wrothgar - Vvardenfell - Hew's Bane: Thieves Guild - Gold Coast: Dark Brotherhood - Clockwork City - Summerset - The Reach - Solstice - Mages Guild - Glenumbra Thieves Guild - Sheogorath Takes A Holiday|r",
        width = "full"
    }, {
        type = "header",
        type = "checkbox",
        name = "Writer Mode",
        getFunc = function() return IMMERSIVE_QUESTS_VARS.settings.writer end,
        setFunc = function(value)
            IMMERSIVE_QUESTS_VARS.settings.writer = value
        end,
        tooltip = "Select this to allow recording quest data",
        width = "full"
    }, {type = "divider", width = "full"}, {
        type = "checkbox",
        name = "Account-Wide",
        getFunc = function()
            return IMMERSIVE_QUESTS_VARS.settings.megaVars
        end,
        setFunc = function(value)
            IMMERSIVE_QUESTS_VARS_MEGA_CROSS.settings.megaVars = value
            IMMERSIVE_QUESTS_VARS_MEGA.settings.megaVars = value
            IMMERSIVE_QUESTS_VARS.settings.megaVars = value

            ReloadUI()
        end,
        tooltip = "Select this to have writing saved across mega-servers (instead of per mega-server, ie per NA/EU/PTS)",
        width = "full",
        warning = "You can always switch back!\nProceeding will reload the UI.",
        default = false
    }, {type = "divider", width = "full"}, {
        type = "button",
        name = "Join Discord Team",
        func = function()
            RequestOpenUnsafeURL("https://discord.gg/vumx2FAVGZ")
        end,
        tooltip = GetString(IMMERSIVE_QUESTS_DISCORD_TOOLTIP),
        width = "half"
    }, {
        type = "button",
        name = "Direction Feedback",
        func = function()
            MAIN_MENU_KEYBOARD:ShowScene("mailSend")
            MAIL_SEND.to:SetText("@OneSkyGod")
            MAIL_SEND.subject:SetText(GetString(IMMERSIVE_QUESTS_NAME))
        end,
        -- Replace above function with this if you want to link it to the Discord instead (and replace Discord link with a valid one)
        --[[function()
				RequestOpenUnsafeURL("https://discord.gg/xxxxxxxxx")
			end]]
        tooltip = GetString(IMMERSIVE_QUESTS_BUTTON_TOOLTIP),
        width = "half"
    }, {
        type = "button",
        name = "Tutorial for Contributors",
        func = function()
            RequestOpenUnsafeURL("https://www.youtube.com/watch?v=IvJWXWKPP-I")
        end,
        tooltip = GetString(IMMERSIVE_QUESTS_YOUTUBE_TOOLTIP),
        width = "half"
    }, {
        type = "button",
        name = "Directions FlowChart",
        func = function()
            RequestOpenUnsafeURL("https://imgur.com/gallery/hb4KnWF")
        end,
        tooltip = GetString(IMMERSIVE_QUESTS_FLOWCHART),
        width = "half"
    }, {
        type = "button",
        name = "List of Immersion Addons",
        func = function()
            RequestOpenUnsafeURL(
                "https://forums.elderscrollsonline.com/en/discussion/574549/immersion-addons-and-settings-ultimate-list/p1")
        end,
        tooltip = GetString(IMMERSIVE_QUESTS_ADDONS_TOOLTIP),
        width = "half"
    }, {
        type = "header",
        name = "|c33ccccCreative Writers - Playtesters - Proofreaders:|r",
        width = "full"
    }, {
        type = "description",
        title = "|c33ccccRosque - Mouch30 -  Westrany - @ARKANOBOT - Johnyfreeman - Chaos Blaze - Devinstrike - IggyTheMad - Kayreb - BEASTESS-@KhajiitEscort - @NaomiFriz - Kalindria - Theoderic Castellanos - Cyberjanet - @Jordakai - @octavare - SaipanDamashii Mehmet - 'Marquolin' Ortaç - Martin Toms <contact@toms.click> - Nilena - Reja Craven -  Tahir - SamPhysis - JayAstrophel - Naughtyninja56 - Mannd - @Nismesis - Litinum - Immy - Szyler - HavocSource - @Aashiana - A Pro Benji - Teaji - S'vin - OneSkyGod - @Carnassia - Darktalon - @Dragneel1207 - LadyAnime - Cirrose - The Lusty Argonian Maid - @boneten - @waldjvnge - @Rekeme - @Dagoth_Ur - TJ - WishPib - Sasquehanna - @Silmuriliam - Charleevada - @thepandalore - @MatchedPython96 - Rheum - @ThatOneApple - @Tes96 - @derpy_mushroom - @ravenshadow6513 - @SoyTempeh - dampendair - Kelinmiriel - HagarDeV - Strangelove -  Yutoma - Wex - Lord Gung - Ég elska klaka - Morgan Miles - Kid-Atlantic - Gheistr - Ppgballs - Creakinator - Ra Re - BoarGules - Fadosch - @fletcherfletcher - ValashValash - doximax|r",
        width = "full"
    }, {type = "divider", width = "full"},

    {type = "header", name = "|cff00ffBenefactors:|r", width = "full"}, {
        type = "description",
        title = "DONATIONS OF GOLD, CROWNS & ART:",
        text = "|cff00ffSena Hyeleth:Digital Artist - FAEVARA : faevara.carrd.co - ArealDisciple - @Machinemonkey00 - @CMFan1966 - Morgannor - GodofShade - TheSimpJR - @liminal.exe - flaxi - Micha - LadyAnime - JHartEllis - Futerko - Crunchyraul - @Carnassia - Highland Lady @Vanillapod - @Kitten620 - B O Y E T R O N - @Xiandata  - Fugnus - Hazard - Peach - Fa-fa - Gary90 - @Kauldwin - @deek268|r",
        width = "full"
    }, {type = "divider", width = "full"}

}

function ImmQuests.LoadSettings()
    local LAM = LibAddonMenu2
    if LAM then
        LAM:RegisterAddonPanel(addOnName, panelData)
        LAM:RegisterOptionControls(addOnName, optionsTable)
    end
end
