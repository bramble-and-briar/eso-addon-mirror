-- The one long-running operation in progress (crafting, moving items, opening containers...),
-- shown in the window with its progress and a Stop button. Only one can run at a time.
MWC.Activity = {}

local current = nil
-- How the last operation ended, when it stopped on a problem: shown in red until the next one starts or
-- the user dismisses it. Normal endings and the user's own Stop leave nothing behind.
local outcome = nil
local SUCCESS_PATTERNS = { "^Done", "^Moved ", "^Turned in" }

local function IsSuccess(message)
  for _, pattern in ipairs(SUCCESS_PATTERNS) do
    if message:find(pattern) then return true end
  end
  return false
end

-- Returns false (and tells the user) if another operation is already running.
-- crafting (also starting quests): while it runs, bag changes don't rebuild the list and the inventory marks (a
-- full rebuild between two steps slowed them down); everything is refreshed once at the end.
function MWC.Activity.Begin(label, total, onStop, crafting)
  if current then
    MWC.Print("%s is still running. Stop it first.", current.label)
    return false
  end
  current = { label = label, total = total, done = 0, detail = label .. "…", onStop = onStop, crafting = crafting }
  MWC.Log("Begin: %s (%s)", label, tostring(total))
  outcome = nil
  MWC.UI.OnActivityChanged()
  return true
end

function MWC.Activity.Progress(done, detail)
  if not current then return end
  current.done = done
  if detail then
    current.detail = detail
  end
  MWC.UI.OnActivityChanged()
end

-- message: what the operation reports in chat when it ends.
function MWC.Activity.End(message)
  if not current then return end
  MWC.Log("End: %s%s", message or "(no message)", current.userStopped and " [stopped by the player]" or "")
  if message and not current.userStopped and not IsSuccess(message) then
    outcome = { message = message, short = message:match("^(.-)%.%s") or message:gsub("%.$", ""), label = current.label }
  end
  current = nil
  MWC.UI.OnActivityChanged()
  -- Crafting, banking, opening containers and starting quests change the bags: the material links, the bag
  -- marks and the list are brought up to date once here.
  MWC.Plan.ForgetLinks()
  MWC.Marks.Refresh()
  MWC.UI.Refresh()
end

function MWC.Activity.IsCrafting()
  return current ~= nil and current.crafting == true
end

-- How an operation's closing message reaches chat: routine successes ("Done...", "Moved...", "Turned in...") stay
-- out of it (the window shows them); problems, skipped writs and anything needing attention are printed.
local QUIET_PATTERNS = { "^Done", "^Moved ", "^Turned in" }

function MWC.Activity.Notify(message)
  if not message then return end
  if not message:find("Skipped") then
    for _, pattern in ipairs(QUIET_PATTERNS) do
      if message:find(pattern) then return end
    end
  end
  MWC.Print("%s", message)
end

function MWC.Activity.Outcome()
  return outcome
end

-- Clears the red outcome only if that kind of operation left it ("Moving" when the bank closes).
function MWC.Activity.DismissIf(label)
  if outcome and outcome.label == label then
    MWC.Activity.Dismiss()
  end
end

function MWC.Activity.Dismiss()
  outcome = nil
  MWC.UI.OnActivityChanged()
end

function MWC.Activity.Current()
  return current
end

function MWC.Activity.Stop()
  if current and current.onStop then
    current.userStopped = true
    current.onStop()
  end
end
