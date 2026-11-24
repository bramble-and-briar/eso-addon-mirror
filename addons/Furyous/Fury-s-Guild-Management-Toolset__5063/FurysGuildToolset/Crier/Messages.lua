-- ============================================================
--  FURY'S GUILD CRIER - DEFAULT MESSAGE LIST
--  This is the STARTING list. Once the addon has loaded, your messages
--  live in the addon's saved settings and you edit them in game:
--  Settings > Addons > Fury's Guild Management - Crier (or /crier settings).
--  Changes made here only show up in game if you use "Import new
--  messages", "Import new tips" or "Reset to Messages.lua" in that
--  settings panel.
--
--  cat    = the heading it shows under in the menu.
--           Headings appear in the order they first show up below.
--  text   = the message.
--  chan   = OPTIONAL. chan = "zone" posts to zone chat.
--           chan = "whisper" whispers the @name typed in the
--           "Whisper to" box at the top of the menu.
--           Leave it off to post to the guild picked in the menu.
--  weight = OPTIONAL. Leave it off for menu-only messages.
--           Add a weight to also put it in the rotation key:
--           weight 3 comes up 3x as often as weight 1.
--
--  These are generic SAMPLES. Replace them with your guild's own messages in
--  the Crier settings. Updating the addon never replaces the messages you
--  already have; only "Reset to Messages.lua" does.
--
--  Placeholders you can use in text:
--    {new}   = @name of the newest member who joined the selected
--              guild since you logged in
--    {guild} = the selected guild's name
--
--  Rules for editing:
--   - Keep the comma at the end of each line.
--   - Don't type /g1 or /z in front. The addon picks the channel.
--   - If your message contains a double quote ("), use [[ ]] instead:
--       { cat = "Rules", text = [[Type "/help" for info]] },
--   - ESO chat max is 350 characters. /crier list flags anything longer.
--   - After editing, type /reloadui in game.
-- ============================================================

local GT = FurysGuildToolset

GT.CrierMessages = {

    -- ===== Recruiting (zone chat) =====
    -- Tip: put your guild's link at the start and end of a recruiting ad so
    -- people can click it to apply.
    { cat = "Recruiting", chan = "zone", text = "{guild} is recruiting! A friendly, active guild for new and veteran players alike. We run dungeons, trials, PvP and crafting nights, and we're happy to teach. Guild hall, trader and a helpful crowd. Whisper me or apply through the Guild Finder!" },
    { cat = "Recruiting", chan = "zone", text = "Like to teach? {guild} is looking for players who want to lead runs, share builds or host events. Lead what you love, your way. Whisper me to find out more!" },

    -- ===== Applications (whisper) =====
    { cat = "Applications", chan = "whisper", text = "Hi! Thanks for applying to {guild}! Your application came through, but you're already in 5 guilds, which is the game's maximum, so I can't accept you yet. If you leave one and apply again, I'll get you in. Hope to see you soon!" },

    -- ===== Welcome =====
    { cat = "Welcome", text = "Welcome to {guild}, {new}! Check the guild MOTD for our rules and links, say hi in guild chat, and ask if you need anything. Glad you're here!" },

    -- ===== Tips (in the rotation) =====
    { cat = "Tips", weight = 2, text = "Need help? Just ask in guild chat! No question is too basic, we were all new once." },
    { cat = "Tips", weight = 2, text = "Guild Bank 101: take what you need for your character, not to sell. Take up to 5 items a day, and put back what you don't use. Deposits should be useful to others. Please don't use the bank to get rid of junk." },
    { cat = "Tips", weight = 1, text = "Our guild trader is open to the whole server, and every sale helps pay for next week's spot. To sell, visit any banker, choose Guild Store, pick {guild} and list your items." },
    { cat = "Tips", weight = 1, text = "Wear your colors! Press C, find the guild nameplate drop-down and pick {guild}, so guildies can spot you and group up." },
    { cat = "Tips", weight = 1, text = "Know something well? Lead a run, a crafting night or a housing tour. You don't need to know everything, just enough to have fun and pass it on." },
    { cat = "Tips", weight = 1, text = [[Combat 101: block big hits, dodge roll out of red circles, bash to interrupt enemies winding up a big attack, and break free when you're stunned. Defense first, damage second. Dead players do zero DPS, and the floor is not a tanking strategy. Want to practice? Ask for a guild class!]] },
    { cat = "Tips", weight = 1, text = [[DPS secret #1: light attack weaving. Tap a light attack, then cast a skill, and repeat. It's a big chunk of free damage once it clicks. It feels weird at first, so practice on a target dummy. Ask in guild chat and someone will happily show you how it's done.]] },
    { cat = "Tips", weight = 1, text = [[Once weapon swap unlocks, you get a second skill bar: more skills and a second ultimate! Keep your buffs up on both bars and your main damage on the bar with your best weapon. Not sure what goes where? Post a screenshot of your bars and let us help.]] },
    { cat = "Tips", weight = 1, text = [[Respecs are FREE now! Open your skills window and play mad scientist: swap morphs, try a new weapon line, test a skill you've never touched. Hit a target dummy and see what happens. Didn't work? Change it back for nothing. Found something cool? Share it in guild chat so we can all steal it.]] },
    { cat = "Tips", weight = 1, text = [[Visit a stablemaster every day and buy a riding lesson for gold. Every lesson makes your mount better, and you can't buy them all at once, so skipped days add up fast. Future you, zooming past everyone on the way to the next dungeon, says thanks.]] },
    { cat = "Tips", weight = 1, text = [[Start crafting research NOW, even if you don't craft yet. Research runs on a real-time clock, even while you're offline, and later traits take days. Keep one item of each trait for blacksmithing, clothing, woodworking and jewelry. Future you will be rich and very smug about it.]] },
    { cat = "Tips", weight = 1, text = [[Free power! Visit a Mundus Stone for a buff that lasts until you swap it, and eat buff food before group content. Not sure which Mundus or food is right for you? Ask! Food is cheap. Repairs and wipes aren't.]] },
    { cat = "Tips", weight = 1, text = [[Don't sink gold into gear while leveling. Your stats scale, and gear only stops changing at CP 160. Until then, wear training gear and any 5-piece sets you find, and save your mats and gold. Hit CP 160 and we'll help you put together a real build.]] },
    { cat = "Tips", weight = 1, text = [[First time in a dungeon? Say so at the start! Nobody minds a newbie, everyone minds a surprise. Let the tank pull, stay with the group, and don't wander off chasing loot. If you die, ask what happened, not who's to blame. That's how we all got good.]] },
    { cat = "Tips", weight = 1, text = [[Join the Fighters Guild and Mages Guild and do their quests. Their skill lines have great passives. Fighters Guild ranks up when you kill undead, daedra and Dark Anchors. Mages Guild ranks up when you read lorebooks. Free power just for playing the game!]] },
    { cat = "Tips", weight = 1, text = [[Say hi when you log in! Guild chat is where groups form, questions get answered and friendships start. You don't have to be chatty, but a quick "hey all" lets people know you're around and up for something. Lurkers welcome, waving lurkers preferred.]] },
    { cat = "Tips", weight = 1, text = [[It's OK to die, wipe, and ask "what just happened?" That's literally how everyone learns this game. Nobody here was born knowing mechanics. Keep showing up, keep asking, and you'll be the one teaching the next newbie sooner than you think.]] },
    { cat = "Tips", weight = 1, text = [[Crafters: grandmaster crafting stations let you craft many sets in one spot, and some guild halls have them. Bring your mats, pick a set and ask if you need help with traits. Not a crafter? Ask in guild chat, crafters are often happy to make gear for you.]] },
    { cat = "Tips", weight = 1, text = [[Level scaling is ESO's superpower! Almost every zone and dungeon scales to you, so you can go anywhere and group with anyone at any level. Level 6? Grab a friend and go tank a dragon. Yes, really, we've seen it done. Your level is a number, not a cage. Join that group!]] },

    -- ===== Group calls =====
    { cat = "Group Calls", text = "Anyone up for a Random Normal Dungeon? Any level, any role. Type x in guild chat to join!" },

    -- ===== Admin =====
    { cat = "Admin", text = "Heads up: roster cleanup soon! Members who haven't logged in for a while may be removed. Going to be away? Tell an officer and we'll hold your spot." },
}
