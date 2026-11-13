-- BGF_Commands.lua
-- Slash commands. Each front end sets BGF.OpenUI(tab) / BGF.CloseUI().
--   /bgf                 open / close
--   /bgf browse|create|mine
--   /bgf search <text>   open Browse with a search
--   /bgf post            post / update your listing with current settings
--   /bgf remove          remove your listing
--   /bgf roles           re-run automatic roles on the draft
--   /bgf help

local BGF = BetterGroupFinderConsole
local A = BGF.Activities
local Api = BGF.Api
local L = Api.Listing

local function Open(tab)
    if BGF.OpenUI then BGF.OpenUI(tab) else BGF:Print("UI not loaded.") end
end

local function Handler(args)
    args = BGF.util.Trim(args)
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = zo_strlower(cmd or "")

    if cmd == "" then
        if BGF.ToggleUI then BGF.ToggleUI() else Open() end
    elseif cmd == "browse" or cmd == "find" then
        Open("browse")
    elseif cmd == "create" or cmd == "list" or cmd == "listing" then
        Open("create")
    elseif cmd == "mine" or cmd == "group" or cmd == "apps" then
        Open("mine")
    elseif cmd == "search" then
        BGF.sv.searchText = rest
        Open("browse")
        Api:StartSearch(BGF.sv.lastCategory)
    elseif cmd == "post" then
        L:Post()
    elseif cmd == "remove" then
        Api:RemoveListing()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if not (BGF.Settings and BGF.Settings:Open()) then
            BGF:Print("Settings: Settings > Add-ons > Better Group Finder (needs LibAddonMenu-2.0).", true)
        end
    elseif cmd == "roles" then
        L:AutoRoles(A:GetIntent(BGF.sv.lastIntent))
        BGF:Print("Roles regenerated.")
        BGF:Fire("ListingChanged")
    else
        BGF:Print("/bgf - open or close", true)
        BGF:Print("/bgf browse | create | mine - open a tab", true)
        BGF:Print("/bgf search <text> - search groups", true)
        BGF:Print("/bgf post | remove - post or remove your listing", true)
        BGF:Print("/bgf roles - regenerate roles for your draft", true)
        BGF:Print("/bgf settings - open the settings panel", true)
    end
end

BGF:OnInitialize(function()
    SLASH_COMMANDS["/bgf"] = Handler
    SLASH_COMMANDS["/bettergroupfinder"] = Handler
end)
