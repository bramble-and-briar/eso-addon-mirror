-- Written by your coach. Overwritten on each plan update; your ticks live in SavedVariables.
-- This is the starter plan. After your first "check", Claude replaces it with a plan built from your data.
CoachClaude_Tasks = {
  generated = "Starter plan",
  message = "Welcome to Coach Claude. Do the three Start tasks, /reloadui, then tell Claude \"check\".",
  sections = { "Start", "Crafting", "Buy", "Sell", "Listings", "Flip" },
  sectionNotes = {
    Start = "One-time steps so your addons record the data your coach reads.",
    Crafting = "Writs and stock targets. Filled in after your first check.",
    Buy = "Buys worth making, with where to find them. Filled in after your first check.",
    Sell = "What to list or vendor, and at what price. Filled in after your first check.",
    Listings = "What is on your guild traders now. Filled in after your first check.",
    Flip = "Items bought to resell.",
  },
  groups = {
    {
      section = "Start",
      name = "First run",
      where = "Left-click a task when done. Right-click for more options. Hover anything for details.",
      tasks = {
        { id = "start-1", text = "Open your bank once", note = "Inventory Insight records your bank, bags and gold." },
        { id = "start-2", text = "Open each of your guild stores once", note = "Tamriel Trade Centre records your listings and your guilds' sales." },
        { id = "start-3", text = "Type /reloadui, then tell Claude \"check\"", note = "The game saves addon data only on /reloadui or logout. Claude then writes your first real plan here." },
      },
    },
  },
}
