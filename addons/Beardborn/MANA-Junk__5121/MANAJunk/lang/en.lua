-- MANA Junk — English (default). Texts in the code are English; other languages translate them here.
MANAJunk = MANAJunk or {}
MANAJunk.STRINGS = MANAJunk.STRINGS or {}
function MANAJunk.T(text) return MANAJunk.STRINGS[text] or text end
function MANAJunk.STACKS(n) return n .. (n == 1 and " stack" or " stacks") end
