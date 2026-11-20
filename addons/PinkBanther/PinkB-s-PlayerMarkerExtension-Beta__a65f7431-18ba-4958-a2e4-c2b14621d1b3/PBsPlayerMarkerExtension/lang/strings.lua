-- English strings: the default. lang/jp.lua overrides them on a Japanese client (the game's language code is "jp").
PBS_PME_STRINGS = {
	banner = "%s is ready.",
	notReady = "Some parts did not start: %s",

	-- what the player is told
	notInGroup = "Extended markers go on members of your group only, and you are not in a group.",
	notMember = "Extended markers go on members of your group only. Look at a group member first.",
	notMemberSelf = "Extended markers go on members of your group or on yourself: look at a group member, or at nothing to mark yourself.",
	placed = "%s: marker %s.",
	taken = "%s: marker taken off.",
	cleared = "All markers taken off.",
	wheelClear = "Clear marker",
	texturesMissing = "%d of %d marker pictures did not load (first: %s), so they are not shown. Check that the add-on folder came with its assets folder; /pbpme status says more.",
	engineStays = "%s has the game's own marker, and it cannot be taken off: take it off first, then put the extra marker on.",
	engineWon = "%s: the game's own marker was put on, so the extra marker is off (one marker at a time).",
	testOn = "A test marker floats ahead of you for a few seconds.",
	testNoPosition = "No test marker: your position is not known (%s).",
	retried = "Forgotten what was learned about the game's calls; they are asked again.",
	texturesChecking = "Looking at whether the marker pictures load; /pbpme status shows the answer in a few seconds.",
	texturesBusy = "The pictures are being looked at already.",
	help = "/pbpme status | why | test [icon] | mark <icon> | unmark | clear | textures | retry",
	markUsage = "Usage: /pbpme mark <icon number 1-%d>",

	-- the settings panel
	note = "Look at a group member (or at nothing, for yourself) and open the marker wheel (hold D-pad right): the extra markers sit after the game's eight.",
	enabled = "Extended markers (wheel, drawing, sharing)",
	wheelSlots = "Extra markers on the wheel",
	slot = "Wheel marker %d",
	shareSend = "Send my markers to the group",
	shareReceive = "Show the group's markers",
	markSelf = "Mark myself when nothing is under the reticle",
	showSelf = "Show markers others put on me",
	frameMarks = "Show the marker in the group frames too (the names at the top left)",
	throughWalls = "Show markers through walls",
	size = "Marker size (%)",
	height = "Marker height: feet to its lower edge (cm)",
	heightPerMetre = "Extra height per metre of distance (cm)",
	facingOffset = "Marker turn (degrees; change it only if a picture looks reversed)",
	opacity = "Opacity (%)",
	sound = "Sounds",
	chat = "Messages in the chat box",
	test = "Show a test marker",
	testButton = "Test",
	clear = "Take all markers off",
	clearButton = "Clear",
	reset = "Reset to defaults",
	resetButton = "Reset",

	icons = {
		"Heart", "Diamond", "Arrow", "Exclamation", "Question", "Lightning", "Flame", "Drop",
		"Shield", "Sword", "Cross", "X", "Check", "Hexagon", "Crown", "Eye",
		"Snowflake", "Leaf", "Sun", "Target", "Flag", "Bomb", "No entry", "Vortex",
		"Red Ranger", "Blue Ranger", "Yellow Ranger", "Green Ranger", "Pink Ranger", "Black Ranger",
		"Navy Ranger", "Purple Ranger", "White Ranger", "Orange Ranger", "Silver Ranger",
	},
}

PBS_PME.MARK("strings")
