local strings = {
	SI_PBSGA_EXPLANATION = "After a login the console game can come up at the default brightness while the brightness you saved in Calibrate Brightness is still stored. This add-on asks the game to apply the saved brightness again as soon as you enter the world. It cannot choose a brightness itself -- set that in the game's own Calibrate Brightness screen.",

	SI_PBSGA_RESTORE = "Restore the saved brightness at login",
	SI_PBSGA_RESTORE_TOOLTIP = "When on, as soon as you enter the world the add-on checks whether the screen is at the brightness you saved in Calibrate Brightness and, if it is not, asks the game to apply it. It looks again a few seconds later in case the game puts its own value back. Nothing is done when the two already match.",

	SI_PBSGA_NOW = "Restore the saved brightness now",
	SI_PBSGA_NOW_TOOLTIP = "Asks the game to apply the brightness you saved in Calibrate Brightness. Does nothing if the screen is already at it.",
	SI_PBSGA_NOW_BUTTON = "Restore",

	SI_PBSGA_NOTE = "If the screen does not change, type /pbgamma in chat and send the lines it prints.",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
