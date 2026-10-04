--[[
    Mansu's HouseBookmarks
    ----------------------
    A short list of bookmarked houses - other players' and your own - and three ways to travel
    to them:

      * /mhb prints the list in chat.  A bookmark that has a house ID is printed as one of the
        game's own housing links, |H1:housing:<house ID>:<@owner>|h[text]|h, so clicking it
        opens the game's usual "Travel to ...?" prompt.  That part is the game's doing; the
        add-on only prints the link.
      * /mhb <number> travels straight to that bookmark.
      * Five bindable keys travel to bookmarks 1 to 5.

    Made to cost as little as possible: one Lua file, no library, no window and no settings
    panel.  Nothing runs per frame, no event stays registered once the add-on is loaded, and
    the saved variables hold the bookmarks and nothing else.

    Travel is requested the way the game requests it, so the game's own rules still decide
    whether it is allowed (the owner's visitor permissions, places you cannot travel from,
    combat...).  When the server refuses, the game shows its own explanation.

    Verified against the ESO UI source (esoui 12.1.5, API 101051):
      ingame/housingeditor/housingsocial_manager.lua
          ZO_HousingSocial_Manager:VisitHouse    -> what a click on a housing link ends up doing:
                                                    RequestJumpToHouse(houseId) for your own house,
                                                    JumpToSpecificHouse(accountName, houseId, fromHouseTours)
                                                    for another player's, then SCENE_MANAGER:ShowBaseScene()
      ingame/housingeditor/houseinformation_shared.lua
          ZO_HousingBook_GetHouseLink            -> a house ID is valid when GetHouseZoneId(houseId) ~= 0;
                                                    the owner's name goes through DecorateDisplayName
          ZO_HousingBook_LinkCurrentHouseInChat  -> GetCurrentZoneHouseId() (0 = not in a house), GetCurrentHouseOwner()
      ingame/housetours/housetoursdata.lua, ingame/collections/keyboard/housingbook_keyboard.lua
          CanJumpToHouseFromCurrentLocation()    -> the game's test before it offers a house visit, and the
                                                    text it shows when the test fails
      ingame/contacts/keyboard/friendslist_keyboard.lua
          JumpToHouse(displayName)               -> "Visit Primary Residence"
      ingame/alerttext/alerthandlers.lua
          EVENT_JUMP_FAILED                      -> the game announces a failed jump itself
      libraries/utility/zo_linkhandler.lua
          the link format, ZO_LinkHandler_InsertLink

    AI disclosure: the code was generated with an AI assistant (Anthropic Claude) under the
    author's direction.

    Credits: travelling to other players' houses from a list of favourites already exists in
    Port to Friend's House (Sordrak), Go Home (static_recharge), House Hotkey (thisbeaurielle),
    Hello Tamriel - Travel Tools (Dharan-Empire) and Housing Hub (Architectura, Cardinal05).
    Their ESOUI pages were read while designing this add-on, not their code, and no code was
    taken from them.
]]

MansusHouseBookmarks = MansusHouseBookmarks or {}
local MHB = MansusHouseBookmarks

MHB.name        = "MansusHouseBookmarks"
MHB.displayName = "Mansu's HouseBookmarks"
MHB.version     = "1.0.0"

-- Bookmarks 1 to NUM_KEYS have a bindable key each (the actions are declared in Bindings.xml).
local NUM_KEYS = 5

-- This account's bookmarks on this megaserver, in the order /mhb shows them. Set when the saved
-- variables are loaded. A bookmark is
--   { owner = "@name", id = house ID (0 = the owner's primary residence), label = text or nil }
local list

-- ---------------------------------------------------------------------------
-- Localisation
-- English is the base and French replaces it line by line, so only one language stays in
-- memory. House names, "Primary Residence" and the reasons for a refused jump are the game's
-- own strings and follow the client language by themselves.
-- ---------------------------------------------------------------------------
local L =
{
    HEADER       = "Bookmarks - click a name to travel, or type /mhb <number>:",
    EMPTY        = "No bookmarks yet. Type /mhb add inside a house to bookmark it, or /mhb help for the other ways.",
    ADDED        = "Added: %s",
    EXISTS       = "Already bookmarked: %s",
    REMOVED      = "Removed: %s",
    MOVED        = "Moved: %s",
    RENAMED      = "Renamed: %s",
    NO_SUCH      = "There is no bookmark %s.",
    NOT_IN_HOUSE = "You are not in a player's house. From anywhere else: /mhb add @name [house ID] [label]",
    BAD_HOUSE    = "Unknown house ID: %s. Find it with /mhb houses <part of the house's name>.",
    NO_PRIMARY   = "You have no primary residence.",
    NO_LINK      = "A primary residence has no link: a housing link needs a house ID.",
    NO_MATCH     = "No house name contains \"%s\".",
    TRAVELLING   = "Travelling to %s",
    HELP =
    {
        "/mhb - list your bookmarks (click one to travel)",
        "/mhb <number> - travel to that bookmark",
        "/mhb add [label] - bookmark the house you are in",
        "/mhb add <housing link> [label] - bookmark a pasted housing link",
        "/mhb add @name [house ID] [label] - bookmark a player's house (no ID = primary residence)",
        "/mhb @name [house ID] - travel there without bookmarking",
        "/mhb name <number> [label] - rename a bookmark (no label = back to its default name)",
        "/mhb move <number> [position] - reorder (no position = to the top); the keys travel to bookmarks 1 to 5",
        "/mhb del <number> - remove a bookmark",
        "/mhb link <number> - put the bookmark's link in the chat box, to share it",
        "/mhb houses <text> - the IDs of the houses whose name contains the text",
        "Keys: Controls > Keybindings > Mansu's HouseBookmarks.",
    },
}

-- The lines of L.HELP that are also the answer to a command given the wrong arguments
local HELP_GO, HELP_VISIT, HELP_NAME, HELP_MOVE, HELP_DEL, HELP_LINK, HELP_HOUSES = 2, 6, 7, 8, 9, 10, 11

local isFrench = GetCVar("language.2") == "fr"

if isFrench then
    L.HEADER       = "Favoris - cliquez sur un nom pour voyager, ou tapez /mhb <numéro> :"
    L.EMPTY        = "Aucun favori pour l'instant. Tapez /mhb add dans une maison pour l'enregistrer, ou /mhb help pour les autres façons de faire."
    L.ADDED        = "Ajouté : %s"
    L.EXISTS       = "Déjà dans les favoris : %s"
    L.REMOVED      = "Supprimé : %s"
    L.MOVED        = "Déplacé : %s"
    L.RENAMED      = "Renommé : %s"
    L.NO_SUCH      = "Il n'y a pas de favori %s."
    L.NOT_IN_HOUSE = "Vous n'êtes pas dans la maison d'un joueur. Depuis ailleurs : /mhb add @nom [ID de maison] [libellé]"
    L.BAD_HOUSE    = "ID de maison inconnu : %s. Trouvez-le avec /mhb houses <partie du nom de la maison>."
    L.NO_PRIMARY   = "Vous n'avez pas de résidence principale."
    L.NO_LINK      = "Une résidence principale n'a pas de lien : un lien de maison a besoin d'un ID de maison."
    L.NO_MATCH     = "Aucun nom de maison ne contient « %s »."
    L.TRAVELLING   = "Voyage vers %s"
    L.HELP =
    {
        "/mhb - affiche vos favoris (cliquez sur l'un d'eux pour voyager)",
        "/mhb <numéro> - voyage vers ce favori",
        "/mhb add [libellé] - enregistre la maison où vous êtes",
        "/mhb add <lien de maison> [libellé] - enregistre un lien de maison collé",
        "/mhb add @nom [ID de maison] [libellé] - enregistre la maison d'un joueur (sans ID = résidence principale)",
        "/mhb @nom [ID de maison] - voyage sans enregistrer",
        "/mhb name <numéro> [libellé] - renomme un favori (sans libellé = retour à son nom par défaut)",
        "/mhb move <numéro> [position] - réordonne (sans position = en tête) ; les touches voyagent vers les favoris 1 à 5",
        "/mhb del <numéro> - supprime un favori",
        "/mhb link <numéro> - place le lien du favori dans la zone de saisie de la discussion, pour le partager",
        "/mhb houses <texte> - les ID des maisons dont le nom contient le texte",
        "Touches : Commandes > Raccourcis > Mansu's HouseBookmarks.",
    }
end

-- Names shown under Controls > Keybindings (must exist before the keybindings UI is built)
do
    local travel, show = "Travel to bookmark %d", "List bookmarks in chat"
    if isFrench then
        travel, show = "Voyager vers le favori %d", "Afficher les favoris dans la discussion"
    end
    for index = 1, NUM_KEYS do
        ZO_CreateStringId("SI_BINDING_NAME_MANSUSHOUSEBOOKMARKS_GO_" .. index, travel:format(index))
    end
    ZO_CreateStringId("SI_BINDING_NAME_MANSUSHOUSEBOOKMARKS_LIST", show)
end

-- ---------------------------------------------------------------------------
-- Chat and alerts
-- ---------------------------------------------------------------------------
local function Print(text)
    CHAT_ROUTER:AddSystemMessage(text)
end

local function Msg(text)
    Print("|c00BFFFMHB|r " .. text)
end

-- Top-right corner, like the game's own refusals. Only for texts without anything the player
-- typed in them: ZO_Alert runs its text through the game's formatter.
local function AlertError(text)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.GENERAL_ALERT_ERROR, text)
end

-- ---------------------------------------------------------------------------
-- Houses and bookmarks
-- ---------------------------------------------------------------------------
local function IsSelf(owner)
    return owner:lower() == GetDisplayName():lower()
end

-- The same test as the game's ZO_HousingBook_GetHouseLink: a house ID is real when it has a zone.
local function IsHouse(houseId)
    return houseId > 0 and houseId < 100000 and GetHouseZoneId(houseId) ~= 0
end

-- The house's name in the client language, "" when there is none.
local function GetHouseName(houseId)
    local collectibleId = GetCollectibleIdForHouse(houseId)
    if not collectibleId or collectibleId == 0 then
        return ""
    end
    return zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleName(collectibleId))
end

-- "@name" from what was typed, what a link carries or what the game reports, without the
-- characters of the link syntax. Returns nothing when no name is left.
local function CleanOwner(text)
    text = DecorateDisplayName((text:gsub("[|:]", "")))
    if #text > 1 then
        return text
    end
end

-- Free text typed by the player. Colour codes are removed, then any "|" left: it would break
-- the link the label is shown in. Returns nothing when no text is left.
local function CleanLabel(text)
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):match("^%s*(.-)%s*$")
    if text ~= "" then
        return text
    end
end

-- What a bookmark is called and where it leads:
--   title = its label, else the house's name, else its owner (a primary residence without label)
--   place = the house's name, or "Primary Residence"
local function Describe(entry)
    local place
    if entry.id == 0 then
        place = GetString(SI_HOUSING_PRIMARY_RESIDENCE_HEADER)
    else
        place = GetHouseName(entry.id)
    end

    local title = entry.label
    if not title then
        title = entry.id ~= 0 and place ~= "" and place or entry.owner
    end
    return title, place
end

-- One line of the list. With a house ID the title is a housing link, which the game makes
-- clickable; a primary residence has no ID, so no link can be made for it.
local function FormatEntry(index, entry)
    local title, place = Describe(entry)

    local details = entry.owner
    if title == entry.owner then
        details = place
    elseif title ~= place and place ~= "" then
        details = details .. " - " .. place
    end

    if entry.id ~= 0 then
        title = ("|H1:housing:%d:%s|h[%s]|h"):format(entry.id, entry.owner, title)
    end
    return ("%d. %s  |c909090%s|r"):format(index, title, details)
end

-- ---------------------------------------------------------------------------
-- Travel
-- ---------------------------------------------------------------------------
-- houseId 0 = the owner's primary residence. Returns true when the jump was requested; if the
-- server then refuses it, the game says why by itself.
local function Travel(owner, houseId, title)
    -- The game's own test before it offers a house visit, and its own text when the test fails.
    if not CanJumpToHouseFromCurrentLocation() then
        AlertError(GetString(SI_COLLECTIONS_CANNOT_JUMP_TO_HOUSE_FROM_LOCATION))
        return false
    end

    if IsSelf(owner) then
        if houseId == 0 then
            houseId = GetHousingPrimaryHouse()
            if houseId == 0 then
                AlertError(L.NO_PRIMARY)
                return false
            end
        end
        RequestJumpToHouse(houseId)
    elseif houseId == 0 then
        JumpToHouse(owner)
    else
        local FROM_HOUSE_TOURS = false
        JumpToSpecificHouse(owner, houseId, FROM_HOUSE_TOURS)
    end
    SCENE_MANAGER:ShowBaseScene() -- closes an open menu, as the game does after its own house jumps

    Msg(L.TRAVELLING:format(title))
    return true
end

-- The keys and /mhb <number>
function MHB.Go(index)
    local entry = list and list[index]
    if not entry then
        AlertError(L.NO_SUCH:format(tostring(index)))
        return false
    end
    return Travel(entry.owner, entry.id, (Describe(entry)))
end

-- /mhb @name [house ID]
local function Visit(owner, text)
    owner = CleanOwner(owner)
    if not owner then
        Msg(L.HELP[HELP_VISIT])
        return
    end

    local houseId, title = 0, owner
    if text ~= "" then
        houseId = tonumber(text:match("^%d+$"))
        if not houseId or not IsHouse(houseId) then
            Msg(L.BAD_HOUSE:format(text))
            return
        end
        title = owner .. " - " .. GetHouseName(houseId)
    end
    Travel(owner, houseId, title)
end

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------
-- The "List bookmarks" key and /mhb
function MHB.List()
    if not list then
        return
    end
    if #list == 0 then
        Msg(L.EMPTY)
        return
    end
    Msg(L.HEADER)
    for index, entry in ipairs(list) do
        Print(FormatEntry(index, entry))
    end
end

-- /mhb add ...
local function Add(text)
    local owner, houseId, label

    local linkHouseId, linkData, linkText, afterLink = text:match("|H%d:housing:(%d+)([^|]*)|h(.-)|h%s*(.*)$")
    if linkHouseId then
        -- a pasted housing link; without an owner it means a house of your own, as in the game.
        -- Its text becomes the label unless another one is typed after it.
        houseId = tonumber(linkHouseId)
        owner = linkData:match("^:([^:]+)") or GetDisplayName()
        label = afterLink ~= "" and afterLink or linkText:match("^%[(.*)%]$") or linkText
    elseif text:sub(1, 1) == "@" then
        -- @name [house ID] [label]; a number only counts as the house ID when it stands alone
        owner, label = text:match("^(%S+)%s*(.*)$")
        local typedHouseId, afterHouseId = (label .. " "):match("^(%d+)%s+(.-)%s*$")
        if typedHouseId then
            houseId, label = tonumber(typedHouseId), afterHouseId
        else
            houseId = 0
        end
    else
        -- the house the player is in; a preview has no owner
        houseId, owner, label = GetCurrentZoneHouseId(), GetCurrentHouseOwner(), text
        if houseId == 0 then
            owner = ""
        end
    end

    owner = CleanOwner(owner)
    if not owner then
        Msg(L.NOT_IN_HOUSE)
        return
    end
    if houseId ~= 0 and not IsHouse(houseId) then
        Msg(L.BAD_HOUSE:format(tostring(houseId)))
        return
    end

    for index, entry in ipairs(list) do
        if entry.id == houseId and entry.owner:lower() == owner:lower() then
            Msg(L.EXISTS:format(FormatEntry(index, entry)))
            return
        end
    end

    local entry = { owner = owner, id = houseId, label = CleanLabel(label) }
    list[#list + 1] = entry
    Msg(L.ADDED:format(FormatEntry(#list, entry)))
end

-- Reads the bookmark number that starts text; the number must stand alone ("2x" is not 2).
-- Returns its index and what follows it, or nothing after telling the player what is wrong
-- (helpLine = the command's line in L.HELP).
local function ReadIndex(text, helpLine)
    local number, rest = (text .. " "):match("^(%d+)%s+(.-)%s*$")
    if not number then
        Msg(L.HELP[helpLine])
        return
    end
    local index = tonumber(number)
    if not list[index] then
        Msg(L.NO_SUCH:format(number))
        return
    end
    return index, rest
end

-- /mhb del <number>
local function Remove(text)
    local index, rest = ReadIndex(text, HELP_DEL)
    if not index then
        return
    end
    if rest ~= "" then
        Msg(L.HELP[HELP_DEL])
        return
    end

    local line = FormatEntry(index, list[index])
    table.remove(list, index)
    Msg(L.REMOVED:format(line))
end

-- /mhb move <number> [position]
local function Move(text)
    local from, rest = ReadIndex(text, HELP_MOVE)
    if not from then
        return
    end
    local to = 1
    if rest ~= "" then
        to = tonumber(rest:match("^%d+$"))
        if not to then
            Msg(L.HELP[HELP_MOVE])
            return
        end
    end

    to = math.max(1, math.min(to, #list))
    table.insert(list, to, table.remove(list, from))
    Msg(L.MOVED:format(FormatEntry(to, list[to])))
end

-- /mhb name <number> [label]
local function Rename(text)
    local index, label = ReadIndex(text, HELP_NAME)
    if index then
        list[index].label = CleanLabel(label)
        Msg(L.RENAMED:format(FormatEntry(index, list[index])))
    end
end

-- /mhb link <number>: the game's own link for that house, placed in the chat box
local function Link(text)
    local index, rest = ReadIndex(text, HELP_LINK)
    if not index then
        return
    end
    if rest ~= "" then
        Msg(L.HELP[HELP_LINK])
        return
    end

    local entry = list[index]
    if entry.id == 0 then
        Msg(L.NO_LINK)
        return
    end
    ZO_LinkHandler_InsertLink(GetHousingLink(entry.id, entry.owner, LINK_STYLE_BRACKETS))
end

-- /mhb houses <text>: "house ID - name" for every house whose name contains the text
local function PrintHouses(text)
    if text == "" then
        Msg(L.HELP[HELP_HOUSES])
        return
    end

    local filter = text:lower()
    local found = false
    for index = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_HOUSE) do
        local collectibleId = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_HOUSE, index)
        local houseName = zo_strformat(SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleName(collectibleId))
        if houseName:lower():find(filter, 1, true) then
            Print(("%d - %s"):format(GetCollectibleReferenceId(collectibleId), houseName))
            found = true
        end
    end
    if not found then
        Msg(L.NO_MATCH:format(text))
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
local function PrintHelp()
    Msg(MHB.displayName .. " " .. MHB.version)
    for _, line in ipairs(L.HELP) do
        Print(line)
    end
end

local function OnSlashCommand(args)
    local command, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local lower = command:lower()

    if command == "" or lower == "list" then
        MHB.List()
    elseif command:find("^%d+$") then
        if rest == "" then
            MHB.Go(tonumber(command))
        else
            Msg(L.HELP[HELP_GO])
        end
    elseif command:sub(1, 1) == "@" then
        Visit(command, rest)
    elseif lower == "add" then
        Add(rest)
    elseif lower == "del" or lower == "delete" or lower == "remove" then
        Remove(rest)
    elseif lower == "move" then
        Move(rest)
    elseif lower == "name" or lower == "rename" then
        Rename(rest)
    elseif lower == "link" or lower == "share" then
        Link(rest)
    elseif lower == "houses" then
        PrintHouses(rest)
    else
        PrintHelp()
    end
end

-- ---------------------------------------------------------------------------
-- Initialisation
-- ---------------------------------------------------------------------------
local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= MHB.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(MHB.name, EVENT_ADD_ON_LOADED)

    -- MansusHouseBookmarksSV[megaserver][account] = the list. NA and EU share one file, and a
    -- player's houses are not the same on both.
    local saved = MansusHouseBookmarksSV
    if type(saved) ~= "table" then
        saved = {}
        MansusHouseBookmarksSV = saved
    end
    local world, account = GetWorldName(), GetDisplayName()
    if type(saved[world]) ~= "table" then
        saved[world] = {}
    end

    -- Rebuild the list from what was saved, keeping the well-formed bookmarks in their order,
    -- in case the file was edited by hand (a deleted line leaves a gap in the numbering).
    list = {}
    local stored = saved[world][account]
    if type(stored) == "table" then
        local positions = {}
        for position in pairs(stored) do
            if type(position) == "number" then
                positions[#positions + 1] = position
            end
        end
        table.sort(positions)

        for _, position in ipairs(positions) do
            local entry = stored[position]
            local owner = type(entry) == "table" and type(entry.owner) == "string" and CleanOwner(entry.owner)
            if owner and type(entry.id) == "number" and entry.id >= 0 and entry.id < 100000 and entry.id == math.floor(entry.id) then
                list[#list + 1] =
                {
                    owner = owner,
                    id = entry.id,
                    label = type(entry.label) == "string" and CleanLabel(entry.label) or nil,
                }
            end
        end
    end
    saved[world][account] = list

    SLASH_COMMANDS["/mhb"] = OnSlashCommand
    SLASH_COMMANDS["/housebookmarks"] = OnSlashCommand
end

EVENT_MANAGER:RegisterForEvent(MHB.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
