-- English, and the base every other language file overrides.
local strings = {
	SI_PBSWT_CUE = "LA > Skill",
	SI_PBSWT_BLOCK = "BLOCK",
	SI_PBSWT_BLOCK_OK = "OK",
	SI_PBSWT_BLOCK_TIME = "Skill > Block  %d ms",
	SI_PBSWT_TOTAL = "Total  %d ms",
	SI_PBSWT_EXCELLENT = "EXCELLENT!",
	SI_PBSWT_WOVE = "LA > Skill  %d ms",
	SI_PBSWT_NO_LA = "No light attack",

	SI_PBSWT_EXPLANATION = "Shows timing only. Every light attack, skill and block is still your own button press -- nothing is pressed for you.",

	SI_PBSWT_SECTION_METRONOME = "Weave metronome",
	SI_PBSWT_METRONOME = "Show the metronome",
	SI_PBSWT_METRONOME_TOOLTIP = "A bar that fills over one skill cycle, counted from your last skill. The bright zone at its end is when to light attack and then cast.",
	SI_PBSWT_SOUND = "Tick when the zone starts",
	SI_PBSWT_SOUND_TOOLTIP = "Plays a short tick as the bar enters the light-attack zone.",
	SI_PBSWT_CYCLE = "Cycle length (ms)",
	SI_PBSWT_CYCLE_TOOLTIP = "The global cooldown is 1000 ms. Raise it a little if your ping makes the bar run ahead of the game.",
	SI_PBSWT_LEAD = "Light-attack zone (ms)",
	SI_PBSWT_LEAD_TOOLTIP = "How long before the end of the cycle the zone begins.",
	SI_PBSWT_COMBAT_ONLY = "Only in combat",
	SI_PBSWT_COMBAT_ONLY_TOOLTIP = "Off, the bar also runs for a few seconds after a skill used out of combat, for practice on a target dummy.",

	SI_PBSWT_SECTION_BLOCK = "Block-cancel window",
	SI_PBSWT_BLOCKCUE = "Flash after a skill",
	SI_PBSWT_BLOCKCUE_TOOLTIP = "Right after an instant skill, flashes BLOCK for the window below, and OK when you block in time. If a light attack came before that skill, blocking in time shows EXCELLENT! instead: light attack > skill > block, all in one chain. Under the box: the time from the skill to the block, and for EXCELLENT! the total from the light attack to the block. Channelled and cast-time skills are skipped, because blocking would interrupt them.",
	SI_PBSWT_WINDOW = "Window (ms)",
	SI_PBSWT_WINDOW_TOOLTIP = "How long BLOCK stays up after the skill.",

	SI_PBSWT_SECTION_POSITION = "Position",
	SI_PBSWT_OFFSET_X = "Horizontal offset",
	SI_PBSWT_OFFSET_Y = "Vertical offset",
	SI_PBSWT_RESET = "Reset all settings",
	SI_PBSWT_RESET_BUTTON = "Reset",

	SI_PBSWT_LOADED = "PB's Weave & Block Trainer %s loaded. /weave for commands.",
	SI_PBSWT_HELP = "/weave on | off -- show or hide everything\n/weave debug -- log skill, light attack and block events to chat",
	SI_PBSWT_ON = "Weave & Block Trainer on.",
	SI_PBSWT_OFF = "Weave & Block Trainer off.",
	SI_PBSWT_DEBUG_ON = "Debug log on.",
	SI_PBSWT_DEBUG_OFF = "Debug log off.",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
