ZO_CreateStringId("SI_MCH_TITLE", "Monster Coffer Helper")
ZO_CreateStringId("SI_MCH_PANEL_TITLE", "Undaunted Shoulders")

-- Verdicts
ZO_CreateStringId("SI_MCH_VERDICT_MYSTERY", "Buy MYSTERY coffers")
ZO_CreateStringId("SI_MCH_VERDICT_CURATED", "Buy CURATED coffers")
ZO_CreateStringId("SI_MCH_VERDICT_EITHER", "Either one costs the same")
ZO_CreateStringId("SI_MCH_VERDICT_DONE", "Collection complete - buy nothing")

-- Panel body
ZO_CreateStringId("SI_MCH_COLLECTED", "Collected")
ZO_CreateStringId("SI_MCH_LINE_COLLECTED", "<<1>> / <<2>> shoulders across <<3>> sets (<<4>> missing)")
ZO_CreateStringId("SI_MCH_MYSTERY", "Mystery")
ZO_CreateStringId("SI_MCH_CURATED", "Curated")
ZO_CreateStringId("SI_MCH_LINE_OFFER", "<<1>> key(s), <<2>> new -> <<3>> keys per new shoulder")
ZO_CreateStringId("SI_MCH_SWITCH_HINT", "Mystery stays cheaper until <<1>> shoulders are missing (<<2>> more to go).")
ZO_CreateStringId("SI_MCH_SWITCH_NOW", "You are past the break-even point; curated is cheaper from here on.")
ZO_CreateStringId("SI_MCH_FINISH", "Finish this vendor")
ZO_CreateStringId("SI_MCH_FINISH_LINE", "~<<1>> keys the smart way (all mystery <<2>> / all curated <<3>>)")
ZO_CreateStringId("SI_MCH_KEYS_HELD", "You hold <<1>> Undaunted Key(s)")
ZO_CreateStringId("SI_MCH_INCOMPLETE_SETS", "Still missing shoulders from")
ZO_CreateStringId("SI_MCH_AND_MORE", "and <<1>> more")
ZO_CreateStringId("SI_MCH_NO_DATA", "No shoulder data for this vendor.")
ZO_CreateStringId("SI_MCH_PRICES_LEARNED", "prices read from this vendor")
ZO_CreateStringId("SI_MCH_PRICES_ASSUMED", "assumed prices - visit the vendor to confirm")

-- Chat
ZO_CreateStringId("SI_MCH_CHAT_PREFIX", "Coffer")
ZO_CreateStringId("SI_MCH_CHAT_LINE", "<<1>>: <<2>> - <<3>> keys per new shoulder vs <<4>> curated (<<5>>/<<6>> collected)")
ZO_CreateStringId("SI_MCH_CHAT_DONE", "<<1>>: every shoulder collected. Save your keys.")

-- Tooltip
ZO_CreateStringId("SI_MCH_TT_CHANCE", "New shoulder: <<1>>")
ZO_CreateStringId("SI_MCH_TT_COST", "Effective cost: <<1>> keys per new shoulder")
ZO_CreateStringId("SI_MCH_TT_BEST", "Best buy here")
ZO_CreateStringId("SI_MCH_TT_WORSE", "The other coffer is cheaper per new shoulder")
ZO_CreateStringId("SI_MCH_TT_SET_MISSING", "<<1>> of <<2>> shoulders still missing from this coffer")
ZO_CreateStringId("SI_MCH_TT_SET_DONE", "You already own every shoulder in this coffer - wasted keys")

-- Purchase confirmation
ZO_CreateStringId("SI_MCH_GUARD_TITLE", "Not the best buy")
ZO_CreateStringId("SI_MCH_GUARD_MYSTERY_WORSE", "Curated coffers are cheaper here right now: <<1>> keys per new shoulder, against <<2>> for a Mystery Coffer.")
ZO_CreateStringId("SI_MCH_GUARD_CURATED_WORSE", "Mystery Coffers are cheaper here right now: <<1>> keys per new shoulder, against <<2>> for this curated coffer.")
ZO_CreateStringId("SI_MCH_GUARD_DUPLICATE", "You already own every shoulder this coffer can give, so it can only be a duplicate.")
ZO_CreateStringId("SI_MCH_GUARD_BUY", "Buy anyway")

-- Settings
ZO_CreateStringId("SI_MCH_SET_DISPLAY", "Display")
ZO_CreateStringId("SI_MCH_SET_PANEL", "Show panel at the vendor")
ZO_CreateStringId("SI_MCH_SET_PANEL_TT", "Pops the recommendation window open when you talk to an Undaunted quartermaster.")
ZO_CreateStringId("SI_MCH_SET_CHAT", "Print recommendation to chat")
ZO_CreateStringId("SI_MCH_SET_CHAT_TT", "Writes a one-line verdict to chat when the vendor's store opens.")
ZO_CreateStringId("SI_MCH_SET_TOOLTIPS", "Add lines to coffer tooltips")
ZO_CreateStringId("SI_MCH_SET_TOOLTIPS_TT", "Shows your odds and the effective key cost on the coffers in the vendor's store.")
ZO_CreateStringId("SI_MCH_SET_CONFIRM", "Confirm purchases that aren't the best buy")
ZO_CreateStringId("SI_MCH_SET_CONFIRM_TT", "Asks before buying the costlier coffer, or a coffer that can only give a shoulder you already own.")
ZO_CreateStringId("SI_MCH_SET_LOCK", "Lock panel position")
ZO_CreateStringId("SI_MCH_SET_RESET_POS", "Reset panel position")
ZO_CreateStringId("SI_MCH_SET_MAXSETS", "Sets listed in the panel")
ZO_CreateStringId("SI_MCH_SET_MAXSETS_TT", "How many incomplete sets to name before collapsing the rest into a count.")

ZO_CreateStringId("SI_MCH_SET_PRICES", "Prices")
ZO_CreateStringId("SI_MCH_SET_LEARN", "Use prices read from the vendor")
ZO_CreateStringId("SI_MCH_SET_LEARN_TT", "Reads the real key cost off the store window and remembers it. Turn this off to always use the values below.")
ZO_CreateStringId("SI_MCH_SET_MCOST", "Mystery coffer cost (keys)")
ZO_CreateStringId("SI_MCH_SET_CCOST", "Curated coffer cost (keys)")
ZO_CreateStringId("SI_MCH_SET_COST_TT", "Fallback used until the addon has seen the vendor's store.")

ZO_CreateStringId("SI_MCH_SET_POOL", "Vendor stock")
ZO_CreateStringId("SI_MCH_SET_LEARNPOOL", "Use stock read from the vendor")
ZO_CreateStringId("SI_MCH_SET_LEARNPOOL_TT", "Adds sets seen in the store window to the list bundled with LibSets, so a set newer than LibSets' data still counts.")
ZO_CreateStringId("SI_MCH_SET_FORGET", "Forget everything read from vendors")

ZO_CreateStringId("SI_BINDING_NAME_MCH_TOGGLE", "Toggle Coffer Helper")
