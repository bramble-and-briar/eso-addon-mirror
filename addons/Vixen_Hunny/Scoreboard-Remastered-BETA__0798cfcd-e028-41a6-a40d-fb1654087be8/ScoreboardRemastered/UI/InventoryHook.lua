-- "Battleground records" in the inventory, so the records dialog works anywhere,
-- not only inside a battleground.
--
--   PC (keyboard / mouse)  a button on the inventory window
--   Gamepad / console      an entry on the gamepad inventory's button bar
--                          (key chosen in settings, right stick click by default)
--
-- The dialog is pushed on top of the inventory scene, so B / Esc returns to it.
local SBR = ScoreboardRemastered
local Inv = { hookedScenes = {} }
SBR.InventoryHook = Inv

local KEYBOARD_SCENES = { "inventory" }
local GAMEPAD_SCENES = { "gamepad_inventory_root" }

function Inv:Open()
    SBR.MatchBrowser:Open("players")
end

-- PC: a button anchored above the inventory window, shown and hidden with it.
function Inv:CreateKeyboardButton()
    if self.button or not SBR.sv.inventoryButton then return end
    local parent = _G.ZO_PlayerInventory
    if not parent then return end
    local ok, button = pcall(WINDOW_MANAGER.CreateControlFromVirtual, WINDOW_MANAGER, "ScoreboardRemasteredInventoryButton", parent, "ZO_DefaultButton")
    if not ok or not button then return end
    button:SetText("Battleground records")
    button:SetDimensions(230, 30)
    button:SetAnchor(BOTTOMRIGHT, parent, TOPRIGHT, -10, -6)
    button:SetHandler("OnClicked", function() Inv:Open() end)
    button:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4)
        SetTooltipText(InformationTooltip, "Scoreboard Remastered: every player you've met in battlegrounds, and every match you've played.")
    end)
    button:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    self.button = button
end

-- Gamepad: keybind on the gamepad inventory's strip while it is showing.
function Inv:GamepadKeybind()
    if not self.keybind then
        self.keybind = {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            {
                name = "Battleground records",
                keybind = "UI_SHORTCUT_RIGHT_STICK",
                callback = function() Inv:Open() end,
            },
        }
    end
    local key = SBR.Gamepad.OPEN_KEYS[SBR.sv.inventoryKey] or SBR.Gamepad.OPEN_KEYS.right_stick
    self.keybind[1].keybind = key.keybind
    return self.keybind
end

function Inv:HookScene(name, scene, gamepad)
    if self.hookedScenes[name] or type(scene) ~= "table" or type(scene.RegisterCallback) ~= "function" then return end
    self.hookedScenes[name] = true
    scene:RegisterCallback("StateChange", function(_, newState)
        if not SBR.sv.inventoryButton then return end
        if gamepad then
            if newState == SCENE_SHOWN then
                KEYBIND_STRIP:AddKeybindButtonGroup(Inv:GamepadKeybind())
                Inv.keybindAdded = true
            elseif newState == SCENE_HIDING and Inv.keybindAdded then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(Inv.keybind)
                Inv.keybindAdded = false
            end
        elseif newState == SCENE_SHOWING then
            Inv:CreateKeyboardButton()
        end
    end)
end

function Inv:Install()
    if not SCENE_MANAGER then return end
    local function get(name)
        if SCENE_MANAGER.GetScene then return SBR.SafeCall(SCENE_MANAGER.GetScene, SCENE_MANAGER, name) end
        return SCENE_MANAGER.scenes and SCENE_MANAGER.scenes[name]
    end
    for _, name in ipairs(KEYBOARD_SCENES) do self:HookScene(name, get(name), false) end
    for _, name in ipairs(GAMEPAD_SCENES) do self:HookScene(name, get(name), true) end
    -- fall back to any gamepad inventory scene, in case the root scene is renamed
    if type(SCENE_MANAGER.scenes) == "table" then
        for name, scene in pairs(SCENE_MANAGER.scenes) do
            if type(name) == "string" and name:find("^gamepad_inventory") and not self.hookedScenes.gamepad_inventory_root then
                self:HookScene(name, scene, true)
            end
        end
    end
    self:CreateKeyboardButton()
end

function Inv:Report()
    local names = {}
    for name in pairs(self.hookedScenes) do names[#names + 1] = name end
    table.sort(names)
    SBR.Print("inventory scenes hooked: %s; PC button: %s", #names > 0 and table.concat(names, ", ") or "none",
        self.button and "yes" or "no")
end
ScoreboardRemastered.Mark("UI/InventoryHook.lua")
