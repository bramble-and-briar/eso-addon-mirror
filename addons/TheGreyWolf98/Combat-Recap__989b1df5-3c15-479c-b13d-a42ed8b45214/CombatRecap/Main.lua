local C = CombatRecap
local function command(args)
    args = (args or ""):lower():match("^%s*(.-)%s*$")
    if args == "help" then
        d("Combat Recap 1.0.1: /recap opens latest fight; /recap N opens history N (1 = latest).")
        d("/recap chat on|off controls qualifying fight announcements.")
        d("/recap stop saves the current fight; /recap clear confirm deletes this character's history.")
        d("A: view build / combat report. X: next rows. Y: next fight. B: back. Personal damage + pets; no companions/group.")
    elseif args == "chat on" then
        C.saved.automaticChat = true; d("Combat Recap: automatic boss/champion/dummy chat ON.")
    elseif args == "chat off" then
        C.saved.automaticChat = false; d("Combat Recap: automatic chat OFF; /recap still works.")
    elseif args == "stop" then
        C.Tracker:Finish("Manually stopped")
        C.Tracker.suspended = IsUnitInCombat("player")
    elseif args == "clear confirm" then
        if C.Tracker.fight then d("Combat Recap: finish recording before clearing history."); return end
        C.saved.history = {}; d("Combat Recap: this character's history cleared.")
        if C.UI.window and SCENE_MANAGER:IsShowing("combatRecap") then C.UI:Refresh() end
    elseif args == "clear" then
        d("Combat Recap: /recap clear confirm deletes this character's 20-fight history.")
    elseif args == "" or tonumber(args) then C.UI:Open(tonumber(args))
    else d("Combat Recap: unknown command. Type /recap help.") end
end

local function loaded(_, name)
    if name ~= "CombatRecap" then return end
    EVENT_MANAGER:UnregisterForEvent("CombatRecap_Load", EVENT_ADD_ON_LOADED)
    C.saved = ZO_SavedVars:NewCharacterIdSettings("CombatRecapSavedVariables", 1, nil,
        { history = {}, automaticChat = true }, GetWorldName())
    while #C.saved.history > C.LIMITS.history do table.remove(C.saved.history) end
    C.Tracker:Initialize()
    SLASH_COMMANDS["/recap"] = command
    d("|cD85757Combat Recap 1.0.1|r loaded. /recap help")
end
EVENT_MANAGER:RegisterForEvent("CombatRecap_Load", EVENT_ADD_ON_LOADED, loaded)
