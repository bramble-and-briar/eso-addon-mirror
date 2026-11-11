-- ESO API adapter/flow tests. This does not simulate the native renderer.
dofile("Core.lua")
local checks = 0
local function eq(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, (message or "Mismatch") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local constants = {"ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_DAMAGE_SHIELDED", "ACTION_RESULT_KILLING_BLOW", "ACTION_RESULT_DIED_XP", "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET", "COMBAT_UNIT_TYPE_PLAYER_COMPANION", "COMBAT_UNIT_TYPE_OTHER", "COMBAT_UNIT_TYPE_GROUP", "COMBAT_UNIT_TYPE_TARGET_DUMMY", "EVENT_ADD_ON_LOADED", "EVENT_COMBAT_EVENT", "EVENT_RETICLE_TARGET_CHANGED", "EVENT_PLAYER_ACTIVATED", "EVENT_PLAYER_COMBAT_STATE", "ACTION_RESULT_DIED", "ACTION_RESULT_DIED_COMPANION_XP"}
for i, key in ipairs(constants) do _G[key] = i end
EVENT_MANAGER = {RegisterForEvent = function() end, UnregisterForEvent = function() end, RegisterForUpdate = function() end}
local day, seconds, stamp, frame, pvp = 20261109, 86399, 1794268799, 1, false
function GetDate() return day end
function GetSecondsSinceMidnight() return seconds end
function GetTimeStamp() return stamp end
function GetFrameTimeSeconds() return frame end
function GetUnitZone() return "Auridon" end
function GetUnitWorldPosition() return 557, 0, 0, 0 end
function GetParentZoneId(id) return id end
function GetZoneNameById(id) return "Zone " .. id end
function GetWorldName() return "EU Megaserver" end
function IsInAvAZone() return pvp end
function IsActiveWorldBattleground() return false end
function IsUnitInCombat() return false end
function zo_strformat(_, value) return (value:gsub("%^.*", "")) end
function ZO_LabelUtils_GetTextDimensions() return 240, 90 end
GuiRoot = {GetWidth = function() return 1920 end, GetHeight = function() return 1080 end}
dofile("Main.lua")
local A = AddKillCounter
A.sv = {enabled = true, includePets = true, includeCompanion = true, participation = false, targetZoneId = 557, targetZoneName = "Zone 557", stats = A.Core.NewStats()}
A.session = 0; A.characterName = "Testchar"; A:ResetRuntime()
local function event(result, id, name, source, target)
    A:OnCombat(nil, result, false, "Test", 0, 0, "Testchar", source or COMBAT_UNIT_TYPE_PLAYER,
        name or "Skelett^m", target or COMBAT_UNIT_TYPE_OTHER, 50, 0, 0, false, 1, id)
end
event(ACTION_RESULT_KILLING_BLOW, 10)
eq(A.sv.stats.total, 1, "Own kill")
eq(A.sv.stats.enemies, nil, "No enemy-name storage")
event(ACTION_RESULT_KILLING_BLOW, 10)
event(ACTION_RESULT_DIED_XP, 10)
eq(A.sv.stats.total, 1, "Duplicate kill notifications")
event(ACTION_RESULT_KILLING_BLOW, 11, "Wolf", COMBAT_UNIT_TYPE_PLAYER_PET)
eq(A.sv.stats.total, 2, "Pet kill")
A.sv.includePets = false
event(ACTION_RESULT_KILLING_BLOW, 12, "Wolf", COMBAT_UNIT_TYPE_PLAYER_PET)
eq(A.sv.stats.total, 2, "Pet toggle")
event(ACTION_RESULT_KILLING_BLOW, 13, "Wolf", COMBAT_UNIT_TYPE_PLAYER_COMPANION)
eq(A.sv.stats.total, 3, "Companion kill")
event(ACTION_RESULT_KILLING_BLOW, 14, "Wolf", COMBAT_UNIT_TYPE_OTHER)
eq(A.sv.stats.total, 3, "Other player's kill excluded")
A.sv.enabled = false; event(ACTION_RESULT_KILLING_BLOW, 15)
eq(A.sv.stats.total, 3, "Pause")
A.sv.enabled = true; pvp = true; event(ACTION_RESULT_KILLING_BLOW, 16)
eq(A.sv.stats.total, 3, "PvP excluded")
pvp = false; event(ACTION_RESULT_KILLING_BLOW, 17, "Dummy", nil, COMBAT_UNIT_TYPE_TARGET_DUMMY)
eq(A.sv.stats.total, 3, "Dummy excluded")
A.sv.participation = true
event(ACTION_RESULT_DAMAGE, 18, "Zombie")
event(ACTION_RESULT_DIED_XP, 18, "", COMBAT_UNIT_TYPE_OTHER)
eq(A.sv.stats.total, 4, "Participation resolves missing name")
event(ACTION_RESULT_KILLING_BLOW, 18, "Zombie")
eq(A.sv.stats.total, 4, "Participation then blow dedup")
event(ACTION_RESULT_DIED_XP, 19, "Nearby wolf", COMBAT_UNIT_TYPE_OTHER)
eq(A.sv.stats.total, 4, "Unrelated XP excluded")
day = 20261110; seconds = 0; stamp = stamp + 1
event(ACTION_RESULT_KILLING_BLOW, 20, "Wolf")
eq(A.sv.stats.days["20261110"].total, 1, "Local midnight")
eq(A.sv.stats.days["20261110"].firstTime, "00:00:00", "Clock at midnight")
eq(A.sv.stats.days["20261109"].total, 4, "Previous day retained")
A.playerNames["Opponent"] = true
event(ACTION_RESULT_KILLING_BLOW, 21, "Opponent")
eq(A.sv.stats.total, 5, "Known player excluded")
-- Minimal native-list adapter to exercise every menu view and destructive flow.
local Base = {}
function Base:Subclass() return setmetatable({}, {__index = self}) end
function Base:New(...) local o = setmetatable({}, {__index = self}); o:Initialize(...); return o end
function Base:Initialize()
    self.list = {rows = {}, index = 1}
    local l = self.list
    function l:AddEntry(_, row) self.rows[#self.rows + 1] = row end
    function l:GetSelectedIndex() return self.index end
    function l:GetTargetData() return self.rows[self.index] end
    function l:GetNumEntries() return #self.rows end
    function l:Clear() self.rows = {} end
    function l:Commit() end
    function l:SetSelectedIndexWithoutAnimation(n) self.index = n end
    self.header = {}; self:InitializeKeybindStripDescriptors()
end
function Base:GetMainList() return self.list end
function Base:SetListsUseTriggerKeybinds() end
function Base:OnSelectionChanged() end
function Base:RefreshKeybinds() end
function Base:Update() self:PerformUpdate() end
function Base:IsShowing() return true end
function Base:DeactivateCurrentList() self.testListActive = false end
function Base:ActivateCurrentList() self.testListActive = true end
ZO_Gamepad_ParametricList_Screen = Base
ZO_GamepadEntryData = {}
function ZO_GamepadEntryData:New(text)
    return {text = text, AddSubLabel = function(self, label) self.subtitle = label end, SetIconTintOnSelection = function() end, SetEnabled = function() end}
end
function ZO_GamepadGenericHeader_Refresh() end
local label = {SetText = function() end}
AddKillCounterDetailsTitle = label; AddKillCounterDetailsBody = label
ZO_Scene = {New = function() return {AddFragment = function() end, AddFragmentGroup = function() end} end}
ZO_FadeSceneFragment = {New = function() return {} end}
ZO_HUDFadeSceneFragment = {New = function() return {SetHiddenForReason = function() end} end}
FRAGMENT_GROUP = {}; ZO_MENU_ENTRIES = {}
SCENE_MANAGER = {GetScene = function() return {AddFragment = function() end} end, HideCurrentScene = function() end, Push = function() end}
-- UI controls are supplied by UI.xml in the game.
AddKillCounterHUD = {ClearAnchors = function() end, SetAnchor = function() end, SetScale = function() end, SetWidth = function(self, width) self.width = width end}
AddKillCounterHUDText = label; AddKillCounterWindow = {}; AddKillCounterDetails = {}
A.sv.hudPosition = 1; A.sv.hudScale = 1; A.sv.showHUD = true
GAMEPAD_DIALOGS = {BASIC = 1}
SI_DIALOG_CANCEL = "Abbrechen"
local dialogs, pending = {}, nil
function ZO_Dialogs_RegisterCustomDialog(name, definition) dialogs[name] = definition end
function ZO_Dialogs_ShowGamepadDialog(name, data)
    pending = {definition = assert(dialogs[name]), data = data}
end
local function finishDialog(confirm)
    local dialog = assert(pending)
    local button = dialog.definition.buttons[confirm and 1 or 2]
    if button.callback then button.callback(dialog) end
    dialog.definition.finishedCallback(dialog)
    pending = nil
end
dofile("Gamepad.lua")
A:CreateUI()
eq(#ZO_MENU_ENTRIES, 0, "No separate controller main-menu entry")
local screen = A.screen
for _, kind in ipairs({"home", "days", "day"}) do
    screen.view = {kind = kind, day = "20261109", capacity = 1000, page = 1}
    screen:PerformUpdate()
    assert(screen.list:GetNumEntries() > 0, "Empty view: " .. kind)
    checks = checks + 1
end
screen.view = {kind = "home", page = 1}; screen.history = {}; screen:PerformUpdate()
screen.list.rows[1].action()
eq(screen.view.kind, "day", "Today navigation")
screen:Back(); eq(screen.view.kind, "home", "Back navigation")
screen:Navigate({kind = "days"})
local deleteKey
for _, descriptor in ipairs(screen.keybindStripDescriptor) do
    if descriptor.keybind == "UI_SHORTCUT_RIGHT_STICK" then deleteKey = descriptor end
end
assert(deleteKey, "Native R3 delete key must be registered")
eq(deleteKey.visible(), true, "R3 deletion shown on selected date")
deleteKey.callback()
eq(pending.definition.gamepadInfo.dialogType, GAMEPAD_DIALOGS.BASIC, "R3 uses ESO native basic dialog")
eq(screen.view.kind, "days", "Delete prompt does not replace list with custom page")
eq(screen.testListActive, false, "Background list deactivated while dialog is open")
finishDialog(false)
eq(screen.testListActive, true, "Cancel restores list navigation")
screen:Navigate({kind = "day", day = "20261109"})
deleteKey.callback()
eq(pending.data.day, "20261109", "Dialog stores exact selected day")
eq(A.sv.stats.total, 5, "Opening dialog does not delete statistics")
finishDialog(false)
eq(A.sv.stats.days["20261109"].total, 4, "Back cancels day deletion")
deleteKey.callback()
finishDialog(true)
eq(A.sv.stats.days["20261109"], nil, "Confirmed day removed")
eq(A.sv.stats.total, 5, "Day deletion leaves overall total intact")
eq(screen.view.kind, "days", "Deletion returns to day list")
screen:Back()
eq(screen.view.kind, "home", "Back after deletion returns to overview")
eq(deleteKey.visible(), false, "R3 delete hidden outside date views")
-- The full reset also uses ESO's native confirmation dialog.
A:RequestDeleteConfirmation("all")
finishDialog(false); eq(A.sv.stats.total, 5, "Cancel deletion")
A:RequestDeleteConfirmation("all")
eq(pending.data.kind, "all", "Full reset opens native dialog")
finishDialog(true)
eq(A.sv.stats.total, 0, "Confirmed deletion")
eq(A.sv.enabled, true, "Settings survive deletion")
eq(screen.view.kind, "home", "Reset returns home")
print("Integration: " .. checks .. " checks passed (mock ESO API; no live renderer)")
