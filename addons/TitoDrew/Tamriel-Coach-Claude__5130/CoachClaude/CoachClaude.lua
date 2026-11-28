-- Coach Claude v1.7.1
-- Task list written by the coach (Tasks.lua). Your actions are saved to CoachClaude_SV for the coach to read.
-- Left-click task: done / undo. Buy tasks the store can act on cycle open -> approved -> done.
-- Right-click task: menu (approve, done, one partial, skip, remove, reset).
-- Approved buys run when you open that guild's store, inside your rules (Settings, top right). See Store.lua.
-- Partial: buy tasks = "bought some, need alternatives"; sell tasks = "listed some, keeping the rest as stock".
-- Tabs across the top: All or one section (Crafting, Buy, Sell, Listings, Flip). The window remembers the last tab.
-- In "All", sections show in a fixed order; click a section header to fold it.
-- Click a group header to fold it.  [-]/[+] in the title folds the whole window.

CoachClaude = CoachClaude or {}
local CC = CoachClaude
CC.name = "CoachClaude"

local ROWS, ROW_H, WIDTH, TOP = 22, 22, 600, 88
local C = { open="FFFFFF", done="66CC66", partial="E8C15A", skip="808080", approved="7FB2FF", head="E8C15A",
            note="A0A0A0", here="5AC8FA", where="C8B48C", prog="9FC5E8", sect="F0E6D2", empty="707070", tab="A0A0A0", tabOn="FFFFFF" }
local SECT_C = { Crafting="9FC5E8", Buy="7FD3A0", Sell="E8A55A", Listings="E8C15A", Flip="C9A0DC", Other="A0A0A0" }
local BOX = { open="[  ]", done="[x]", partial="[~]", skip="[-]", approved="[A]" }

local function col(hex, s) return "|c" .. hex .. tostring(s) .. "|r" end
local function norm(s) return (tostring(s or ""):lower():gsub("[^%w]", "")) end
local function fmt(n) return n and ZO_CommaDelimitNumber(n) or "" end

local function groups() return (CoachClaude_Tasks and CoachClaude_Tasks.groups) or {} end
CC.groups = groups
local DEFAULT_SECTIONS = { "Crafting", "Buy", "Sell", "Listings", "Flip" }
local function sections() return (CoachClaude_Tasks and CoachClaude_Tasks.sections) or DEFAULT_SECTIONS end

-- state entry: nil (open) or { s = "done"|"partial"|"skip"|"remove", qty = n, have = n, t = ts }
local function entry(id) return CC.sv.state[id] end
-- a task the plan pre-approved (t.approved) counts as approved until you change it
local function stateOf(t)
  local e = entry(t.id)
  if e then return e.s end
  return t.approved and "approved" or "open"
end
CC.stateOfTask = stateOf

-- the group a task belongs to (for its guild)
local function groupOf(t)
  for _, g in ipairs(groups()) do
    for _, x in ipairs(g.tasks or {}) do if x == t then return g end end
  end
end
local function actionable(t) return CC.Store and CC.Store.Actionable(t, groupOf(t)) end

-- Inventory index by item name: backpack + bank (+ ESO Plus bank) + craft bag. Rebuilt when inventory changes.
local function addSlot(idx, bag, slot)
  local name = GetItemName(bag, slot)
  if name and name ~= "" then
    local k = norm(zo_strformat("<<1>>", name))
    local n = GetSlotStackSize(bag, slot) or 0
    local e = idx[k] or { total = 0, bags = {} }
    e.total = e.total + n
    e.bags[bag] = (e.bags[bag] or 0) + n
    idx[k] = e
  end
end

local function invIndex()
  if CC.inv then return CC.inv end
  local idx = {}
  for _, bag in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
    local size = GetBagSize(bag) or 0
    for slot = 0, size - 1 do addSlot(idx, bag, slot) end
  end
  if BAG_VIRTUAL and GetNextVirtualBagSlotId then
    local slot = GetNextVirtualBagSlotId(nil)
    while slot do addSlot(idx, BAG_VIRTUAL, slot); slot = GetNextVirtualBagSlotId(slot) end
  end
  CC.inv = idx
  return idx
end

-- the name a task counts: t.match, else t.item with any "(...)" note stripped
local function matchName(t)
  local n = t.match or t.item
  if not n then return nil end
  return norm((n:gsub("%b()", "")))
end

local function haveDetail(t)
  if t.link and t.link ~= "" then
    local ok, b, k, c = pcall(GetItemLinkStacks, t.link)
    if ok and b then return (b or 0) + (k or 0) + (c or 0), { bag = b, bank = k, craft = c } end
  end
  local key = matchName(t)
  if not key then return nil end
  local e = invIndex()[key]
  if not e then return 0, {} end
  local bank = (e.bags[BAG_BANK] or 0) + (e.bags[BAG_SUBSCRIBER_BANK] or 0)
  return e.total, { bag = e.bags[BAG_BACKPACK] or 0, bank = bank, craft = e.bags[BAG_VIRTUAL] or 0 }
end

local function haveCount(t) local n = haveDetail(t); return n end

-- sell/list tasks: how many left inventory since the plan loaded. buy tasks: how many arrived.
local function moved(t)
  local base, have = CC.sv.base[t.id], haveCount(t)
  if not (base and have) then return nil, have end
  if t.kind == "buy" then return math.max(0, have - base), have end
  return math.max(0, base - have), have
end

local function taskTip(t)
  local out = {}
  if t.note then out[#out + 1] = t.note end
  local have, where = haveDetail(t)
  if have then
    local parts = {}
    if where.bag and where.bag > 0 then parts[#parts + 1] = "bag " .. fmt(where.bag) end
    if where.bank and where.bank > 0 then parts[#parts + 1] = "bank " .. fmt(where.bank) end
    if where.craft and where.craft > 0 then parts[#parts + 1] = "craft bag " .. fmt(where.craft) end
    out[#out + 1] = "In inventory: " .. fmt(have) .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "")
    local mv = moved(t)
    if t.kind == "buy" then
      local need = t.need or t.qty
      if need then out[#out + 1] = "Recipe needs: " .. fmt(need) .. "   Still to buy: " .. fmt(math.max(0, need - have)) end
      if t.qty then out[#out + 1] = "Plan: buy " .. fmt(t.qty) .. (mv and mv > 0 and ("  (" .. fmt(mv) .. " bought so far)") or "") end
      if need and have > need then out[#out + 1] = "Spare after crafting: " .. fmt(have - need) end
    elseif t.qty then
      out[#out + 1] = "Plan: list/sell " .. fmt(t.qty) .. (mv and mv > 0 and ("  (" .. fmt(mv) .. " gone so far)") or "")
    end
  end
  return table.concat(out, "\n")
end

local function setState(t, s, qty, why)
  local _, have = moved(t)
  if s == "open" and not t.approved then CC.sv.state[t.id] = nil
  else CC.sv.state[t.id] = { s = s, qty = qty, have = have, why = why, t = GetTimeStamp() } end
  local log = CC.sv.log
  log[#log + 1] = { id = t.id, s = s, qty = qty, have = have, why = why, t = GetTimeStamp() }
  while #log > 300 do table.remove(log, 1) end
  PlaySound(SOUNDS.DEFAULT_CLICK)
  CC.Refresh()
end
CC.SetTaskState = setState

local function currentGuild()
  if not CC.atStore then return nil end
  local ok, _, name = pcall(GetCurrentTradingHouseGuildDetails)
  if ok and name then return norm(name) end
end

-- Lines for one group: its header (if it has tasks), where-line and tasks.
local function groupLines(g, here)
  local lines, gTotal, gDone, removed = {}, 0, 0, 0
  local folded = CC.sv.folded[g.name]
  local taskLines = {}
  for _, t in ipairs(g.tasks or {}) do
    local s = stateOf(t)
    if s == "remove" then
      removed = removed + 1
    else
      gTotal = gTotal + 1
      if s ~= "open" and s ~= "approved" then gDone = gDone + 1 end
      local e = entry(t.id)
      local txt = t.text or t.item or "?"
      if t.qty then txt = txt .. " x" .. fmt(t.qty) end
      if t.price then
        txt = txt .. "  @ " .. fmt(t.price)
        if t.qty and t.qty > 1 then txt = txt .. "  (~" .. fmt(t.qty * t.price) .. ")" end
      end
      local mv, have = moved(t)
      local extra = {}
      if s == "partial" and e then
        local n = e.qty and (fmt(e.qty) .. " ") or ""
        if e.why == "buy_alt" then extra[#extra + 1] = col(C.partial, "bought " .. n .. "- needs new leads")
        else extra[#extra + 1] = col(C.partial, (t.kind == "buy" and "bought " or "listed ") .. n .. "- keeping rest") end
      end
      if mv and mv > 0 then
        local verb = t.kind == "buy" and " bought" or " moved"
        extra[#extra + 1] = col(s == "skip" and C.skip or C.prog, fmt(mv) .. (t.qty and ("/" .. fmt(t.qty)) or "") .. verb)
      end
      if have then
        local need = t.kind == "buy" and (t.need or nil)
        extra[#extra + 1] = col(C.note, "have " .. fmt(have) .. (need and ("/" .. fmt(need)) or ""))
      end
      if s == "approved" then
        local left = actionable(t) and CC.Store.Remaining(t)
        extra[#extra + 1] = col(C.approved, "approved - buys at " .. (g.guild or "?") .. (left and left < t.qty and (" (" .. fmt(left) .. " left)") or ""))
      end
      if #extra > 0 then txt = txt .. "  " .. table.concat(extra, "  ") end
      local colr = C[s] or C.open
      taskLines[#taskLines + 1] = { kind = "task", task = t, text = col(colr, "  " .. BOX[s] .. " " .. txt) }
    end
  end
  if gTotal > 0 then
    local hl = here and g.guild and norm(g.guild) == here
    local arrow = folded and "+ " or "- "
    local head = col(hl and C.here or C.head, "  " .. arrow .. (hl and "> " or "") .. g.name) .. col(C.note, "  " .. gDone .. "/" .. gTotal)
    lines[#lines + 1] = { kind = "head", group = g.name, text = head, tip = g.where }
    if not folded then
      if g.where then lines[#lines + 1] = { kind = "where", text = "      " .. col(C.where, g.where), tip = g.where } end
      for _, l in ipairs(taskLines) do lines[#lines + 1] = l end
    end
  end
  return lines, gTotal, gDone, removed
end

-- Fixed sections in a fixed order. Each group names its section (g.section); groups
-- without one, or with an unknown one, go under "Other" at the end. Section folds are
-- keyed by the section name, so they survive plan updates (group names change).
local function buildLines()
  local lines, total, done, removed = {}, 0, 0, 0
  local tab = CC.sv.tab or "All"
  CC.counts = { All = 0 }
  if CC.view == "settings" and CC.Store then
    CC.order = DEFAULT_SECTIONS
    return CC.Store.SettingLines(), 0, 0, 0
  end
  if CC.Store then for _, l in ipairs(CC.Store.Lines()) do lines[#lines + 1] = l end end
  local here = currentGuild()
  local order, bySection, known = {}, {}, {}
  for _, name in ipairs(sections()) do order[#order + 1] = name; bySection[name] = {}; known[norm(name)] = name end
  local other = {}
  for _, g in ipairs(groups()) do
    local name = g.section and known[norm(g.section)]
    if name then table.insert(bySection[name], g) else other[#other + 1] = g end
  end
  if #other > 0 then order[#order + 1] = "Other"; bySection["Other"] = other end
  local notes = (CoachClaude_Tasks and CoachClaude_Tasks.sectionNotes) or {}
  for _, name in ipairs(order) do
    local sLines, sTotal, sDone = {}, 0, 0
    for _, g in ipairs(bySection[name]) do
      local gl, gt, gd, gr = groupLines(g, here)
      sTotal, sDone, removed = sTotal + gt, sDone + gd, removed + gr
      for _, l in ipairs(gl) do sLines[#sLines + 1] = l end
    end
    total, done = total + sTotal, done + sDone
    CC.counts[name] = sTotal - sDone
    CC.counts.All = CC.counts.All + (sTotal - sDone)
    local key = "\194\167" .. name
    if tab == "All" then
      local folded = CC.sv.folded[key]
      local count = sTotal > 0 and col(C.note, "  " .. sDone .. "/" .. sTotal) or col(C.empty, "  nothing today")
      lines[#lines + 1] = { kind = "section", key = key, tip = notes[name],
        text = col(sTotal > 0 and (SECT_C[name] or C.sect) or C.empty, (folded and "+ " or "- ") .. string.upper(name)) .. count }
      if not folded then for _, l in ipairs(sLines) do lines[#lines + 1] = l end end
    elseif tab == name then
      if notes[name] then lines[#lines + 1] = { kind = "where", text = col(C.where, notes[name]), tip = notes[name] } end
      if #sLines == 0 then lines[#lines + 1] = { kind = "where", text = col(C.empty, "Nothing today.") } end
      for _, l in ipairs(sLines) do lines[#lines + 1] = l end
    end
  end
  CC.order = order
  return lines, total, done, removed
end

-- Tab row: "All" plus every section, each with its count of open tasks.
local function refreshTabs()
  if not CC.tabs then return end
  local names = { "All" }
  for _, n in ipairs(CC.order or {}) do names[#names + 1] = n end
  local active = CC.sv.tab or "All"
  for i, ctrl in ipairs(CC.tabs) do
    local name = names[i]
    ctrl.tabName = name
    if name then
      local n = (CC.counts and CC.counts[name]) or 0
      local on = name == active
      local hue = on and (SECT_C[name] or C.tabOn) or (n > 0 and C.tab or C.empty)
      ctrl:SetText(col(hue, (on and "[" or "") .. name .. (n > 0 and (" " .. n) or "") .. (on and "]" or "")))
      ctrl:SetHidden(false)
    else
      ctrl:SetText(""); ctrl:SetHidden(true)
    end
  end
end

function CC.Refresh()
  if not CC.win then return end
  local lines, total, done, removed = buildLines()
  CC.lines = lines
  refreshTabs()
  local inSettings = CC.view == "settings"
  for _, t in ipairs(CC.tabs or {}) do if inSettings then t:SetHidden(true) end end
  if CC.gear then CC.gear:SetText(col(inSettings and C.tabOn or C.tab, inSettings and "[Tasks]" or "Settings")) end
  local gen = CoachClaude_Tasks and CoachClaude_Tasks.generated or "no tasks loaded"
  CC.title:SetText(col(C.head, "Coach Claude") .. "  " .. done .. "/" .. total .. " done" ..
    (removed > 0 and col(C.note, "  (" .. removed .. " removed)") or ""))
  CC.fold:SetText(CC.sv.collapsed and "[+]" or "[-]")
  if CC.sv.collapsed then
    for i = 1, ROWS do CC.rows[i]:SetHidden(true) end
    for _, t in ipairs(CC.tabs or {}) do t:SetHidden(true) end
    if CC.gear then CC.gear:SetHidden(true) end
    CC.sub:SetHidden(true); CC.pager:SetText("")
    CC.win:SetHeight(40)
    return
  end
  CC.sub:SetHidden(false)
  if CC.gear then CC.gear:SetHidden(false) end
  local dry = CC.sv.rules and CC.sv.rules.dry
  CC.sub:SetText(col(C.note, gen .. "   |   left-click: done   right-click: more") .. (dry and col("9FC5E8", "   |   dry run") or ""))
  local pages = math.max(1, math.ceil(#lines / ROWS))
  CC.page = zo_clamp(CC.page or 1, 1, pages)
  local first, shown = (CC.page - 1) * ROWS, 0
  for i = 1, ROWS do
    local row, line = CC.rows[i], lines[first + i]
    row.line = line
    if line then
      row:SetFont((line.kind == "section" or line.kind == "store") and "ZoFontWinH5" or (line.kind == "head" and "ZoFontGameBold" or "ZoFontGame"))
      row:SetText(line.text); row:SetHidden(false); shown = i
    else row:SetText(""); row:SetHidden(true) end
  end
  CC.pager:SetText(pages > 1 and ("<  page " .. CC.page .. "/" .. pages .. "  >") or "")
  CC.win:SetHeight(TOP + math.max(shown, 1) * ROW_H + 34)
end

function CC.Show(show)
  if not CC.win then return end
  CC.win:SetHidden(not show)
  CC.sv.visible = show
  if show then CC.Refresh() end
end

local function tooltip(ctrl, text)
  if not text or text == "" then return end
  InitializeTooltip(InformationTooltip, ctrl, LEFT, 8, 0, RIGHT)
  SetTooltipText(InformationTooltip, text)
end

local function taskMenu(ctrl, t)
  ClearMenu()
  local s = stateOf(t)
  local mv = moved(t)
  if actionable(t) then
    if s == "approved" then
      AddMenuItem("Unapprove (don't buy at the store)", function() setState(t, "open") end)
    else
      AddMenuItem("Approve - buy at " .. groupOf(t).guild .. " inside my rules", function() setState(t, "approved") end)
    end
  end
  AddMenuItem("Done", function() setState(t, "done", t.qty) end)
  -- Two partial outcomes only. Quantity comes from inventory movement since the plan loaded.
  if t.item and t.qty then
    local n = (mv and mv > 0 and mv < t.qty) and mv or nil
    local cnt = n and (fmt(n) .. "/" .. fmt(t.qty) .. " ") or ""
    if t.kind == "buy" then
      AddMenuItem("Partial - bought " .. cnt .. "- need alternatives for the rest", function() setState(t, "partial", n, "buy_alt") end)
    else
      AddMenuItem("Partial - sold/listed " .. cnt .. "- keeping the rest as stock", function() setState(t, "partial", n, "sell_keep") end)
    end
  end
  AddMenuItem("Skip for now", function() setState(t, "skip") end)
  AddMenuItem("Remove from list (don't suggest again)", function() setState(t, "remove") end)
  if s ~= "open" then AddMenuItem("Reset to open", function() setState(t, "open") end) end
  ShowMenu(ctrl)
end

local function buildUI()
  local wm = WINDOW_MANAGER
  local win = wm:CreateTopLevelWindow("CoachClaudeWindow")
  CC.win = win
  win:SetDimensions(WIDTH, 200)
  win:SetMovable(true); win:SetMouseEnabled(true); win:SetClampedToScreen(true)
  win:SetHidden(true)
  local p = CC.sv.pos
  if p then win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, p.x, p.y)
  else win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
  win:SetHandler("OnMoveStop", function(self) CC.sv.pos = { x = self:GetLeft(), y = self:GetTop() } end)

  local bg = wm:CreateControlFromVirtual("$(parent)BG", win, "ZO_DefaultBackdrop")
  bg:SetAnchorFill(win)

  CC.title = wm:CreateControl("$(parent)Title", win, CT_LABEL)
  CC.title:SetFont("ZoFontWinH4"); CC.title:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 8)

  CC.sub = wm:CreateControl("$(parent)Sub", win, CT_LABEL)
  CC.sub:SetFont("ZoFontGameSmall"); CC.sub:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 34)

  local close = wm:CreateControl("$(parent)Close", win, CT_LABEL)
  close:SetFont("ZoFontWinH4"); close:SetText("X"); close:SetMouseEnabled(true)
  close:SetAnchor(TOPRIGHT, win, TOPRIGHT, -12, 8)
  close:SetHandler("OnMouseUp", function() CC.Show(false) end)

  CC.fold = wm:CreateControl("$(parent)Fold", win, CT_LABEL)
  CC.fold:SetFont("ZoFontWinH4"); CC.fold:SetMouseEnabled(true)
  CC.fold:SetAnchor(TOPRIGHT, close, TOPLEFT, -14, 0)
  CC.fold:SetHandler("OnMouseUp", function() CC.sv.collapsed = not CC.sv.collapsed; CC.Refresh() end)

  CC.gear = wm:CreateControl("$(parent)Gear", win, CT_LABEL)
  CC.gear:SetFont("ZoFontGameBold"); CC.gear:SetMouseEnabled(true)
  CC.gear:SetAnchor(RIGHT, CC.fold, LEFT, -16, 0)
  CC.gear:SetHandler("OnMouseUp", function(_, _, upInside)
    if upInside then CC.ToggleSettings() end
  end)
  CC.gear:SetHandler("OnMouseEnter", function(self) tooltip(self, "Rules for approved buys: tolerance, gold cap, keep-at-least, dry run.") end)
  CC.gear:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

  CC.tabs = {}
  for i = 1, 7 do
    local t = wm:CreateControl("$(parent)Tab" .. i, win, CT_LABEL)
    t:SetFont("ZoFontGameBold"); t:SetMouseEnabled(true)
    if i == 1 then t:SetAnchor(TOPLEFT, win, TOPLEFT, 12, 58)
    else t:SetAnchor(LEFT, CC.tabs[i - 1], RIGHT, 16, 0) end
    t:SetHandler("OnMouseUp", function(self, _, upInside)
      if upInside and self.tabName then CC.sv.tab = self.tabName; CC.page = 1; CC.Refresh() end
    end)
    t:SetHandler("OnMouseEnter", function(self)
      local notes = (CoachClaude_Tasks and CoachClaude_Tasks.sectionNotes) or {}
      if self.tabName and notes[self.tabName] then tooltip(self, notes[self.tabName]) end
    end)
    t:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    CC.tabs[i] = t
  end

  CC.rows = {}
  for i = 1, ROWS do
    local r = wm:CreateControl("$(parent)Row" .. i, win, CT_LABEL)
    r:SetFont("ZoFontGame")
    r:SetDimensions(WIDTH - 24, ROW_H)
    r:SetAnchor(TOPLEFT, win, TOPLEFT, 12, TOP + (i - 1) * ROW_H)
    r:SetMouseEnabled(true)
    r:SetHandler("OnMouseEnter", function(self) if self.line then tooltip(self, self.line.kind == "task" and taskTip(self.line.task) or self.line.tip) end end)
    r:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
    r:SetHandler("OnMouseUp", function(self, button, upInside)
      if not upInside or not self.line then return end
      local l = self.line
      if l.kind == "head" then
        CC.sv.folded[l.group] = not CC.sv.folded[l.group] or nil
        CC.Refresh()
      elseif l.kind == "section" then
        CC.sv.folded[l.key] = not CC.sv.folded[l.key] or nil
        CC.Refresh()
      elseif l.kind == "task" then
        if button == MOUSE_BUTTON_INDEX_RIGHT then
          taskMenu(self, l.task)
        else
          local s = stateOf(l.task)
          if actionable(l.task) then
            -- open -> approved -> done -> open
            if s == "approved" then setState(l.task, "done", l.task.qty)
            elseif s == "done" then setState(l.task, "open")
            else setState(l.task, "approved") end
          else
            setState(l.task, s == "done" and "open" or "done", l.task.qty)
          end
        end
      elseif l.kind == "setting" then
        CC.Store.ChangeSetting(l.key, button == MOUSE_BUTTON_INDEX_RIGHT)
      elseif l.kind == "storeRun" then
        CC.Store.Run()
      elseif l.kind == "decision" then
        if button == MOUSE_BUTTON_INDEX_RIGHT then CC.Store.Skip(l.opt) else CC.Store.Take(l.opt) end
      end
    end)
    CC.rows[i] = r
  end

  CC.pager = wm:CreateControl("$(parent)Pager", win, CT_LABEL)
  CC.pager:SetFont("ZoFontGameSmall"); CC.pager:SetMouseEnabled(true)
  CC.pager:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -12, -6)
  CC.pager:SetHandler("OnMouseUp", function(_, button)
    CC.page = (CC.page or 1) + ((button == MOUSE_BUTTON_INDEX_RIGHT) and -1 or 1)
    local pages = math.max(1, math.ceil(#(CC.lines or {}) / ROWS))
    if CC.page > pages then CC.page = 1 elseif CC.page < 1 then CC.page = pages end
    CC.Refresh()
  end)
end

function CC.ToggleSettings()
  if CC.view == "settings" then CC.view = nil else CC.view = "settings" end
  CC.page = 1
  CC.Refresh()
end

local function slash(arg)
  arg = (arg or ""):lower()
  if arg == "reset" then
    CC.sv.state = {}; CC.Refresh(); d("[Coach Claude] All ticks cleared (removed tasks restored).")
  elseif arg == "fold" then
    CC.sv.collapsed = not CC.sv.collapsed; CC.Refresh()
  elseif arg == "run" then
    if CC.atStore then CC.Store.Run() else d("[Coach Claude] Open a guild store first.") end
  elseif arg == "dry" then
    CC.sv.rules.dry = not CC.sv.rules.dry; CC.Refresh()
    d("[Coach Claude] Dry run " .. (CC.sv.rules.dry and "ON - nothing will be bought." or "OFF - approved buys will spend gold."))
  elseif arg == "settings" then
    CC.ToggleSettings(); CC.Show(true)
  elseif arg == "help" then
    d("[Coach Claude] /coach show/hide | /coach fold | /coach reset | /coach settings | /coach run (at a store) | /coach dry")
    d("Left-click task = done. Right-click = partial / skip / remove. Click group header = fold. /reloadui saves for your coach.")
  else
    CC.Show(CC.win:IsHidden())
  end
end

local function onLoaded(_, addon)
  if addon ~= CC.name then return end
  EVENT_MANAGER:UnregisterForEvent(CC.name, EVENT_ADD_ON_LOADED)
  CC.sv = ZO_SavedVars:NewAccountWide("CoachClaude_SV", 1, nil,
    { state = {}, log = {}, base = {}, folded = {}, visible = true, collapsed = false })
  -- migrate v1.0 plain-string states
  for id, v in pairs(CC.sv.state) do
    if type(v) == "string" then CC.sv.state[id] = { s = v, t = GetTimeStamp() } end
  end
  CC.sv.base = CC.sv.base or {}; CC.sv.folded = CC.sv.folded or {}
  CC.Store.Init()
  CC.sv.lastGenerated = CoachClaude_Tasks and CoachClaude_Tasks.generated
  -- baseline inventory per task the first time a plan is seen
  for _, g in ipairs(groups()) do
    for _, t in ipairs(g.tasks or {}) do
      if CC.sv.base[t.id] == nil then CC.sv.base[t.id] = haveCount(t) end
    end
  end
  buildUI()
  SLASH_COMMANDS["/coach"] = slash
  EVENT_MANAGER:RegisterForEvent(CC.name, EVENT_OPEN_TRADING_HOUSE, function()
    CC.atStore = true
    zo_callLater(function() CC.Show(true) end, 400)
  end)
  EVENT_MANAGER:RegisterForEvent(CC.name, EVENT_OPEN_BANK, function() CC.inv = nil; CC.Refresh() end)
  EVENT_MANAGER:RegisterForEvent(CC.name, EVENT_CLOSE_TRADING_HOUSE, function() CC.atStore = false; CC.Refresh() end)
  EVENT_MANAGER:RegisterForEvent(CC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
    CC.inv = nil
    if CC.win and not CC.win:IsHidden() and not CC.pending then
      CC.pending = true
      zo_callLater(function() CC.pending = false; CC.Refresh() end, 500)
    end
  end)
  if CC.sv.visible then CC.Show(true) end
end

EVENT_MANAGER:RegisterForEvent(CC.name, EVENT_ADD_ON_LOADED, onLoaded)
