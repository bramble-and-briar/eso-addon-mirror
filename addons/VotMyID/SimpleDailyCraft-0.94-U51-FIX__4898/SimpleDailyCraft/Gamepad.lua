local SDC = SimpleDailyCraft

--Register for gamepad
function SDC.GamepadMode()
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.GamepadEvent)
end

--Convert gamepad event to pc event
local EventFun = {SDC.CraftCore, SDC.InteractCore, SDC.BankCore}
function SDC.GamepadEvent(scene, _, newstate)
  local Name = scene.name
  --Transfer
  if Name == "gamepad_smithing_root"    then Name = "smithing"    end
  if Name == "gamepad_provisioner_root" then Name = "provisioner" end
  if Name == "gamepad_enchanting_mode"  then Name = "enchanting"  end
  if Name == "gamepad_alchemy_mode"     then Name = "alchemy"     end
  if Name == "gamepadInteract"          then Name = "interact"    end
  if Name == "lootGamepad"              then Name = "loot"        end
  if Name == "gamepad_banking"          then Name = "bank"        end
  --Return for pc function
  if Name == scene.name then return end
  for i = 1, #EventFun do
    EventFun[i]({["name"] = Name}, nil, newstate)
  end
end