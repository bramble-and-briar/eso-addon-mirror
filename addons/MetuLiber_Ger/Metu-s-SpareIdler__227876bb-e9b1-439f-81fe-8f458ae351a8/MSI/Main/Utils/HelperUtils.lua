-- HelperUtils.lua
if MSI == nil then MSI = MSI or {} end
local MSI = _G['MSI']

--***********--
-- TextColor
MSI.MetuRed = ZO_ColorDef:New("8B0000") MSI.Red 	= ZO_ColorDef:New("FF0000")
MSI.Green 	= ZO_ColorDef:New("00FF00") MSI.Blue 	= ZO_ColorDef:New("0000FF")
MSI.Yellow 	= ZO_ColorDef:New("EEC900") MSI.Rose 	= ZO_ColorDef:New("EFEBBE")
MSI.Brown 	= ZO_ColorDef:New("B8860B") MSI.Brown1 	= ZO_ColorDef:New("8B5A00")
MSI.Brown2 	= ZO_ColorDef:New("8B7355") MSI.Blue1 	= ZO_ColorDef:New("1874CD")
MSI.Blue2 	= ZO_ColorDef:New("778899") MSI.Orange 	= ZO_ColorDef:New("CD661D")

function MSI.Colorize(text, color)
	if not color then color = "D0D172" end
		text = string.format('|c%s%s|r', color, text)
	return text
end

--***********--
-- IsConsole
local function IsConsole()
	local p = GetUIPlatform()
	return p == UI_PLATFORM_XBOX or p == UI_PLATFORM_PS5
end
MSI.IsConsole = IsConsole

--*****************--
-- "gameMenuInGame" "inventory" "bank" "guildBank" "skills" "gamepadInteract" "achievementsGamepad" "loreLibraryGamepad" "bookSetGamepad" "lootGamepad" "repairGamepad" "lootInventoryGamepad" "enchantGamepad" "alchemy" 
-- "loreReaderInteraction" "gamepad_loreReaderInteraction" "loreReaderInventory" "gamepad_loreReaderInventory" "loreReaderLoreLibrary"  "gamepad_loreReaderLoreLibrary" "bookSetGamepad"
-- ApplyRightScene
function MSI.ApplyRightScene(givenScene)
	if givenScene == "gamepad_inventory_root" then
		--EndInteraction(INTERACTION_BOOK)
		--SCENE_MANAGER:Hide("loreLibrary")
		SCENE_MANAGER:Show("gamepad_inventory_root")
	else
		--SCENE_MANAGER:ShowBaseScene()
		SCENE_MANAGER:Show("hudui")
	end
end

-- split() split string based on given string & delimiter
function MSI.split(inputStr, seperator)
  if seperator == nil then
    seperator = "%s"
  end
  local trimstr = {}
  for str in string.gmatch(inputStr, "([^"..seperator.."]+)") do
    table.insert(trimstr, str)
  end
  return trimstr
end

--************************--
-- PlayAlertSound()
function MSI.PlayAlertSound()
  PlaySound(SOUNDS.DEATH_RECAP_ATTACK_SHOWN)
  zo_callLater(function() return PlaySound(SOUNDS.DEATH_RECAP_ATTACK_SHOWN) end, 150)
  zo_callLater(function() return PlaySound(SOUNDS.DEATH_RECAP_ATTACK_SHOWN) end, 300)
end

--************************--
-- MSI.PlayAlertBanner(message)
function MSI.PlayAlertBanner(message)
  zo_callLater(function() return CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_LARGE_TEXT, SOUNDS.INTERACT_WINDOW_OPEN, message) end, 1000)
end

function MSI.ValNameSliderOne()
    MSI.Print("d", string.format("%s %s %s", "Schiebe-Regler auf", MSI.SVars.ValNameSliderOne, "umgestellt"))
end

function MSI.ValNameSliderTwo()
    MSI.Print("d", string.format("%s %s %s", "Schiebe-Regler auf", MSI.SVars.ValNameSliderTwo, "umgestellt"))
end
-- eof