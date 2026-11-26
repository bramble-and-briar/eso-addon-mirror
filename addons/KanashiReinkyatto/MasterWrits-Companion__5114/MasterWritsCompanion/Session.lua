MWC.Session = {}

-- Exclusions are keyed by item unique id so they follow the writ between bags and survive reloads.
local function VoucherBalance()
  return GetCurrencyAmount(CURT_WRIT_VOUCHERS, GetCurrencyPlayerStoredLocation(CURT_WRIT_VOUCHERS))
end

-- what: as for MWC.UI.Refresh.
local function Changed(what)
  MWC.Marks.Refresh()
  MWC.UI.Refresh(what)
end

function MWC.Session.Init()
  if not MWC.sv.session then
    MWC.sv.session = { started = GetTimeStamp(), startVouchers = VoucherBalance(), excluded = {} }
  end
end

-- Writs whose quest is still open stay in the new session's journal: their crafted items remain reserved.
function MWC.Session.Reset()
  local open = {}
  for uid, entry in pairs(MWC.sv.session.journal or {}) do
    if entry.state == "active" or entry.state == "accepting" then
      open[uid] = entry
    end
  end
  MWC.sv.session = nil
  MWC.Session.Init()
  MWC.sv.session.journal = open
  Changed()
end

-- Writs that can't be crafted start skipped, once per session: checking one again later is respected.
function MWC.Session.AutoSkip(uid)
  local session = MWC.sv.session
  session.autoSkipped = session.autoSkipped or {}
  if session.autoSkipped[uid] then return false end
  session.autoSkipped[uid] = true
  session.excluded[uid] = true
  return true
end

-- Writ kinds (group keys) whose style material is replaced by a Crown Mimic Stone.
function MWC.Session.UsesMimic(key)
  return MWC.sv.session.mimic ~= nil and MWC.sv.session.mimic[key] == true
end

function MWC.Session.SetMimic(group, enabled)
  MWC.sv.session.mimic = MWC.sv.session.mimic or {}
  MWC.sv.session.mimic[group.key] = enabled or nil
  Changed({ group.type })
end

function MWC.Session.IsExcluded(uid)
  return MWC.sv.session.excluded[uid] == true
end

-- Writs within a group are the same task, so which ones stay selected doesn't matter; keep the first n.
-- Only writs in the bags can be queued or skipped; writs with a quest (journal) are past that.
function MWC.Session.SetSelectedCount(group, count)
  local excluded = MWC.sv.session.excluded
  local index = 0
  for _, writ in ipairs(group.writs) do
    if not writ.state then
      index = index + 1
      excluded[writ.uid] = index > count or nil
    end
  end
  Changed(true)
end

function MWC.Session.SetGroupsSelected(groups, selected)
  local excluded = MWC.sv.session.excluded
  for _, group in ipairs(groups) do
    for _, writ in ipairs(group.writs) do
      if not writ.state then
        excluded[writ.uid] = not selected or nil
      end
    end
  end
  Changed(true)
end

function MWC.Session.ExcludeGroups(groups)
  MWC.Session.SetGroupsSelected(groups, false)
end

-- The handed-in figures are in the Stats table (from the session journal).
function MWC.Session.Summary()
  return string.format("Session since %s", os.date("%d.%m %H:%M", MWC.sv.session.started))
end

function MWC.Session.ConfirmReset()
  ZO_Dialogs_ShowDialog("MWC_RESET_SESSION")
end

ZO_Dialogs_RegisterCustomDialog("MWC_RESET_SESSION", {
  title = { text = "MasterWrits" },
  mainText = { text = "Reset the session? All \"skip\" marks and the history of turned-in writs will be cleared." },
  buttons = {
    { text = SI_DIALOG_CONFIRM, callback = MWC.Session.Reset },
    { text = SI_DIALOG_CANCEL },
  },
})
