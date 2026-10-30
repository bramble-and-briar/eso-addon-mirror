local active,calls=1,0
ObsidianHUD={}
local O=ObsidianHUD
function GetActiveHotbarCategory() return active end
function GetSlotBoundId() return 0 end
function O.NoSkillAnimationsView() return false end
function O.FixedSkillRows() return true end
function O.UpdateNativePositions(only) assert(only==true); calls=calls+1 end
function O.UpdateFixedSkillBindings() end
function O.SuppressNativeSkillText() end
function O.UpdateSkillProcHighlight() end
local function label() return {SetText=function() end} end
dofile("SkillText.lua")
local skin={activeTextVisible=true,activeTextBar=1,activeTextSlot=3,
    activeTimer=label(),activeStacks=label(),button={}}
O.UpdateActiveSkillText(skin)
assert(calls==1,"empty first skill still stabilizes layout each frame")
skin.activeTextSlot=4
O.UpdateActiveSkillText(skin)
assert(calls==1,"other skills do not repeat layout work")
skin.activeTextSlot=3; active=2
O.UpdateActiveSkillText(skin)
assert(calls==1,"stale bar cannot apply layout during swap")
print("PASS: per-frame skill layout, empty first slot and swap identity guard")
