-- English, and the base every other language file overrides.
local strings = {
	SI_PBSES_EXPLANATION = "When the group leader plays an emote, the members play the same one. Everybody needs this add-on, the leader included. Members only play emotes they own, and only while out of combat.",

	SI_PBSES_SECTION_SYNC = "Synchronisation",
	SI_PBSES_ENABLED = "Turn the add-on on",
	SI_PBSES_ENABLED_TOOLTIP = "Off: nothing is sent and nothing is played.",
	SI_PBSES_SEND = "Send my emotes when I am the leader",
	SI_PBSES_SEND_TOOLTIP = "While you lead a group, every emote you play is sent to the group.",
	SI_PBSES_FOLLOW = "Play the leader's emotes",
	SI_PBSES_FOLLOW_TOOLTIP = "When the leader plays an emote, you play it too. Emotes you do not own, and anything in combat, are skipped.",
	SI_PBSES_NOTIFY = "Tell me in chat",
	SI_PBSES_NOTIFY_TOOLTIP = "Prints a line when an emote was played to follow the leader, or could not be.",
	SI_PBSES_LEAD = "Leader waits before playing (ms)",
	SI_PBSES_LEAD_TOOLTIP = "Members always trail the leader by the time the message needs to arrive, at least half a second. Raise this to hold your own emote back by that time so the whole group starts together. 0 plays yours at once. Measure the delay first with the button below.",

	SI_PBSES_SECTION_TOOLS = "Measure",
	SI_PBSES_PING_BUTTON = "Measure the delay to the group",
	SI_PBSES_PING_BUTTON_TEXT = "Measure",
	SI_PBSES_RESET = "Reset to defaults",
	SI_PBSES_RESET_BUTTON = "Reset",

	SI_PBSES_FOLLOWED = "Played \"%s\" to follow the leader.",
	SI_PBSES_FAILED = "Could not play \"%s\" (%s).",
	SI_PBSES_FAIL_BLACKLISTED = "blocked right now",
	SI_PBSES_FAIL_GENERIC = "not possible right now",
	SI_PBSES_FAIL_LOCKED = "not unlocked",
	SI_PBSES_FAIL_UNKNOWN = "reason %s",

	SI_PBSES_LOADED = "PB's Emote Synchronizer %s loaded. /emotesync for commands.",
	SI_PBSES_HELP = "/emotesync on | off -- turn everything on or off\n/emotesync status -- role, counters and why emotes were skipped\n/emotesync ping -- measure the round trip to every member who runs the add-on\n/emotesync lead <ms | auto> -- hold the leader's own emote back (auto = half the last round trip)\n/emotesync play <emote> -- play an emote from the add-on (a check; nothing is sent)\n/emotesync probe -- ask the game whether PlayEmoteByIndex is restricted\n/emotesync debug -- log what is sent and received",
	SI_PBSES_ON = "Emote Synchronizer on.",
	SI_PBSES_OFF = "Emote Synchronizer off.",
	SI_PBSES_DEBUG_ON = "Debug log on.",
	SI_PBSES_DEBUG_OFF = "Debug log off.",

	SI_PBSES_ROLE_SOLO = "not in a group",
	SI_PBSES_ROLE_LEADER = "leader",
	SI_PBSES_ROLE_MEMBER = "member",
	SI_PBSES_STATE_ON = "on",
	SI_PBSES_STATE_OFF = "off",
	SI_PBSES_HOOK_ACTIVE = "installed",
	SI_PBSES_HOOK_MISSING = "not installed",
	SI_PBSES_STATUS_ROLE = "Role: %s / add-on %s (send %s, follow %s) / leader waits %d ms / emote hook %s",
	SI_PBSES_STATUS_COUNTS = "Sent %d / received %d / played %d / failed %d",
	SI_PBSES_STATUS_SKIPPED = "Skipped: %s",
	SI_PBSES_STATUS_NONE = "none",

	SI_PBSES_NO_LIBRARY = "LibGroupBroadcast is not installed, so nothing can be sent or received.",
	SI_PBSES_TRANSPORT_ID_TAKEN = "Protocol id %d is already used by another add-on on this client. (%s)",
	SI_PBSES_TRANSPORT_FAILED = "The channel could not be set up. (%s)",
	SI_PBSES_TRANSPORT_REPORT = "Channel: id %d / enabled %s / sent %d / received %d (other version %d)%s",
	SI_PBSES_WHY_LAST = " / last failure: %s",
	SI_PBSES_WHY_NOT_READY = "the channel was never set up",
	SI_PBSES_WHY_DISABLED = "LibGroupBroadcast has this add-on's channel disabled",
	SI_PBSES_WHY_REFUSED = "LibGroupBroadcast did not accept the message",
	SI_PBSES_WHY_VERSION = "a member runs another version of the protocol",

	SI_PBSES_PROBE = "PlayEmoteByIndex: private %s / protected %s. Emotes known: %d. Broadcast cooldown left: %d ms.",
	SI_PBSES_PROBE_UNAVAILABLE = "IsPrivateFunction / IsProtectedFunction do not exist on this client.",
	SI_PBSES_PLAY_USAGE = "/emotesync play <emote>, for example /emotesync play dance",
	SI_PBSES_PLAY_NONE = "No emote called \"%s\".",
	SI_PBSES_PLAY_DONE = "Asked the game to play \"%s\".",

	SI_PBSES_NOT_GROUPED = "You are not in a group.",
	SI_PBSES_SEND_FAILED = "Could not send: %s",
	SI_PBSES_PING_SENT = "Measuring. Replies from members who run this add-on appear below.",
	SI_PBSES_PING_REPLY = "%s: round trip %d ms",
	SI_PBSES_PING_SUMMARY = "%d replied. Round trip: shortest %d / median %d / longest %d ms. About %d ms one way.",
	SI_PBSES_PING_NONE = "Nobody replied. Members need this add-on and LibGroupBroadcast.",
	SI_PBSES_LEAD_USAGE = "/emotesync lead <0-3000 | auto>",
	SI_PBSES_LEAD_SET = "The leader now waits %d ms before playing.",
	SI_PBSES_LEAD_NO_MEASURE = "No measurement yet. Run /emotesync ping first.",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
