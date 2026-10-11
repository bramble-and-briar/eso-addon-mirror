local BA = BuildAdvisor
-- Tags that let the advisor tell group-support gear and skills from selfish ones.
-- Names are English set/skill names as the game reports them; matching ignores case and
-- "Perfected". Lists are a starting point and need in-game validation.

-- Sets that buff the group or debuff enemies when worn by a tank.
BA.tankSupportSets = {
    "Pearlescent Ward", "Lucent Echoes", "Saxhleel Champion", "Turning Tide",
    "Crimson Oath's Rive", "Roar of Alkosh", "Archdruid Devyric", "Claw of Yolnahkriin",
    "Drake's Rush", "Encratis's Behemoth", "Nazaray", "Tremorscale", "Ebon Armory",
}

-- Sets that only help the tank wearing them.
BA.tankSelfishSets = {
    "Fortified Brass", "Plague Doctor", "Hist Bark", "Leeching Plate",
}

-- Sets that buff the group when worn by a healer.
BA.healerSupportSets = {
    "Spell Power Cure", "Powerful Assault", "Jorvuld's Guidance", "Pillager's Profit",
    "Master Architect", "Roaring Opportunist", "Symphony of Blades", "Vestment of Olorime",
    "Way of Martial Knowledge", "Worm's Raiment", "Pearls of Ehlnofey",
}

-- Skills that debuff enemies or buff the group, grouped by what they provide; any listed
-- skill or morph counts. Builds bring these different ways, so only "essential" effects are
-- recommended when missing. The rest are recognized (shown as good when slotted) and offered
-- as examples only when nothing on the bars helps the group. "class" limits an example to
-- that class (ids from BA.Scanner.CLASS_IDS).
BA.tankUtilitySkills = {
    -- The group's penetration math assumes the tank keeps Major Breach up.
    { effect = "Major Breach", essential = true,
      names = { "Pierce Armor", "Ransack", "Puncture", "Elemental Susceptibility", "Elemental Drain", "Weakness to Elements" } },
    { effect = "taunt + Minor Vulnerability", names = { "Inner Beast", "Inner Rage", "Inner Fire" } },
    { effect = "group Major Force or resistances", names = { "Aggressive Horn", "Sturdy Horn", "War Horn" } },
}

BA.healerUtilitySkills = {
    { effect = "group Major Force or resistances", names = { "Aggressive Horn", "Sturdy Horn", "War Horn" } },
    { effect = "Minor Magickasteal for group sustain", names = { "Elemental Drain" } },
    { effect = "group Minor Berserk", names = { "Combat Prayer", "Blessing of Protection" }, class = "templar" },
    { effect = "group healing over time", names = { "Echoing Vigor", "Resolving Vigor", "Vigor" } },
}

-- Mundus advice by role. "penShort" is used when damage is under its penetration target.
BA.mundusAdvice = {
    damage = { penShort = "The Lover", default = { "The Thief", "The Shadow" } },
    tank = { default = { "The Lady", "The Lord", "The Atronach" } },
    healer = { default = { "The Atronach", "The Ritual" } },
}
