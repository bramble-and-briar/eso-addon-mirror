local LF = LetsFurnish
local L, count, sentences, list, ask = LF.L, LF.count, LF.sentences, LF.list, LF.ask
local unrecordable = LF.unrecordable
local WIDTH, PAD = 820, 16
local MOST_ROWS, LEAST_ROWS, MARGIN = 8, 4, 20
local ROW, ICON, ICON_GAP = 52, 40, 27
local BAR, ARROW = 16, 16
local LIST_TOP, LIST_RIGHT = 176, WIDTH - PAD - BAR - 6
local FOOT = 80
local BUTTON = 120
local BUTTON_X = LIST_RIGHT - BUTTON
local WHERE, POINTER = 64, 32
local PROGRESS_WIDTH, PROGRESS_HEIGHT = 315, 20
local STOP = 80
local NAME_X = PAD + 6 + ICON + ICON_GAP
local NAMES = { apply = 290, needs = 250, backups = 160, other = 250, crafting = 120 }
local HALF = (LIST_RIGHT - PAD) / 2
local SHIFT = HALF + 4
local CHECK = 16
local SIDE_W, SIDE_TOP = 400, 96
local PRICE = 100
local PRICE_OPTIONS = { showTooltips = false, font = "ZoFontGameShadow", iconSide = RIGHT }
local TOTAL_OPTIONS = { showTooltips = false, font = "ZoFontGameLargeBold", iconSide = RIGHT }
local SIDE_PRICED, SIDE_FOOT = 416, 60
local MODE = 104
local SIDE_COLS = { name = { 66, 80 }, have = { 150, 70 }, each = { 224, 72 }, cost = { 300, 76 } }
local COLUMN = { { x = PAD, width = LIST_RIGHT - PAD - BAR - 8, icon = 6 + CHECK + 6, top = LIST_TOP + ROW, name = 250 },
                 { x = 12, width = SIDE_W - 12 - BAR - 16, icon = 6, top = SIDE_TOP, name = 130 } }
local TICKS = 126
local ART = "EsoUI/Art/"
local POINTER_ART = ART .. "Housing/housing_retrievalDirctionArrow.dds"
local WHERE_UPDATE, WHERE_MS = "LetsFurnishWindowWhere", 250
local TABS = {
    { "layouts", L.window.layouts, "Journal/journal_tabIcon_loreLibrary", L.window.layouts_lead, "" },
    { "apply", L.window.apply, "Housing/Keyboard/furniture_tabIcon_place", nil, L.window.apply_status },
    { "needs", L.window.needs, "Crafting/blueprints_tabIcon", nil, "" },
    { "backups", L.window.backups, "Guild/tabIcon_history", L.window.backups_lead, L.window.backups_status },
    { "share", L.window.share, "Mail/mail_tabIcon_compose", nil, "" },
    { "settings", L.window.settings, "Housing/Keyboard/furniture_tabIcon_settings", nil, "" },
}
local LISTS = { { "layouts", "here", L.window.this_house, L.window.empty_here }, { "layouts", "every", L.window.every_house, L.window.empty_every },
                { "apply", "place", L.window.to_place, L.window.empty_place }, { "apply", "move", L.window.to_move, L.window.empty_move },
                { "apply", "remove", L.window.to_remove, L.window.empty_remove }, { "apply", "missing", L.window.missing, L.window.empty_missing },
                { "apply", "inplace", L.window.in_place, L.window.empty_in_place },
                { "needs", "all", L.window.all_needed, L.window.empty_needed }, { "needs", "missing", L.window.missing, L.window.empty_needs_missing },
                { "needs", "uncraftable", L.window.not_craftable, L.window.empty_not_craftable },
                { "needs", "crafting", L.window.crafting, L.window.empty_crafting },
                { "backups", "hand", L.window.manual_backups, L.window.no_backup },
                { "backups", "auto", L.window.automatic_backups, L.window.no_backup },
                { "settings", "take", L.window.take_from, "" }, { "settings", "put", L.window.put_into, "" },
                { "settings", "prices", L.window.prices, "" }, { "settings", "speed", L.window.speed, "" },
                { "settings", "log", L.window.log, L.window.empty_log } }
local WORK = { "place", "move", "remove", "missing" }
local SOURCES = { app = { ART .. "Housing/Keyboard/furniture_tabIcon_place_up.dds", L.window.from_app },
                  code = { ART .. "Mail/mail_tabIcon_compose_up.dds", L.window.from_code },
                  recorded = { ART .. "Miscellaneous/clipboard_up.dds", L.window.recorded_here } }
local GONE = { app = L.window.gone_app, code = L.window.gone_code, recorded = L.window.gone_recorded }
local REASONS = { hand = { L.window.made_by_hand }, apply = { L.window.before_applying_unnamed, L.window.before_applying },
                  rollback = { L.window.before_rollback }, change = { L.window.before_change_unnamed, L.window.before_change } }
local DIALOG, NAME_DIALOG, PROBLEM_DIALOG = "LETSFURNISH_CONFIRM", "LETSFURNISH_NAME", "LETSFURNISH_PROBLEM"
local REFRESH_WAIT = 300
local W = { tab = "layouts", list = { layouts = "here", apply = "place", needs = "all", backups = "hand", settings = "take" }, offset = 0, sources = {}, picked = {}, rows = {}, lists = {},
            footers = {}, recording = {}, shown = {}, ticked = {}, checks = {}, visible = MOST_ROWS }
LF.window = W
if ZO_CreateStringId then ZO_CreateStringId("SI_BINDING_NAME_LETSFURNISH_TOGGLE", L.window.binding) end
local function red(text)
    return "|cff6060" .. text .. "|r"
end
local function game(id, ours)
    return LF.nonempty(id and ask(GetString, id) or "") or ours
end
local function name()
    W.controls = (W.controls or 0) + 1
    return "LetsFurnishWindow" .. W.controls
end
local function put(c, parent, x, y)
    if y < 0 then c:SetAnchor(TOPLEFT, parent, BOTTOMLEFT, x, y) else c:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y) end
end
local function label(parent, font, x, y, width, height, color)
    local c = WINDOW_MANAGER:CreateControl(name(), parent, CT_LABEL)
    c:SetFont(font)
    put(c, parent, x, y)
    c:SetDimensions(width, height)
    c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    if color then c:SetColor(color:UnpackRGBA()) end
    return c
end
local function texture(parent, x, y, width, height)
    local c = WINDOW_MANAGER:CreateControl(name(), parent, CT_TEXTURE)
    put(c, parent, x, y)
    c:SetDimensions(width, height)
    return c
end
local function textTip(owner, first, ...)
    if not first then return end
    InitializeTooltip(InformationTooltip, owner, BOTTOM, 0, -10)
    SetTooltipText(InformationTooltip, first)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line and line ~= "" then InformationTooltip:AddLine(line, "", ZO_NORMAL_TEXT:UnpackRGBA()) end
    end
end
local function hideTips()
    ClearTooltip(InformationTooltip)
    ClearTooltip(ItemTooltip)
end
local function button(parent, text, x, y, width, onClicked, tip, iconTemplate)
    local c = WINDOW_MANAGER:CreateControlFromVirtual(name(), parent, iconTemplate or "ZO_DefaultButton")
    if iconTemplate then c:ClearAnchors() else c:SetText(text) end
    put(c, parent, x, y)
    c:SetDimensions(width, 28)
    c.tip = tip
    c:SetHandler("OnClicked", function()
        onClicked()
        W.paint()
    end)
    c:SetHandler("OnMouseEnter", function()
        local why = c.why and red(c.why) or nil
        if iconTemplate then textTip(c, text, c.tip, why)
        elseif c.tip then textTip(c, c.tip, why)
        else textTip(c, why) end
    end)
    c:SetHandler("OnMouseExit", hideTips)
    return c
end
local function allow(c, why)
    c:SetEnabled(why == nil)
    c.why = why
end
local function confirm(title, text, yes, go)
    ZO_Dialogs_ShowDialog(DIALOG, { title = title, text = text, yes = yes, go = function()
        go()
        W.paint()
    end })
end
local function keyOf(entry)
    local plan = entry.plan
    return entry.source .. ":" .. tostring((type(plan) == "table" and plan.id) or entry.key or entry.name)
end
local function activeEntry()
    local key, here, first = LF.saved.active, GetCurrentZoneHouseId(), nil
    for _, entry in ipairs(LF.listed()) do
        if key and keyOf(entry) == key then return entry end
        if not first and here ~= 0 and entry.house_id == here and entry.source ~= "recorded" and type(entry.plan.items) == "table" then first = entry end
    end
    return first
end
local function chosen()
    local entry, here = activeEntry(), GetCurrentZoneHouseId()
    W.activeKey = entry and keyOf(entry) or nil
    if entry and here ~= 0 and entry.house_id == here and type(entry.plan.items) == "table" then
        W.elsewhere = nil
        return entry.plan
    end
    W.elsewhere = entry
    return nil
end
local function activate(entry)
    LF.saved.active = keyOf(entry)
    W.activeKey = LF.saved.active
end
local function applied(layout)
    local done = LF.saved.applied and LF.saved.applied[tostring(layout.id)]
    if type(done) ~= "table" or (tonumber(done.started) or 0) < (tonumber(layout.sent) or 0) then return nil end
    return done
end
local function slotsText(slots)
    local parts = {}
    for _, slot in ipairs(slots) do
        if slot.most > 0 then
            local after = slot.placed + slot.adding - slot.freeing
            local change = (slot.adding > 0 or slot.freeing > 0) and string.format(" -> %d", after) or ""
            local text = string.format("%s %d/%d%s", slot.name, slot.placed, slot.most, change)
            parts[#parts + 1] = slot.placed + slot.adding > slot.most and red(text) or text
        end
    end
    return table.concat(parts, "   ")
end
local function previewed()
    local entry = activeEntry()
    if entry then return entry.plan, entry end
    return nil
end
local function popup(link)
    link = LF.nonempty(link)
    return link and function() ZO_PopupTooltip_SetLink(link) end or nil
end
local function qualityOf(link, placed)
    if placed then return ask(GetPlacedHousingFurnitureDisplayQuality, placed) end
    return link and ask(GetItemLinkDisplayQuality, link) or nil
end
local function furnishing(entry, row)
    if row and row.kind == "collectible" then
        entry.collectible = row.item_id
    elseif row then
        entry.link = LF.itemLink(row)
    end
    entry.quality = qualityOf(entry.link, entry.placed)
    return entry
end
local function askDelete(entry)
    confirm(L.window.delete_layout, sentences(zo_strformat(L.window.delete_layout_ask, entry.name), GONE[entry.source]), L.window.delete,
            function() LF.forgetLayout(entry) end)
end
local function askName(title, text, initial, yes, go)
    local dialog = ZO_Dialogs_ShowDialog(NAME_DIALOG, { title = title, text = text, yes = yes, go = go, letsFurnish = true }, { initialEditText = initial })
    local edit = dialog and dialog:GetNamedChild("EditBox")
    if edit and W.enterHooked ~= edit then
        W.enterHooked = edit
        ZO_PreHookHandler(edit, "OnEnter", function()
            local shown = dialog.data
            if dialog:IsHidden() or type(shown) ~= "table" or not shown.letsFurnish then return false end
            W.named(dialog)
            return true
        end)
    end
end
function W.named(dialog)
    local data = dialog.data
    local ok, why = data.go(ZO_Dialogs_GetEditBoxText(dialog) or "")
    if ok then
        ZO_Dialogs_ReleaseDialog(NAME_DIALOG)
        W.paint()
        return
    end
    data.why = why
    ZO_Dialogs_RefreshDialogText(NAME_DIALOG, dialog)
end
function W.keepName(backup)
    askName(L.window.keep_backup_title, L.window.keep_backup_name_ask, backup.meta and backup.meta.name or "", L.window.keep_backup_save, function(name)
        return LF.keepBackup(backup, name)
    end)
end
function LF.offerKeep(backup, text, partly)
    if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
        return zo_callLater(function() LF.offerKeep(backup, text, partly) end, 500)
    end
    local offer = partly and L.window.keep_backup_offer_after or L.window.keep_backup_offer
    confirm(L.window.keep_backup_title, text .. "\n\n" .. offer, L.window.keep_backup_button, function()
        zo_callLater(function() W.keepName(backup) end, 0)
    end)
end
local function recordNamed()
    local why = unrecordable()
    if why then
        LF.say(why)
        return LF.alert(why)
    end
    local house = LF.houseName(GetCurrentZoneHouseId())
    askName(L.window.record_house, zo_strformat(L.window.name_ask, house), string.format("%s %s", house, LF.stamp(GetTimeStamp())), L.window.record,
            function(name) return LF.export(name, true) end)
end
local function askRename(entry)
    askName(L.window.rename_title, zo_strformat(L.window.rename_ask, entry.name), entry.name, L.window.rename_button,
            function(name) return LF.rename(entry, name) end)
end
local function layoutRow(entry, mine)
    local recorded = entry.source == "recorded"
    local active = W.activeKey ~= nil and keyOf(entry) == W.activeKey
    local said = SOURCES[entry.source][2]
    if recorded and not mine then said = L.window.recorded end
    local state = L.window.not_applied
    local done = applied(entry.plan)
    if active and mine then
        state = recorded and L.window.active_recorded or L.window.active
    elseif active then
        state = zo_strformat(L.window.active_needs, LF.houseName(entry.house_id))
    elseif done and done.finished then
        state = ZO_SUCCEEDED_TEXT:Colorize(zo_strformat(L.window.applied, LF.stamp(done.finished)))
    elseif done then
        state = zo_strformat(L.window.begun, LF.stamp(done.started))
    elseif recorded then
        state = L.window.for_the_app
    end
    local function activateIt() activate(entry) end
    local menu = {}
    if not active then menu[#menu + 1] = { L.window.activate, activateIt } end
    if entry.source ~= "app" then menu[#menu + 1] = { L.window.rename, function() askRename(entry) end } end
    menu[#menu + 1] = { L.window.delete, function() askDelete(entry) end }
    return { name = entry.name, icon = SOURCES[entry.source][1], note = zo_strformat(L.window.layout_note, said, count(L.window.furnishings, entry.count), state),
             chosen = active, double = not active and activateIt or nil,
             hints = not active and { (recorded and mine) and L.window.hint_activate_recorded or L.window.hint_activate } or nil,
             button = { L.window.activate, activateIt, why = active and L.window.already_active or nil }, menu = menu }
end
local function at(backup)
    for i, kept in ipairs(LF.backups()) do
        if kept == backup then return i end
    end
end
local function backupRow(backup)
    local reason, layout = LF.reasonOf(backup)
    local words = REASONS[reason] or {}
    local why = (layout and words[2]) and zo_strformat(words[2], layout) or words[1] or ""
    local when = LF.backupName(backup)
    local function rollBack()
        local plan, refusal = LF.rollbackPlan(at(backup))
        if not plan then return LF.say(refusal) end
        if #plan.blocks > 0 then return LF.offerKeepBackup(backup, LF.blockedText(plan), table.concat(plan.blocks, " ")) end
        if #plan.steps == 0 then return LF.say(L.house.already_as) end
        confirm(L.window.roll_back, zo_strformat(L.window.roll_back_ask, when, plan.summary), L.window.roll_back, function()
            if at(backup) then LF.rollback(at(backup), true) end
        end)
    end
    local function forget()
        confirm(L.window.delete_backup, zo_strformat(L.window.delete_backup_ask, when), L.window.delete, function()
            LF.forgetBackup(backup)
        end)
    end
    return { name = when, icon = ART .. "Guild/tabIcon_history_up.dds", note = count(L.window.furnishings, #backup.items) .. "\n" .. why,
             button = { L.window.roll_back, rollBack, changes = true },
             menu = { { L.window.roll_back, rollBack, changes = true }, { L.window.keep_backup_menu, function() W.keepName(backup) end }, { L.window.delete, forget } } }
end
local LOG_KINDS = { run = L.window.log_kind_run, remove = L.window.log_kind_remove, ["remove one"] = L.window.log_kind_remove_one,
                    rollback = L.window.log_kind_rollback, ["by hand"] = L.window.log_kind_by_hand }
local LOG_WHAT = { failed = L.window.log_what_failed, error = L.window.log_what_error, absent = L.window.log_what_absent,
                   unconfirmed = L.window.log_what_unconfirmed, unanswered = L.window.log_what_unanswered, refused = L.window.log_what_refused,
                   not_taken = L.window.log_what_not_taken, late = L.window.log_what_late, not_put_away = L.window.log_what_not_put_away,
                   conform = L.window.log_what_conform, stopped = L.window.log_what_stopped, skipped = L.window.log_what_skipped }
local LOG_WHY = { too_fast = L.window.log_why_too_fast, no_place = L.window.log_why_no_place, left_house = L.window.log_why_left_house,
                  not_owner = L.window.log_why_not_owner, stop = L.window.log_why_stop, path_unconfirmed = L.window.log_why_path_unconfirmed }
local function conformWord(v)
    if v == true then return L.window.log_conform_on elseif v == false then return L.window.log_conform_off end
    return v == "timeout" and L.window.log_got_timeout or L.window.log_got_unread
end
local function logRows()
    local out = {}
    for _, run in ipairs(type(LF.saved.runs) == "table" and LF.saved.runs or {}) do
        local events = type(run.events) == "table" and run.events or {}
        local how = (run.how == "finished" and L.window.log_finished) or (run.how == "stopped" and L.window.log_stopped) or L.window.log_going
        local problems, solved = #events + (run.dropped or 0), 0
        for _, e in ipairs(events) do if e.solved then solved = solved + 1 end end
        out[#out + 1] = { name = zo_strformat(L.window.log_title, LOG_KINDS[run.kind] or tostring(run.kind), tostring(run.name or "")),
                          icon = ART .. "Guild/tabIcon_history_up.dds",
                          note = table.concat({ LF.seenText(run.started), how, problems > 0 and count(L.window.log_problems, problems) or L.window.log_no_problems,
                                                solved > 0 and count(L.window.log_solved_count, solved) or nil }, " · "),
                          hints = {} }
        local hints = out[#out].hints
        if run.said then hints[#hints + 1] = run.said end
        if (run.dropped or 0) > 0 then hints[#hints + 1] = count(L.window.log_dropped, run.dropped) end
        for _, e in ipairs(events) do
            local parts = { LOG_WHAT[e.what] or tostring(e.what) }
            if e.place_name then parts[#parts + 1] = e.place_name end
            if e.answer then parts[#parts + 1] = e.answer elseif e.code ~= nil then parts[#parts + 1] = zo_strformat(L.core.refused_code, tostring(e.code)) end
            if e.why then parts[#parts + 1] = LOG_WHY[e.why] or tostring(e.why) end
            if e.what == "conform" then parts[#parts + 1] = zo_strformat(L.window.log_conform, conformWord(e.want), conformWord(e.got)) end
            local places = {}
            for line in string.gmatch(tostring(e.places or ""), "[^;]+") do places[#places + 1] = (string.gsub(line, "^%s+", "")) end
            if places[1] then parts[#parts + 1] = places[1] end
            local pause = (string.format("%.1f", (tonumber(e.retry_ms) or 0) / 1000):gsub("%.", L.window.decimal_point))
            local solvedWords = (e.solved == "retried" and zo_strformat(L.window.log_solved_retried, pause))
                                or (e.solved == "other_place" and zo_strformat(L.window.log_solved_other_place, e.solved_place or ""))
                                or (e.solved == "late" and L.window.log_solved_late) or (e.solved == "corrected" and L.window.log_solved_corrected) or nil
            local at = zo_strformat(L.window.log_step, tostring(e.step or 0), (string.format("%.1f", (tonumber(e.ms) or 0) / 1000):gsub("%.", L.window.decimal_point)))
            local hints = {}
            for _, line in ipairs(places) do hints[#hints + 1] = line end
            for _, v in ipairs({ e.error or "", e.thing or "", e.id or "", e.uid or "" }) do
                if v ~= "" then hints[#hints + 1] = tostring(v) end
            end
            local note = table.concat(parts, ": ") .. "\n" .. (solvedWords and (ZO_SUCCEEDED_TEXT:Colorize(solvedWords) .. " · " .. at) or at)
            out[#out + 1] = { name = e.name or e.thing or parts[1], note = note, hints = hints }
        end
    end
    return out
end
local function needRows(which)
    local out = {}
    if which == "crafting" then
        local ok, craftable = pcall(LF.craftable, W.need or {})
        if not ok then W.needsFailed = W.needsFailed or tostring(craftable) end
        out.count = ok and #craftable or 0
        return out
    end
    for _, need in ipairs(W.need or {}) do
        if which == "all" or (need.missing > 0 and (which == "missing" or not need.recipe)) then
            local ticked = W.ticked[need.what] == true
            local _, short = LF.placesText(need)
            out[#out + 1] = { name = need.name, icon = need.icon, pick = popup(need.link), note = LF.needText(need, red, which == "uncraftable"), chosen = ticked, price = need.price,
                              where = #need.places > 1 and LF.placeLines(need) or nil, whereShort = short,
                              link = need.kind ~= "collectible" and need.link or nil, collectible = need.kind == "collectible" and need.id or nil,
                              quality = need.kind ~= "collectible" and qualityOf(need.link) or nil }
        end
    end
    return out
end
local function tickAll()
    for _, entry in ipairs(LF.craftable(W.need or {})) do
        if entry.recipe.tickable then W.ticked[entry.need.what] = true end
    end
    if not W.sideOnce then W.sideOpen, W.sideOnce = true, true end
end
local function editAt(id)
    local why = LF.editRefused()
    if why then return LF.say(why) end
    W.hide()
    LF.editInPlace(id)
end
local function standing(action, id)
    local menu = { { game(SI_HOUSING_EDITOR_PRECISION_EDIT, L.window.edit), function() editAt(id) end },
                   { game(SI_WORLD_MAP_ACTION_SET_PLAYER_WAYPOINT, L.window.destination), function() LF.waypoint(id) end } }
    if action then table.insert(menu, 1, action) end
    return menu
end
local function everyHouse(entries, here)
    local rows, groups, byId = { count = #entries }, {}, {}
    for _, entry in ipairs(entries) do
        local id = tonumber(entry.house_id) or 0
        local group = byId[id]
        if not group then
            group = { id = id, name = LF.houseName(id), layouts = {} }
            byId[id], groups[#groups + 1] = group, group
        end
        group.layouts[#group.layouts + 1] = entry
    end
    table.sort(groups, function(a, b)
        if here ~= 0 and (a.id == here or b.id == here) then return a.id == here and b.id ~= here end
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    local expanded = type(LF.saved.expandedHouses) == "table" and LF.saved.expandedHouses or {}
    for _, group in ipairs(groups) do
        local key = tostring(group.id)
        local open = expanded[key]
        if open == nil then open = #groups == 1 or (here ~= 0 and group.id == here) end
        local function toggle()
            LF.saved.expandedHouses = expanded
            expanded[key] = not open
        end
        rows[#rows + 1] = { name = group.name, note = count(L.window.layouts_count, #group.layouts), houseGroup = true,
                            icon = ART .. (open and "Buttons/tree_open_up.dds" or "Buttons/tree_closed_up.dds"),
                            pick = toggle, menu = { { open and L.window.collapse or L.window.expand, toggle } } }
        if open then
            for _, entry in ipairs(group.layouts) do rows[#rows + 1] = layoutRow(entry, here ~= 0 and group.id == here) end
        end
    end
    return rows
end
local function listRows(tab, which)
    local out, here = {}, GetCurrentZoneHouseId()
    if tab == "layouts" then
        local layouts = LF.listed()
        if which == "every" then return everyHouse(layouts, here) end
        for _, entry in ipairs(layouts) do
            if here ~= 0 and entry.house_id == here then out[#out + 1] = layoutRow(entry, true) end
        end
        return out
    elseif tab == "backups" then
        for _, backup in ipairs(here ~= 0 and LF.backups() or {}) do
            if LF.backupKind(backup) == which then out[#out + 1] = backupRow(backup) end
        end
        return out
    elseif tab == "needs" then
        return needRows(which)
    elseif tab == "settings" and which == "log" then
        return logRows()
    elseif tab == "settings" then
        out.count = (which == "take" or which == "put") and #LF.places(which) or nil
        return out
    elseif tab ~= "apply" then
        return out
    end
    if which == "inplace" then
        for _, standing_ in ipairs(W.diff and W.diff.inPlace or {}) do
            local id = standing_.id
            out[#out + 1] = furnishing({ name = standing_.name, icon = standing_.icon, note = ZO_SUCCEEDED_TEXT:Colorize(L.window.stands_in_place),
                                         placed = id, pick = function() editAt(id) end, button = { L.window.edit, function() editAt(id) end },
                                         menu = standing(nil, id) }, standing_.row)
        end
        return out
    end
    for _, task in ipairs(W.diff and W.diff.tasks or {}) do
        local placing = task.action == "item" or task.action == "collectible"
        if which == "missing" and task.missing then
            out[#out + 1] = furnishing({ name = task.name, icon = task.icon, note = red(L.window.not_anywhere) }, task.row)
        elseif which == "place" and placing and not task.missing then
            local several = #task.sources > 1 and task.uid ~= nil
            local n = several and math.min(W.sources[task.uid] or 1, #task.sources) or 1
            local source = task.sources[n]
            local place = { L.window.place, function() W.act(task, n) end, changes = true }
            local menu = { place }
            for i, other in ipairs(several and task.sources or {}) do
                if i ~= n then menu[#menu + 1] = { zo_strformat(L.window.from_place, other.place, other.count), function() W.sources[task.uid] = i end } end
            end
            out[#out + 1] = furnishing({ name = task.name, icon = task.icon, stack = source.count, button = place, menu = menu,
                                         note = zo_strformat(L.window.from_place, source.place, source.count) .. (several and "\n" .. L.window.another_place or ""),
                                         turn = several and function() W.sources[task.uid] = n % #task.sources + 1 end or nil }, task.row)
        elseif which == "move" and (task.action == "move" or task.action == "state" or task.action == "path") then
            local word = (task.action == "move" and L.window.move) or (task.action == "path" and L.window.set_path) or L.window.switch
            local act = { word, function() W.act(task) end, changes = true }
            local note = (task.action == "move" and L.window.stands_elsewhere) or (task.action == "path" and L.window.other_path) or L.window.other_state
            out[#out + 1] = furnishing({ name = task.name, icon = task.icon, note = note,
                                         placed = task.id, pick = function() editAt(task.id) end, button = act, menu = standing(act, task.id) }, task.row)
        elseif which == "remove" and task.action == "remove" then
            local act = { L.window.remove, function() W.act(task) end, changes = true }
            out[#out + 1] = furnishing({ name = task.name, icon = task.icon, note = L.window.not_in_layout, placed = task.id, pick = function() editAt(task.id) end,
                                         button = act, menu = standing(act, task.id) }, nil)
        end
    end
    return out
end
local function entries(tab, which)
    local key = tab .. ":" .. tostring(which)
    local made = W.made and W.made[key]
    if made then return made end
    made = listRows(tab, which)
    if W.made then W.made[key] = made end
    return made
end
local function context()
    local here = GetCurrentZoneHouseId()
    if W.tab == "share" then return L.window.share_context end
    if W.tab == "settings" then return L.window.settings_context end
    if W.tab == "needs" then
        local layout, entry = previewed()
        if not layout then return L.window.needs_none end
        return zo_strformat(L.window.needs_context, entry.name, entry.house_id and LF.houseName(entry.house_id) or "?")
    end
    if W.tab == "layouts" and W.list.layouts == "every" then return zo_strformat(L.window.every_house_count, count(L.window.layouts_count, W.shown.count)) end
    if here == 0 then return L.core.no_house end
    local house = LF.houseName(here)
    if W.tab == "layouts" then return zo_strformat(L.window.house_count, house, count(L.window.layouts_count, #W.shown)) end
    if W.tab == "backups" then
        return zo_strformat(L.window.house_count, house, count(L.window.backups_count, #LF.backups()))
    end
    if W.elsewhere and W.tab == "apply" then return tostring(W.elsewhere.name) end
    return W.layout and tostring(W.layout.name) or house
end
local function sized(rows)
    return rows.count or #rows
end
local function workLeft()
    local left = {}
    for _, key in ipairs(WORK) do left[key] = #entries("apply", key) end
    return left
end
local function emptyText()
    local here = GetCurrentZoneHouseId()
    if W.tab == "share" or (W.tab == "settings" and W.list.settings ~= "log") or (here == 0 and not (W.tab == "layouts" and W.list.layouts == "every") and W.tab ~= "needs") then return nil end
    if W.tab == "needs" and not previewed() then return L.window.no_needs, L.window.no_needs_hint end
    if W.tab == "needs" and W.list.needs == "crafting" and (W.shown.count or 0) > 0 then return nil end
    if W.tab == "backups" then return L.window.no_backup, L.window.no_backup_hint end
    if W.tab == "apply" and not W.layout and W.elsewhere then
        return zo_strformat(L.window.wrong_house, LF.houseName(W.elsewhere.house_id)), ""
    end
    if W.tab == "apply" and not W.layout then return L.window.nothing_received, L.window.nothing_received_hint end
    for _, entry in ipairs(LISTS) do
        if entry[1] == W.tab and entry[2] == W.list[W.tab] then
            local hint = (W.tab == "layouts" and L.window.layouts_hint) or (entry[2] == "crafting" and L.window.crafting_hint) or ""
            if W.tab == "apply" and W.diff then
                local left, none = workLeft(), true
                for _, key in ipairs(WORK) do none = none and left[key] == 0 end
                if none then hint = L.window.all_in_place end
            end
            return entry[4], hint
        end
    end
end
local function nameColor(entry)
    if entry and entry.quality then
        local r, g, b = ask(GetInterfaceColor, INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, entry.quality)
        if r then return r, g, b, 1 end
    end
    return ZO_SELECTED_TEXT:UnpackRGBA()
end
local function whereNow()
    local px, py, pz = ask(GetPlayerWorldPositionInHouse)
    local heading = ask(GetPlayerCameraHeading) or 0
    for _, row in ipairs(W.rows) do
        local id = row.entry and row.entry.placed
        local x, y, z
        if id and px then x, y, z = ask(HousingEditorGetFurnitureWorldPosition, id) end
        local known = x ~= nil
        row.where:SetHidden(not known)
        row.pointer:SetHidden(not known)
        if known then
            local metres = math.floor(math.sqrt((x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2) / 100)
            local format = game(SI_HOUSING_BROWSER_DISTANCE_AWAY_FORMAT)
            row.where:SetText(format and zo_strformat(format, metres) or zo_strformat(L.window.metres, metres))
            row.pointer:SetTextureRotation((math.atan2(x - px, z - pz) - heading) % (2 * math.pi))
        end
    end
end
local function show()
    local shown, rows = #W.shown, W.visible
    local most = math.max(0, shown - rows)
    W.offset = math.max(0, math.min(W.offset, most))
    local locked = LF.unchangeable(W.tab == "apply" and W.layout or nil)
    local nameWidth = NAMES[W.tab] or NAMES.other
    local priced = W.tab == "needs" and LF.pricesOn()
    for i, row in ipairs(W.rows) do
        local entry = i <= rows and W.shown[W.offset + i] or nil
        row.entry = entry
        local group = entry and entry.houseGroup
        if group ~= row.houseGroup then
            row.houseGroup = group
            local size = group and 24 or ICON
            row.icon:ClearAnchors()
            put(row.icon, W.control, PAD + 6, LIST_TOP + (i - 1) * ROW + (ROW - size) / 2)
            row.icon:SetDimensions(size, size)
            row.name:ClearAnchors()
            put(row.name, W.control, group and PAD + 38 or NAME_X, LIST_TOP + (i - 1) * ROW)
            row.name:SetFont(group and "ZoFontGameBold" or "ZoFontGame")
        end
        row.name:SetHidden(entry == nil)
        row.note:SetHidden(entry == nil)
        row.strip:SetHidden(entry == nil)
        row.highlight:SetHidden(not (entry and entry.chosen))
        row.over:SetHidden(not (entry and row.hovered))
        row.icon:SetHidden(not (entry and entry.icon))
        if entry and entry.icon then row.icon:SetTexture(entry.icon) end
        row.stack:SetText((entry and (entry.stack or 0) > 1) and tostring(entry.stack) or "")
        row.name:SetText(entry and entry.name or "")
        row.name:SetColor(nameColor(entry))
        row.note:SetText(entry and entry.note or "")
        row.name:SetDimensions(nameWidth, ROW)
        local right = (entry and entry.second) and (BUTTON_X - BUTTON - 4) or (entry and entry.button) and BUTTON_X or LIST_RIGHT
        if entry and entry.placed then right = right - WHERE - POINTER - 18 end
        if priced then right = right - PRICE - 12 end
        row.note:SetDimensions(right - 16 - NAME_X - nameWidth, ROW)
        W.setPrice(row.price, priced and entry and entry.price)
        row.note:SetColor(((entry and entry.chosen) and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT):UnpackRGBA())
        for _, slot in ipairs({ "button", "second" }) do
            local spec = entry and entry[slot]
            row[slot]:SetHidden(spec == nil)
            if spec then
                row[slot]:SetText(spec[1])
                allow(row[slot], (spec.changes and locked) or spec.why or nil)
            end
        end
    end
    whereNow()
    W.bar:SetHidden(most == 0)
    W.bar:SetEnabled(most > 0)
    W.bar:SetMinMax(0, most)
    W.bar:SetValue(W.offset)
    W.bar:SetThumbTextureHeight((rows * ROW - 2 * ARROW) * rows / math.max(shown, rows))
    W.range:SetText(shown > rows and zo_strformat(L.window.range, W.offset + 1, W.offset + rows, shown) or "")
end
local function scroll(rows)
    W.offset = W.offset + rows
    show()
end
local function enter(row)
    row.hovered = true
    local entry = row.entry
    row.over:SetHidden(entry == nil)
    if not entry then return end
    local link = LF.nonempty(entry.link)
    if entry.placed or link or entry.collectible then
        InitializeTooltip(ItemTooltip, row.strip, RIGHT, -15, 0, LEFT)
        if entry.placed then
            ItemTooltip:SetPlacedFurniture(entry.placed)
        elseif link then
            ItemTooltip:SetLink(link)
        else
            ItemTooltip:SetCollectible(entry.collectible, true)
        end
        local cut = entry.where and (entry.whereShort or (row.note.WasTruncated and row.note:WasTruncated()))
        if cut then
            InitializeTooltip(InformationTooltip, row.strip, LEFT, 15 + BAR + 6, 0, RIGHT)
            SetTooltipText(InformationTooltip, L.needs.where_title)
            for _, line in ipairs(entry.where) do InformationTooltip:AddLine(line, "", ZO_NORMAL_TEXT:UnpackRGBA()) end
        end
        return
    end
    InitializeTooltip(InformationTooltip, row.strip, RIGHT, -15, 0, LEFT)
    SetTooltipText(InformationTooltip, entry.name)
    local lines = { entry.note or "" }
    for _, hint in ipairs(entry.hints or {}) do lines[#lines + 1] = hint end
    if entry.menu and #entry.menu > 0 then lines[#lines + 1] = L.window.hint_more end
    for _, line in ipairs(lines) do
        if line ~= "" then InformationTooltip:AddLine(line, "", ZO_NORMAL_TEXT:UnpackRGBA()) end
    end
end
local function leave(row)
    row.hovered = false
    row.over:SetHidden(true)
    hideTips()
end
local function chatLink(entry)
    if not (entry and ask(IsChatSystemAvailableForCurrentPlatform) ~= false) then return nil end
    local link = LF.nonempty(entry.link)
    if not link and entry.collectible then link = LF.nonempty(ask(GetCollectibleLink, entry.collectible, LINK_STYLE_BRACKETS)) end
    if not link and entry.placed then
        local itemLink, collectibleLink = ask(GetPlacedFurnitureLink, entry.placed, LINK_STYLE_BRACKETS)
        link = LF.nonempty(itemLink) or LF.nonempty(collectibleLink)
    end
    return link
end
local function linkInChat(link)
    if not LF.nonempty(link) then return end
    if string.find(link, "^|H%d+:item:") and SI_TOOLTIP_ITEM_NAME then link = zo_strformat(SI_TOOLTIP_ITEM_NAME, link) end
    ZO_LinkHandler_InsertLink(link)
end
W.linkInChat = linkInChat
local function menuOf(entry)
    local items = {}
    for _, item in ipairs(entry and entry.menu or {}) do items[#items + 1] = item end
    local link = chatLink(entry)
    if link then items[#items + 1] = { game(SI_ITEM_ACTION_LINK_TO_CHAT, L.window.link_to_chat), function() linkInChat(link) end } end
    return items
end
local function menu(row, owner, entry)
    entry = entry or row.entry
    local items = menuOf(entry)
    if #items == 0 then return end
    local locked = LF.unchangeable(W.tab == "apply" and W.layout or nil)
    ClearMenu()
    for _, item in ipairs(items) do
        AddMenuItem(item[1], function()
            item[2]()
            W.paint()
        end, nil, nil, nil, nil, nil, nil, nil, nil, nil, not (item.changes and locked))
    end
    ShowMenu(owner or row.strip)
end
local SETTINGS_ROW, MOVE = 34, 32
local function arrow(c, way)
    local base = ART .. "Buttons/large_" .. way .. "arrow_"
    c:SetNormalTexture(base .. "up.dds")
    c:SetPressedTexture(base .. "down.dds")
    c:SetMouseOverTexture(base .. "over.dds")
    c:SetDisabledTexture(base .. "disabled.dds")
    c:SetDimensions(MOVE, MOVE)
    return c
end
local S = { offset = 0, rows = {} }
W.settings = S
local function placeDetail(kind, place)
    if not place.enabled then return red(place.why or "") end
    if kind == "take" then return count(L.window.furnishings, place.count or 0) end
    local format = SI_GAMEPAD_HOUSING_EDITOR_RETRIEVE_TO_BAG_FORMATTER and LF.nonempty(ask(GetString, SI_GAMEPAD_HOUSING_EDITOR_RETRIEVE_TO_BAG_FORMATTER) or "")
    if format then return zo_strformat(format, place.used, place.total) end
    return zo_strformat(L.window.slots_used, place.used, place.total)
end
local function firstPlace()
    local places = LF.removalOrder()
    return places[1] or LF.places("put")[1]
end
local function openSettings(kind)
    W.list.settings, S.offset = kind or W.list.settings, 0
    W.select("settings")
end
W.openSettings = openSettings
local function priceAtText(at)
    if at <= 0 then return L.window.price_at_low end
    if at >= 1 then return L.window.price_at_top end
    local share = math.floor(at * LF.PRICE_BAND * 1000 + 0.5) / 10
    local words = share == math.floor(share) and string.format("%d", share) or string.format("%.1f", share):gsub("%.", L.window.decimal_point)
    return zo_strformat(L.window.price_at, words)
end
local function drawPrices(on)
    local present, priced = LF.ttcPresent(), LF.pricesOn()
    local range, at = LF.priceSettings()
    for _, c in ipairs(S.prices) do c:SetHidden(not on) end
    S.ttc:SetHidden(not on)
    ZO_CheckButton_SetLabelText(S.ttc, present and L.window.ttc_check or L.window.ttc_absent)
    ZO_CheckButton_SetCheckState(S.ttc, present and LF.saved.ttc ~= false)
    ZO_CheckButton_SetEnableState(S.ttc, present)
    local why = (not present and L.window.ttc_absent) or (not priced and L.window.prices_off) or nil
    for _, choice in ipairs(S.ranges) do
        local pressed = choice.range == range
        choice.mark:SetHidden(not (on and pressed))
        choice.control:SetState(pressed and BSTATE_PRESSED or BSTATE_NORMAL, pressed)
        allow(choice.control, why)
    end
    S.slider:SetValue(at)
    S.slider:SetEnabled(why == nil)
    S.at:SetText(priceAtText(at))
    local example
    for _, need in ipairs(on and why == nil and W.need or {}) do
        local price = need.kind == "item" and LF.priceOf(need.link)
        if price then example = { name = need.name, price = price } break end
    end
    S.example:SetHidden(not (on and example))
    S.example:SetText(example and zo_strformat(L.window.price_example, example.name) or "")
    W.setPrice(S.examplePrice, example and example.price)
end
local function drawSpeed(on)
    local chosen = LF.stepDelay()
    for _, choice in ipairs(S.speeds or {}) do
        local pressed = choice.ms == chosen
        choice.control:SetHidden(not on)
        choice.mark:SetHidden(not (on and pressed))
        choice.control:SetState(pressed and BSTATE_PRESSED or BSTATE_NORMAL, pressed)
    end
    if S.speedNote then S.speedNote:SetHidden(not on) end
end
local function drawSettings()
    local on = W.tab == "settings"
    local kind = W.list.settings
    S.debug:SetHidden(not on or kind ~= "log")
    ZO_CheckButton_SetCheckState(S.debug, LF.debugEntry ~= nil)
    local places = (on and (kind == "take" or kind == "put")) and LF.places(kind, true) or {}
    local rows = math.floor(W.visible * ROW / SETTINGS_ROW)
    local most = math.max(0, #places - rows)
    S.offset = math.max(0, math.min(S.offset, most))
    S.kind, S.places = kind, places
    for i, row in ipairs(S.rows) do
        local n = S.offset + i
        local place = i <= rows and places[n] or nil
        row.place = place
        for _, c in ipairs({ row.strip, row.check, row.name, row.detail, row.up, row.down }) do c:SetHidden(place == nil) end
        if place then
            row.name:SetText(place.name)
            row.name:SetColor(((place.on and place.enabled) and ZO_SELECTED_TEXT or ZO_NORMAL_TEXT):UnpackRGBA())
            row.detail:SetText(placeDetail(kind, place))
            ZO_CheckButton_SetCheckState(row.check, place.on)
            allow(row.up, n == 1 and L.window.first_already or nil)
            allow(row.down, n == #places and L.window.last_already or nil)
        end
    end
    S.bar:SetHidden(not on or most == 0)
    S.bar:SetEnabled(most > 0)
    S.bar:SetMinMax(0, most)
    S.bar:SetValue(S.offset)
    S.bar:SetThumbTextureHeight((rows * SETTINGS_ROW - 2 * ARROW) * rows / math.max(#places, rows))
    drawPrices(on and kind == "prices")
    drawSpeed(on and kind == "speed")
end
W.drawSettings = drawSettings
local function scrollSettings(rows)
    S.offset = S.offset + rows
    drawSettings()
end
local P = { offset = { 0, 0 }, drawnOffset = {}, maxOffset = { 0, 0 }, cells = { {}, {} } }
W.craft = P
function W.priceCell(parent)
    local cell = { gold = WINDOW_MANAGER:CreateControlFromVirtual(name(), parent, "ZO_CurrencyTemplate"),
                   range = label(parent, "ZoFontGameSmall", 0, 0, PRICE, 18, ZO_NORMAL_TEXT) }
    cell.range:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    cell.gold:SetHidden(true)
    cell.range:SetHidden(true)
    return cell
end
function W.placePrice(cell, parent, x, y, width, alone)
    cell.gold:ClearAnchors()
    cell.gold:SetAnchor(TOPRIGHT, parent, TOPLEFT, x + width, y + (alone and (ROW - 24) / 2 or 5))
    cell.gold:SetDimensions(width, 24)
    cell.range:ClearAnchors()
    cell.range:SetAnchor(TOPRIGHT, parent, TOPLEFT, x + width, y + 29)
    cell.range:SetDimensions(width, 18)
end
function W.setPrice(cell, price, times, alone)
    cell.gold:SetHidden(not price)
    cell.range:SetHidden(not price or alone == true)
    if price then
        ZO_CurrencyControl_SetSimpleCurrency(cell.gold, CURT_MONEY, math.floor(price.rec * (times or 1) + 0.5), PRICE_OPTIONS)
        cell.range:SetText(LF.rangeText(price, times))
    end
end
local function craftColumns()
    local left, right = {}, {}
    P.materials = {}
    local ok, why = pcall(function()
        for _, entry in ipairs(LF.craftable(W.need or {})) do
            local need, known, pattern = entry.need, entry.recipe.tickable, entry.recipe.pattern
            local link = (pattern and LF.nonempty(need.link)) or LF.nonempty(entry.recipe.link) or LF.nonempty(need.link)
            local item = { name = need.name, icon = need.icon, link = link, pick = popup(link), quality = qualityOf(need.link),
                           note = LF.craftText(entry, red), need = need, price = need.price, known = known, ticked = known and W.ticked[need.what] == true }
            if pattern then
                item.pattern = { name = LF.clean(ask(GetItemLinkName, pattern.link)), icon = LF.nonempty(ask(GetItemLinkIcon, pattern.link) or ""),
                                 link = pattern.link, pick = popup(pattern.link), quality = qualityOf(pattern.link), price = LF.priceOf(pattern.link) }
            end
            left[#left + 1] = item
        end
        P.materials = LF.crafting(W.need or {}, W.ticked).materials
        for _, m in ipairs(P.materials) do
            local link = LF.nonempty(m.link)
            right[#right + 1] = { name = m.name, icon = m.icon, link = link, pick = popup(link), quality = qualityOf(link), price = m.price,
                                  missing = m.missing, need = m.need, note = LF.materialText(m, red, LF.pricesOn()) }
        end
    end)
    if not ok then W.needsFailed = W.needsFailed or tostring(why) end
    return { left, right }
end
local function craftEnter(k, i, pattern)
    local cell = P.cells[k][i]
    cell.hovered = true
    local entry = cell.entry
    if entry and pattern then entry = entry.pattern end
    cell.over:SetHidden(entry == nil)
    if not entry then return end
    local link = LF.nonempty(entry.link)
    if link then
        InitializeTooltip(ItemTooltip, cell.strip, RIGHT, -15, 0, LEFT)
        ItemTooltip:SetLink(link)
    else
        InitializeTooltip(InformationTooltip, cell.strip, RIGHT, -15, 0, LEFT)
        SetTooltipText(InformationTooltip, entry.name)
        if entry.note then InformationTooltip:AddLine(entry.note, "", ZO_NORMAL_TEXT:UnpackRGBA()) end
    end
end
local function checkEnter(i)
    local entry = P.cells[1][i].entry
    if not entry or entry.known then return end
    local share = LF.patternsShare()
    local why = (share and zo_strformat(L.window.cant_tick_yet, math.floor(share * 100))) or (entry.need.unchecked and L.window.cant_tick_unchecked)
    textTip(P.cells[1][i].check, red(why or L.window.cant_tick))
end
local function craftLeave(k, i)
    local cell = P.cells[k][i]
    cell.hovered = false
    cell.over:SetHidden(true)
    hideTips()
end
local function placeSide()
    local screen = (GuiRoot and GuiRoot:GetWidth()) or 1920
    local tall = W.control:GetHeight() or (LIST_TOP + W.visible * ROW + FOOT)
    local left, right = W.control:GetLeft() or 0, W.control:GetRight() or WIDTH
    local wide = P.sidePriced and SIDE_PRICED or SIDE_W
    P.side:ClearAnchors()
    if right + 4 + wide <= screen then
        P.side:SetAnchor(TOPLEFT, W.control, TOPRIGHT, 4, 0)
    elseif left - 4 - wide >= 0 then
        P.side:SetAnchor(TOPRIGHT, W.control, TOPLEFT, -4, 0)
    else
        P.side:SetAnchor(TOPRIGHT, W.control, TOPRIGHT, 0, LIST_TOP + ROW)
        tall = tall - LIST_TOP - ROW
    end
    P.sideHeight = tall
    P.side:SetDimensions(wide, tall)
end
local function layoutSide(priced)
    if P.sidePriced == priced then return end
    P.sidePriced = priced
    local column, side = COLUMN[2], P.side
    local width = (priced and SIDE_PRICED or SIDE_W) - column.x - BAR - 16
    local top = SIDE_TOP
    local nameX = priced and SIDE_COLS.name[1] or (column.x + column.icon + ICON + ICON_GAP)
    local nameW = priced and SIDE_COLS.name[2] or column.name
    local noteX = priced and SIDE_COLS.have[1] or (nameX + nameW + 8)
    local noteW = priced and SIDE_COLS.have[2] or (column.x + width - 8 - noteX)
    local function at(c, x, y, w, h)
        c:ClearAnchors()
        c:SetAnchor(TOPLEFT, side, TOPLEFT, x, y)
        if w then c:SetDimensions(w, h) end
    end
    for i, cell in ipairs(P.cells[2]) do
        local y = top + (i - 1) * ROW
        at(cell.strip, column.x, y, width, ROW)
        at(cell.over, column.x, y, width, ROW)
        at(cell.icon, column.x + column.icon, y + (ROW - ICON) / 2)
        at(cell.name, nameX, y, nameW, ROW)
        at(cell.note, noteX, y, noteW, ROW)
        cell.note:SetHorizontalAlignment(priced and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT)
        W.placePrice(cell.each, side, SIDE_COLS.each[1], y, SIDE_COLS.each[2])
        W.placePrice(cell.cost, side, SIDE_COLS.cost[1], y, SIDE_COLS.cost[2], true)
    end
    P.sideTop = top
    at(P.bars[2], column.x + width + 4, top + ARROW)
    at(P.empty, column.x, top, width, ROW)
    for _, c in pairs(P.cols) do c:SetHidden(not priced) end
    P.heads[2]:SetDimensions(priced and (SIDE_COLS.have[1] - 4 - 22) or (SIDE_W - 44), 34)
end
local function sideRows()
    local under = P.sidePriced and SIDE_FOOT or 0
    return math.max(1, math.floor(((P.sideHeight or W.control:GetHeight() or (LIST_TOP + W.visible * ROW + FOOT)) - (P.sideTop or SIDE_TOP) - 16 - under) / ROW))
end
local function drawFoot(shown)
    local all = LF.saved.materialsAll == true
    for _, mode in ipairs(P.modes) do
        local pressed = mode.all == all
        mode.control:SetHidden(not (shown and P.sidePriced))
        mode.mark:SetHidden(not (shown and P.sidePriced and pressed))
        mode.control:SetState(pressed and BSTATE_PRESSED or BSTATE_NORMAL, pressed)
    end
    local total = shown and P.sidePriced and LF.materialsTotal(P.materials or {}, all) or nil
    local F = P.foot
    for _, c in pairs(F) do c:SetHidden(total == nil) end
    if not total then return end
    local some = total.priced > 0
    F.gold:SetHidden(not some)
    F.range:SetHidden(not some)
    F.partly:SetHidden(total.priced == total.counted)
    F.words:SetText(all and L.window.cost_all or L.window.cost_missing)
    if some then
        ZO_CurrencyControl_SetSimpleCurrency(F.gold, CURT_MONEY, math.floor(total.rec + 0.5), TOTAL_OPTIONS)
        F.range:SetText(zo_strformat(L.needs.price_range, LF.gold(total.min), LF.gold(total.max)))
    end
    F.partly:SetText(zo_strformat(L.needs.priced, total.priced, total.counted))
end
local function craftItem(cell, entry, priced, i)
    local column = COLUMN[1]
    local pattern = entry and entry.pattern
    local paired = pattern ~= nil
    local y = column.top + (i - 1) * ROW
    local x = column.x + column.icon
    local nameX = x + ICON + 8
    local noteX = nameX + column.name + 8
    local edge = column.x + column.width - 8
    if cell.paired ~= paired then
        cell.paired = paired
        local function at(control, left, top, width, height)
            control:ClearAnchors()
            put(control, W.control, left, top)
            control:SetDimensions(width, height)
        end
        local h = ROW / 2
        at(cell.icon, x + (paired and 8 or 0), y + (paired and 1 or (ROW - ICON) / 2), paired and 24 or ICON, paired and 24 or ICON)
        at(cell.name, nameX, y, column.name, paired and h or ROW)
        if paired then
            at(cell.patternIcon, x + 8, y + h + 1, 24, 24)
            at(cell.patternName, nameX, y + h, column.name, h)
            for j, price in ipairs({cell.price, cell.patternPrice}) do
                local top = y + (j - 1) * h
                at(price.gold, edge - PRICE, top, PRICE, h)
                at(price.range, edge - 2 * PRICE, top, PRICE, h)
            end
        else
            W.placePrice(cell.price, W.control, edge - PRICE, y, PRICE)
        end
    end
    cell.note:SetDimensions(edge - noteX - (priced and (paired and 2 * PRICE or PRICE) + 12 or 0), ROW)
    cell.patternName:SetHidden(not paired)
    cell.patternIcon:SetHidden(not (pattern and pattern.icon))
    if pattern then
        cell.patternName:SetText(pattern.name)
        cell.patternName:SetColor(nameColor(pattern))
        if pattern.icon then cell.patternIcon:SetTexture(pattern.icon) end
    end
    W.setPrice(cell.price, priced and entry and entry.price)
    W.setPrice(cell.patternPrice, priced and pattern and pattern.price)
end
local function drawCraftRows(k, rows, visible)
    local list_, priced = P.columns[k], P.sidePriced
    local offset = math.floor(P.offset[k] + 0.5)
    for i, cell in ipairs(P.cells[k]) do
        local entry = (visible and i <= rows) and list_[offset + i] or nil
        cell.entry = entry
        cell.name:SetHidden(entry == nil)
        cell.note:SetHidden(entry == nil)
        cell.strip:SetHidden(entry == nil)
        cell.over:SetHidden(not (entry and cell.hovered))
        cell.icon:SetHidden(not (entry and entry.icon))
        if entry and entry.icon then cell.icon:SetTexture(entry.icon) end
        cell.name:SetText(entry and entry.name or "")
        cell.name:SetColor(nameColor(entry))
        cell.note:SetText(entry and entry.note or "")
        if k == 1 then
            craftItem(cell, entry, priced, i)
        else
            W.setPrice(cell.each, priced and entry and entry.price)
            local n = entry and LF.toBuy(entry, LF.saved.materialsAll == true) or 0
            W.setPrice(cell.cost, priced and n > 0 and entry.price, n, true)
        end
        if cell.check then
            cell.check:SetHidden(entry == nil)
            if entry then
                ZO_CheckButton_SetCheckState(cell.check, entry.ticked)
                ZO_CheckButton_SetEnableState(cell.check, entry.known)
            end
        end
    end
    P.drawnOffset[k] = offset
    P.bars[k]:SetValue(offset)
end
local function drawCraft()
    local on = W.tab == "needs" and W.list.needs == "crafting" and W.need ~= nil
    local columns = on and craftColumns() or { {}, {} }
    on = on and #columns[1] > 0
    P.columns = columns
    local shown = on and W.sideOpen == true and not W.control:IsHidden()
    local priced = LF.pricesOn()
    layoutSide(priced)
    P.side:SetHidden(not shown)
    if shown then placeSide() end
    drawFoot(shown)
    for k = 1, 2 do
        local rows = k == 1 and (W.visible - 1) or sideRows()
        local list_, most = columns[k], math.max(0, #columns[k] - rows)
        local visible = k == 1 and on or shown
        P.offset[k] = math.max(0, math.min(P.offset[k], most))
        P.maxOffset[k] = visible and most or 0
        local bar = P.bars[k]
        bar:SetDimensions(BAR, rows * ROW - 2 * ARROW)
        bar:SetHidden(not visible or most == 0)
        bar:SetEnabled(most > 0)
        bar:SetMinMax(0, most)
        drawCraftRows(k, rows, visible)
        bar:SetThumbTextureHeight((rows * ROW - 2 * ARROW) * rows / math.max(#list_, rows))
    end
    local known, ticked = 0, 0
    for _, entry in ipairs(columns[1]) do
        if entry.known then known = known + 1 end
        if entry.ticked then ticked = ticked + 1 end
    end
    P.heads[1]:SetText(on and string.format("%s %d", L.window.to_craft, #columns[1]) or "")
    P.heads[2]:SetText(on and string.format("%s %d", L.window.resources, #columns[2]) or "")
    for _, c in ipairs({ P.heads[1], P.tickAll, P.untickAll, P.toggle }) do c:SetHidden(not on) end
    allow(P.tickAll, known == 0 and L.window.cant_tick or nil)
    P.toggle:SetState(W.sideOpen and BSTATE_PRESSED or BSTATE_NORMAL, W.sideOpen == true)
    P.empty:SetText(shown and #columns[2] == 0 and L.window.no_ticked or "")
    P.empty:SetHidden(not (shown and #columns[2] == 0))
end
W.drawCraft = drawCraft
local function flushCraftScroll()
    P.scrollPending = false
    if W.control:IsHidden() or W.tab ~= "needs" or W.list.needs ~= "crafting" then return end
    for k = 1, 2 do
        if P.drawnOffset[k] ~= math.floor(P.offset[k] + 0.5) and P.maxOffset[k] > 0 then
            drawCraftRows(k, k == 1 and W.visible - 1 or sideRows(), true)
        end
    end
end
local function scrollCraftTo(k, offset)
    offset = math.max(0, math.min(offset, P.maxOffset[k]))
    if P.offset[k] == offset then return end
    P.offset[k] = offset
    if not P.scrollPending and P.drawnOffset[k] ~= math.floor(offset + 0.5) then
        P.scrollPending = true
        zo_callLater(flushCraftScroll, 0)
    end
end
function P.scroll(k, rows)
    scrollCraftTo(k, P.offset[k] + rows)
end
local function paint()
    if not W.control or W.control:IsHidden() then return end
    local here = GetCurrentZoneHouseId()
    local layout = chosen()
    if layout ~= W.layout then W.layout, W.job, W.sources = layout, nil, {} end
    if here == 0 and W.list.layouts == "here" then W.list.layouts = "every" end
    if W.tab == "needs" then
        local wanted, entry = previewed()
        local key = entry and keyOf(entry) or nil
        if key ~= W.needsOf then W.needsOf, W.ticked = key, {} end
        local ok, needs = false, nil
        if wanted then ok, needs = pcall(LF.needs, wanted) end
        W.need = ok and needs or nil
        W.needsFailed = (wanted and not ok) and tostring(needs) or nil
        if W.need then needRows("crafting") end
    end
    if not (LF.queue and W.diff and W.diff.layout == layout) then
        local ok, diff = false, nil
        if layout then ok, diff = pcall(LF.diff, layout) end
        W.diff = ok and diff or nil
        if W.diff and W.job then LF.settle(W.job, W.diff) end
    end
    W.made = {}
    if W.ended and not LF.queue and W.diff then
        W.ended = nil
        local left, next_ = workLeft(), "inplace"
        for i = #WORK, 1, -1 do
            if left[WORK[i]] > 0 then next_ = WORK[i] end
        end
        if left[W.list.apply] == nil or left[W.list.apply] == 0 then W.list.apply, W.offset = next_, 0 end
    end
    W.shown = entries(W.tab, W.list[W.tab])
    W.title:SetText(context())
    local _, why = LF.received()
    local broken = why and type(LetsFurnish_Inbox) == "table" and next(LetsFurnish_Inbox) ~= nil
    local slots = W.tab == "apply" and here ~= 0 and slotsText(W.diff and W.diff.slots or LF.slots())
    for _, tab in ipairs(TABS) do
        if tab[1] == W.tab then
            local counted = W.tab == "needs" and LF.sourcesText() or nil
            if W.tab == "needs" and W.needsFailed then counted = red(zo_strformat(L.window.needs_failed, W.needsFailed)) end
            local lead = (W.tab == "layouts" and here == 0) and L.window.layouts_lead_outside or tab[4]
            if W.tab == "settings" then
                lead = (W.list.settings == "put" and L.window.put_lead) or (W.list.settings == "prices" and L.window.prices_lead)
                       or (W.list.settings == "speed" and L.window.speed_lead) or (W.list.settings == "log" and L.window.log_lead) or L.window.take_lead
            end
            W.lead:SetText(slots or counted or (W.tab == "layouts" and broken and red(why)) or lead or "")
            local ran = (W.tab == "apply" or W.tab == "backups") and LF.lastRun or nil
            local recording = W.tab == "apply" and W.layout and W.layout.recorded and L.window.recorded_status
            W.status:SetText(ran and ZO_SUCCEEDED_TEXT:Colorize(ran) or recording or tab[5])
        end
        for _, c in ipairs(W.footers[tab[1]]) do c:SetHidden(tab[1] ~= W.tab) end
    end
    W.lead:SetHidden(W.tab == "share")
    for _, check in ipairs(W.checks) do
        check.control:SetHidden(W.tab ~= "needs")
        ZO_CheckButton_SetCheckState(check.control, LF.sourceOn(check.key))
    end
    for _, entry in ipairs(W.lists) do
        local pressed = entry.tab == W.tab and entry.key == W.list[W.tab]
        entry.control:SetHidden(entry.tab ~= W.tab)
        entry.mark:SetHidden(not pressed)
        local counted = entry.key ~= "prices" and entry.key ~= "speed" and entry.key ~= "log"
        entry.control:SetText(counted and string.format("%s %d", entry.text, entry.tab == W.tab and sized(entries(entry.tab, entry.key)) or 0) or entry.text)
        entry.control:SetState(pressed and BSTATE_PRESSED or BSTATE_NORMAL, pressed)
        allow(entry.control, (entry.key == "here" and here == 0) and L.core.no_house or nil)
    end
    local empty, hint = emptyText()
    W.empty:SetText(empty or "")
    W.hint:SetText(hint or "")
    W.empty:SetHidden(#W.shown > 0 or empty == nil)
    W.hint:SetHidden(#W.shown > 0 or empty == nil)
    W.code.frame:SetHidden(W.tab ~= "share")
    W.code.note:SetHidden(W.tab ~= "share")
    W.code.sync()
    local cantRecord, unchangeable = unrecordable(), LF.unchangeable(W.layout)
    for _, recording in ipairs(W.recording) do allow(recording, cantRecord) end
    if W.tab == "backups" then
        local limit = LF.backupLimit(W.list.backups)
        W.backupLimit:SetText(zo_strformat(L.window.keep_per_house, limit))
        W.fewerBackups:SetEnabled(limit > 1)
        W.moreBackups:SetEnabled(limit < LF.MOST_BACKUPS)
    end
    local left = W.diff and workLeft() or {}
    local none = W.elsewhere and zo_strformat(L.window.wrong_house, LF.houseName(W.elsewhere.house_id)) or L.window.nothing_received
    allow(W.placeAll, unchangeable or (not W.diff and none) or ((left.place or 0) == 0 and L.window.empty_place) or nil)
    allow(W.moveAll, unchangeable or (not W.diff and none) or ((left.move or 0) == 0 and L.window.empty_move) or nil)
    allow(W.removeAll, unchangeable or (not W.diff and none) or ((left.remove or 0) == 0 and L.window.empty_remove) or nil)
    local reasons = {}
    if here == 0 and W.tab ~= "share" and W.tab ~= "needs" then
        reasons[#reasons + 1] = L.core.no_house
    elseif here ~= 0 and unchangeable and not LF.queue and W.tab ~= "share" and W.tab ~= "needs" then
        reasons[#reasons + 1] = unchangeable
    end
    if here ~= 0 and cantRecord and W.tab ~= "needs" then reasons[#reasons + 1] = cantRecord end
    if W.tab == "settings" then reasons = {} end
    W.refusal:SetText(#reasons > 0 and red(table.concat(reasons, " ")) or "")
    W.status:SetHidden(W.tab == "needs" or #reasons > 0)
    show()
    W.made = nil
    drawCraft()
    drawSettings()
    W.progress()
    if LF.queue then W.soon() end
end
W.paint = paint
function W.progress()
    if not W.control then return end
    local p = LF.progress()
    if LF.queue then W.running = true elseif W.running then W.running, W.ended = nil, true end
    local busy = W.busy
    for _, c in ipairs({ busy.words, busy.bar, busy.stop }) do c:SetHidden(p == nil) end
    W.lead:SetHidden(p ~= nil or W.tab == "share")
    W.code.note:SetHidden(p ~= nil or W.tab ~= "share")
    if not p then return end
    busy.words:SetText(p.words)
    if p.total then
        busy.bar:SetMinMax(0, math.max(1, p.total))
        busy.bar:SetValue(p.done)
        busy.label:SetText(zo_strformat(L.window.n_of_m, p.done, p.total))
    else
        local percent = math.floor(math.max(0, math.min(1, p.share or 0)) * 100)
        busy.bar:SetMinMax(0, 100)
        busy.bar:SetValue(percent)
        busy.label:SetText(zo_strformat(L.window.percent, percent))
    end
    busy.stop:SetEnabled(p.stop ~= nil)
end
LF.onProgress = function()
    if W.control and not W.control:IsHidden() then W.progress() end
end
local function soon()
    if W.waiting or not W.control or W.control:IsHidden() then return end
    W.waiting = true
    zo_callLater(function()
        W.waiting = false
        paint()
    end, REFRESH_WAIT)
end
W.soon = soon
local function job()
    if not W.job or not LF.sameHouse(W.job.tally) then W.job = LF.job(W.layout, W.diff and W.diff.found) end
    return W.job
end
function W.act(task, n)
    if W.layout then LF.act(job(), task, n, soon) end
end
local function runAll(which)
    if not (W.diff and W.layout) then return end
    local place, move, switch, paths = 0, 0, 0, 0
    for _, task in ipairs(W.diff.tasks) do
        if LF.inList(task, which) then
            if task.action == "move" then
                move = move + 1
            elseif task.action == "state" then
                switch = switch + 1
            elseif task.action == "path" then
                paths = paths + 1
            elseif task.action ~= "conform" then
                place = place + 1
            end
        end
    end
    local parts = list(LF.some(L.core.to_place, place), LF.some(L.core.to_move, move), LF.some(L.window.to_switch, switch), LF.some(L.core.paths_to_set, paths))
    local name_ = tostring(W.layout.name)
    local title = which == "place" and L.window.place_all or L.window.move_all
    local text
    if W.layout.recorded then
        text = which == "place" and zo_strformat(L.window.place_recorded_ask, name_, parts) or zo_strformat(L.window.move_recorded_ask, name_, parts)
    else
        text = which == "place" and zo_strformat(L.window.place_all_ask, name_, parts) or zo_strformat(L.window.move_all_ask, name_, parts)
    end
    confirm(title, text, title, function()
        if W.diff and W.layout then LF.run(job(), W.diff, which) end
    end)
end
local function removeAll()
    if not (W.diff and W.layout) then return end
    local n = 0
    for _, task in ipairs(W.diff.tasks) do
        if task.action == "remove" then n = n + 1 end
    end
    if n == 0 then return end
    confirm(L.window.remove_all, count(L.window.remove_all_ask, n, tostring(W.layout.name), firstPlace().name), L.window.remove_all, function()
        if W.diff and W.layout then LF.removeAll(W.layout, W.diff) end
    end)
end
function W.select(key)
    if not ZO_MenuBar_SelectDescriptor(W.tabs, key, true) then paint() end
end
local C = { mode = "paste", extents = 0 }
W.code = C
local function note(text) C.note:SetText(text) end
function C.sync()
    if not C.forget then return end
    C.extents = math.max(0, C.edit:GetScrollExtents() or 0)
    C.bar:SetHidden(W.tab ~= "share" or C.extents == 0)
    C.bar:SetEnabled(C.extents > 0)
    C.bar:SetMinMax(0, C.extents)
    C.bar:SetValue((C.edit:GetTopLineIndex() or 1) - 1)
    C.bar:SetThumbTextureHeight(math.max(2 * ARROW, (C.height - 2 * ARROW) / (C.extents + 1)))
    local several = C.mode == "share" and C.parts ~= nil and #C.parts > 1
    for _, c in ipairs({ C.previous, C.next }) do c:SetHidden(W.tab ~= "share" or not several) end
    C.forget:SetHidden(W.tab ~= "share" or C.mode ~= "paste" or not LF.heldParts())
    allow(C.read, C.mode ~= "paste" and L.window.read_own or nil)
    if several then
        C.previous:SetEnabled(C.at > 1)
        C.next:SetEnabled(C.at < #C.parts)
    end
    if W.tab ~= "share" then return end
    local length = #C.edit:GetText()
    if several then
        W.status:SetText(zo_strformat(L.window.part_length, C.at, #C.parts, length, LF.CODE_MOST))
    else
        W.status:SetText(length >= LF.CODE_MOST and red(zo_strformat(L.window.box_full, LF.CODE_MOST)) or zo_strformat(L.window.code_length, length, LF.CODE_MOST))
    end
end
local function scrollBox(lines, top)
    local current = C.edit:GetTopLineIndex() or 1
    C.edit:SetTopLineIndex(math.max(1, math.min(C.extents + 1, top or (current + lines))))
    C.sync()
end
local function showPart(at_)
    C.at, C.code = at_, C.parts[at_]
    C.edit:SetText(C.code)
    C.edit:TakeFocus()
    C.edit:SelectAll()
    if #C.parts > 1 and C.told == nil then C.told = C.note:GetText() end
    if #C.parts > 1 and at_ > 1 then
        local copied = pcall(function() CopyToClipboard(C.code) end)
        local which = at_ < #C.parts and zo_strformat(L.window.part_next, at_, #C.parts, at_ + 1) or zo_strformat(L.window.part_last, at_, #C.parts)
        note(sentences(which, copied and L.house.part_on_clipboard or L.house.part_by_hand))
    elseif #C.parts > 1 then
        note(C.told)
    end
    C.sync()
end
local function showCode(parts)
    C.mode, C.parts, C.told = "share", parts, nil
    showPart(1)
end
local function shareHouse(houseName)
    C.mode, C.code, C.parts, C.house = "share", nil, nil, LF.houseKey()
    C.edit:SetText("")
    LF.share(houseName, note, showCode)
end
local function shareNamed(offered)
    local why = unrecordable()
    if why then
        LF.say(why)
        return LF.alert(why)
    end
    local house = LF.nonempty(offered or "") or LF.houseName(GetCurrentZoneHouseId())
    askName(L.window.share_title, L.window.share_ask, house, L.window.share_button, function(name)
        name = string.match(tostring(name or ""), "^%s*(.-)%s*$")
        if name == "" then return nil, L.core.name_empty end
        local _, characters = string.gsub(name, "[^\128-\191]", "")
        if characters > LF.NAME_MOST then return nil, zo_strformat(L.core.name_long, LF.NAME_MOST) end
        shareHouse(name)
        return true
    end)
end
local function codeOutdated(why)
    if C.mode ~= "share" or not (C.code or LF.coding) then return end
    if LF.coding then LF.stopCode() end
    C.mode, C.code, C.parts, C.house = "paste", nil, nil, nil
    C.edit:SetText("")
    note(why)
    C.sync()
end
W.codeOutdated = codeOutdated
local function pasteHere()
    C.mode, C.code, C.parts = "paste", nil, nil
    C.edit:SetText("")
    C.edit:TakeFocus()
    note(LF.partsText() or L.window.paste_note)
    C.sync()
end
local function readCode()
    if C.mode ~= "paste" then return end
    if not LF.nonempty(C.edit:GetText()) then
        C.edit:TakeFocus()
        return note(L.window.paste_first)
    end
    local reading, took = LF.paste(C.edit:GetText(), note, function(row)
        if LF.view(row).house_id == GetCurrentZoneHouseId() then
            for _, entry in ipairs(LF.listed()) do
                if entry.layout == row then activate(entry) end
            end
            W.select("apply")
        else
            paint()
        end
    end)
    if not reading and took then
        C.edit:SetText("")
        C.edit:TakeFocus()
    end
    C.sync()
end
local function buildCraft(win)
    local side = WINDOW_MANAGER:CreateTopLevelWindow("LetsFurnishMaterials")
    side:SetMouseEnabled(true)
    side:SetHandler("OnMouseWheel", function(_, delta) P.scroll(2, -delta) end)
    side:SetClampedToScreen(true)
    side:SetHidden(true)
    P.side = side
    WINDOW_MANAGER:CreateControlFromVirtual(name(), side, "ZO_DefaultBackdrop")
    local close = WINDOW_MANAGER:CreateControlFromVirtual(name(), side, "ZO_CloseButton")
    close:SetHandler("OnClicked", function()
        W.sideOpen = false
        paint()
    end)
    label(side, "ZoFontWinH2", 16, 8, SIDE_W - 60, 34):SetText(L.window.materials)
    texture(side, 16, 46, SIDE_W - 32, 8):SetTexture(ART .. "Miscellaneous/horizontalDivider.dds")
    P.heads = { label(win, "ZoFontGame", PAD + 6, LIST_TOP, COLUMN[1].width - 3 * TICKS - 18, ROW, ZO_NORMAL_TEXT),
                label(side, "ZoFontGame", 22, 56, SIDE_W - 44, 34, ZO_NORMAL_TEXT) }
    local x = PAD + COLUMN[1].width
    P.tickAll = button(win, L.window.tick_all, x - 3 * TICKS - 8, LIST_TOP + (ROW - 28) / 2, TICKS, tickAll, L.window.tip_tick_all)
    P.untickAll = button(win, L.window.untick_all, x - 2 * TICKS - 4, LIST_TOP + (ROW - 28) / 2, TICKS, function() W.ticked = {} end,
                         L.window.tip_untick_all)
    P.toggle = button(win, L.window.materials, x - TICKS, LIST_TOP + (ROW - 28) / 2, TICKS, function() W.sideOpen = not W.sideOpen end,
                      L.window.tip_materials)
    P.bars = {}
    for k, column in ipairs(COLUMN) do
        local parent = k == 1 and win or side
        local nameX = column.x + column.icon + ICON + (k == 1 and 8 or ICON_GAP)
        local nameWidth = column.name
        for i = 1, k == 1 and (MOST_ROWS - 1) or (MOST_ROWS + 2) do
            local y = column.top + (i - 1) * ROW
            local cell = { strip = texture(parent, column.x, y, column.width, ROW), over = texture(parent, column.x, y, column.width, ROW),
                           icon = texture(parent, column.x + column.icon, y + (ROW - ICON) / 2, ICON, ICON), name = label(parent, "ZoFontGame", nameX, y, nameWidth, ROW),
                           note = label(parent, "ZoFontGameSmall", nameX + nameWidth + 8, y, column.x + column.width - 8 - nameX - nameWidth - 8, ROW, ZO_NORMAL_TEXT) }
            if k == 1 then
                cell.price, cell.patternPrice = W.priceCell(parent), W.priceCell(parent)
                cell.patternIcon = texture(parent, 0, 0, 24, 24)
                cell.patternName = label(parent, "ZoFontGameSmall", 0, 0, nameWidth, ROW / 2)
            else
                cell.each, cell.cost = W.priceCell(parent), W.priceCell(parent)
            end
            cell.strip:SetTexture(ART .. "Miscellaneous/listItem_backdrop.dds")
            cell.strip:SetTextureCoords(0, 1, 0, 0.8125)
            cell.over:SetTexture(ART .. "Miscellaneous/listItem_highlight.dds")
            cell.over:SetTextureCoords(0, 1, 0, 0.625)
            if k == 1 then
                cell.check = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CheckButton")
                cell.check:SetAnchor(TOPLEFT, win, TOPLEFT, column.x + 6, y + (ROW - CHECK) / 2)
                ZO_CheckButton_SetToggleFunction(cell.check, function(_, checked)
                    local entry = cell.entry
                    if entry and entry.known then W.ticked[entry.need.what] = checked or nil end
                    if checked and not W.sideOnce then W.sideOpen, W.sideOnce = true, true end
                    paint()
                end)
                cell.check:SetHandler("OnMouseWheel", function(_, delta) P.scroll(1, -delta) end)
                cell.check:SetHandler("OnMouseEnter", function() checkEnter(i) end)
                cell.check:SetHandler("OnMouseExit", hideTips)
            end
            for _, c in pairs(cell) do
                if c.SetHidden then c:SetHidden(true) end
            end
            for _, part in ipairs({ cell.icon, cell.name, cell.note, cell.patternIcon, cell.patternName }) do
                local pattern = part == cell.patternIcon or part == cell.patternName
                part:SetMouseEnabled(true)
                part:SetHandler("OnMouseWheel", function(_, delta) P.scroll(k, -delta) end)
                part:SetHandler("OnMouseEnter", function() craftEnter(k, i, pattern) end)
                part:SetHandler("OnMouseExit", function() craftLeave(k, i) end)
                part:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
                    local entry = cell.entry
                    if entry and pattern then entry = entry.pattern end
                    if not entry or upInside == false then return end
                    if mouseButton == MOUSE_BUTTON_INDEX_RIGHT then return menu(nil, cell.strip, entry) end
                    if ask(IsShiftKeyDown) and chatLink(entry) then return linkInChat(chatLink(entry)) end
                    if entry.pick then entry.pick() end
                end)
            end
            P.cells[k][i] = cell
        end
        local bar = WINDOW_MANAGER:CreateControlFromVirtual(name(), parent, "ZO_VerticalScrollbarBase")
        bar:SetAnchor(TOPLEFT, parent, TOPLEFT, column.x + column.width + 4, column.top + ARROW)
        bar:SetValueStep(1)
        bar:SetHandler("OnMouseWheel", function(_, delta) P.scroll(k, -delta) end)
        bar:SetHandler("OnValueChanged", function(_, value, reason)
            if reason == EVENT_REASON_HARDWARE then
                scrollCraftTo(k, math.floor(value + 0.5))
            end
        end)
        bar:GetNamedChild("Up"):SetHandler("OnMouseDown", function() P.scroll(k, -1) end)
        bar:GetNamedChild("Down"):SetHandler("OnMouseDown", function() P.scroll(k, 1) end)
        bar:SetHidden(true)
        P.bars[k] = bar
    end
    P.empty = label(side, "ZoFontGameSmall", COLUMN[2].x, SIDE_TOP, COLUMN[2].width, ROW, ZO_NORMAL_TEXT)
    P.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    P.empty:SetHidden(true)
    local function head(text, x, w, align)
        local c = label(side, "ZoFontGame", x, 56, w, 34, ZO_NORMAL_TEXT)
        c:SetText(text)
        c:SetHorizontalAlignment(align)
        c:SetHidden(true)
        return c
    end
    local cols = SIDE_COLS
    P.cols = { head(L.window.head_need_have, cols.have[1] - 8, cols.have[2] + 34, TEXT_ALIGN_CENTER),
               head(L.window.head_each, cols.each[1], cols.each[2], TEXT_ALIGN_RIGHT), head(L.window.head_cost, cols.cost[1], cols.cost[2], TEXT_ALIGN_RIGHT) }
    local F = { line = texture(side, 16, -SIDE_FOOT, SIDE_PRICED - 32, 8),
                words = label(side, "ZoFontGame", 22, 8 - SIDE_FOOT, 200, 28, ZO_NORMAL_TEXT),
                gold = WINDOW_MANAGER:CreateControlFromVirtual(name(), side, "ZO_CurrencyTemplate"),
                partly = label(side, "ZoFontGameSmall", 22, 34 - SIDE_FOOT, 190, 18, ZO_NORMAL_TEXT),
                range = label(side, "ZoFontGameSmall", SIDE_PRICED - 22 - 200, 34 - SIDE_FOOT, 200, 18, ZO_NORMAL_TEXT) }
    F.line:SetTexture(ART .. "Miscellaneous/horizontalDivider.dds")
    F.words:SetText(L.window.cost_missing)
    F.gold:SetAnchor(TOPRIGHT, side, BOTTOMLEFT, SIDE_PRICED - 22, 8 - SIDE_FOOT)
    F.gold:SetDimensions(SIDE_PRICED - 22 - 226, 28)
    F.range:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    for _, c in ipairs({ F.words, F.partly, F.range }) do
        c:SetMouseEnabled(true)
        c:SetHandler("OnMouseEnter", function() textTip(c, L.window.tip_ttc_total, LF.ttcAge()) end)
        c:SetHandler("OnMouseExit", hideTips)
    end
    for _, c in pairs(F) do c:SetHidden(true) end
    P.foot = F
    P.modes = {}
    for i, mode in ipairs({ { all = false, text = L.window.mat_missing, tip = L.window.tip_mat_missing },
                            { all = true, text = L.window.mat_all, tip = L.window.tip_mat_all } }) do
        local x = -40 - (2 - i) * (MODE + 4) - MODE
        mode.mark = texture(side, 0, 0, MODE, 28)
        mode.mark:SetTexture(ART .. "Contacts/social_list_bgStrip_highlight.dds")
        mode.mark:SetTextureCoords(0, 0.7607, 0, 1)
        mode.control = button(side, mode.text, 0, 0, MODE, function() LF.saved.materialsAll = mode.all end, mode.tip)
        for _, c in ipairs({ mode.mark, mode.control }) do
            c:ClearAnchors()
            c:SetAnchor(TOPLEFT, side, TOPRIGHT, x, 12)
            c:SetHidden(true)
        end
        P.modes[i] = mode
    end
end
local function buildPrices(win)
    local y, x = LIST_TOP + 4, PAD + 214
    local half = (LIST_RIGHT - x - 4) / 2
    S.ttc = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CheckButton")
    S.ttc:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + 6, y + 8)
    ZO_CheckButton_SetLabelText(S.ttc, L.window.ttc_check)
    ZO_CheckButton_SetTooltipText(S.ttc, L.window.tip_ttc)
    ZO_CheckButton_SetToggleFunction(S.ttc, function(_, checked)
        LF.saved.ttc = checked
        paint()
    end)
    S.ttc:SetHidden(true)
    S.prices, S.ranges = { label(win, "ZoFontGame", PAD + 6, y + 40, 200, 28, ZO_NORMAL_TEXT), label(win, "ZoFontGame", PAD + 6, y + 76, 200, 28, ZO_NORMAL_TEXT) }, {}
    S.prices[1]:SetText(L.window.range_shown)
    S.prices[2]:SetText(L.window.price_used)
    for i, choice in ipairs({ { range = "listing", text = L.window.range_listing, tip = L.window.tip_range_listing },
                              { range = "band", text = L.window.range_band, tip = L.window.tip_range_band } }) do
        local at = x + (i - 1) * (half + 4)
        choice.mark = texture(win, at, y + 40, half, 28)
        choice.mark:SetTexture(ART .. "Contacts/social_list_bgStrip_highlight.dds")
        choice.mark:SetTextureCoords(0, 0.7607, 0, 1)
        choice.control = button(win, choice.text, at, y + 40, half, function() LF.setPriceRange(choice.range) end, choice.tip)
        S.prices[#S.prices + 1] = choice.control
        S.ranges[i] = choice
    end
    S.slider = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_Slider")
    S.slider:SetAnchor(TOPLEFT, win, TOPLEFT, x, y + 82)
    S.slider:SetDimensions(half, 16)
    S.slider:SetMinMax(0, 1)
    S.slider:SetValueStep(LF.PRICE_STEP)
    S.slider:SetHandler("OnValueChanged", function(_, value, reason)
        if reason == EVENT_REASON_HARDWARE then
            LF.setPriceAt(value)
            paint()
        end
    end)
    S.slider:SetHandler("OnMouseEnter", function() textTip(S.slider, L.window.tip_price_at) end)
    S.slider:SetHandler("OnMouseExit", hideTips)
    S.at = label(win, "ZoFontGame", x + half + 16, y + 76, half - 12, 28, ZO_SELECTED_TEXT)
    local explain = label(win, "ZoFontGameSmall", PAD + 6, y + 110, LIST_RIGHT - PAD - 12, 38, ZO_NORMAL_TEXT)
    explain:SetText(L.window.prices_explain)
    S.example = label(win, "ZoFontGame", PAD + 6, y + 150, LIST_RIGHT - PAD - 12 - PRICE - 20, ROW)
    S.examplePrice = W.priceCell(win)
    W.placePrice(S.examplePrice, win, LIST_RIGHT - 8 - PRICE, y + 150, PRICE)
    for _, c in ipairs({ S.slider, S.at, explain }) do S.prices[#S.prices + 1] = c end
    for _, c in ipairs(S.prices) do c:SetHidden(true) end
    for _, choice in ipairs(S.ranges) do choice.mark:SetHidden(true) end
    S.example:SetHidden(true)
end
local SPEED_WORDS = { L.window.speed_fast, L.window.speed_normal, L.window.speed_careful, L.window.speed_slow }
local function buildSpeed(win)
    local y = LIST_TOP + 12
    local wide = (LIST_RIGHT - PAD - 12 - 3 * 4) / 4
    S.speeds = {}
    for i, ms in ipairs(LF.SPEEDS) do
        local at = PAD + 6 + (i - 1) * (wide + 4)
        local choice = { ms = ms, mark = texture(win, at, y, wide, 28) }
        choice.mark:SetTexture(ART .. "Contacts/social_list_bgStrip_highlight.dds")
        choice.mark:SetTextureCoords(0, 0.7607, 0, 1)
        local seconds = string.format(ms % 1000 == 0 and "%d" or "%.2g", ms / 1000):gsub("%.", L.window.decimal_point)
        choice.control = button(win, SPEED_WORDS[i] or tostring(ms), at, y, wide, function()
            LF.setSpeed(ms)
            paint()
        end, zo_strformat(L.window.tip_speed, seconds))
        choice.control:SetHidden(true)
        choice.mark:SetHidden(true)
        S.speeds[i] = choice
    end
    S.speedNote = label(win, "ZoFontGameSmall", PAD + 6, y + 40, LIST_RIGHT - PAD - 12, 60, ZO_NORMAL_TEXT)
    S.speedNote:SetText(L.window.speed_explain)
    S.speedNote:SetHidden(true)
end
local function buildSettings(win)
    for i = 1, math.floor(MOST_ROWS * ROW / SETTINGS_ROW) do
        local y = LIST_TOP + (i - 1) * SETTINGS_ROW
        local row = { strip = texture(win, PAD, y, LIST_RIGHT - PAD, SETTINGS_ROW - 2),
                      name = label(win, "ZoFontGame", PAD + 36, y, 290, SETTINGS_ROW),
                      detail = label(win, "ZoFontGameSmall", PAD + 336, y, LIST_RIGHT - 2 * MOVE - 16 - (PAD + 336), SETTINGS_ROW, ZO_NORMAL_TEXT) }
        row.strip:SetTexture(ART .. "Miscellaneous/listItem_backdrop.dds")
        row.strip:SetTextureCoords(0, 1, 0, 0.8125)
        row.check = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CheckButton")
        row.check:SetAnchor(TOPLEFT, win, TOPLEFT, PAD + 10, y + (SETTINGS_ROW - 16) / 2)
        ZO_CheckButton_SetToggleFunction(row.check, function(_, checked)
            if row.place then LF.togglePlace(S.kind, row.place.bag, checked) end
            paint()
        end)
        row.up = arrow(button(win, L.window.move_up, LIST_RIGHT - 2 * MOVE - 4, y + (SETTINGS_ROW - MOVE) / 2, MOVE, function()
            if row.place then LF.movePlace(S.kind, row.place.bag, -1) end
        end, L.window.tip_up, "ZO_ScrollUpButton"), "up")
        row.down = arrow(button(win, L.window.move_down, LIST_RIGHT - MOVE, y + (SETTINGS_ROW - MOVE) / 2, MOVE, function()
            if row.place then LF.movePlace(S.kind, row.place.bag, 1) end
        end, L.window.tip_down, "ZO_ScrollDownButton"), "down")
        for _, c in pairs(row) do c:SetHidden(true) end
        S.rows[i] = row
    end
    S.bar = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_VerticalScrollbarBase")
    S.bar:SetAnchor(TOPLEFT, win, TOPLEFT, WIDTH - PAD - BAR, LIST_TOP + ARROW)
    S.bar:SetValueStep(1)
    S.bar:SetHandler("OnMouseWheel", function(_, delta) scrollSettings(-delta) end)
    S.bar:SetHandler("OnValueChanged", function(_, value, reason)
        if reason == EVENT_REASON_HARDWARE then
            S.offset = math.floor(value + 0.5)
            drawSettings()
        end
    end)
    S.bar:GetNamedChild("Up"):SetHandler("OnMouseDown", function() scrollSettings(-1) end)
    S.bar:GetNamedChild("Down"):SetHandler("OnMouseDown", function() scrollSettings(1) end)
    S.bar:SetHidden(true)
    buildPrices(win)
    buildSpeed(win)
end
local function fit()
    local tall = (GuiRoot and GuiRoot:GetHeight()) or 1080
    W.visible = math.max(LEAST_ROWS, math.min(MOST_ROWS, math.floor((tall - 2 * MARGIN - LIST_TOP - FOOT) / ROW)))
    W.control:SetDimensions(WIDTH, LIST_TOP + W.visible * ROW + FOOT)
    W.bar:SetDimensions(BAR, W.visible * ROW - 2 * ARROW)
    P.bars[1]:SetDimensions(BAR, (W.visible - 1) * ROW - 2 * ARROW)
    S.bar:SetDimensions(BAR, math.floor(W.visible * ROW / SETTINGS_ROW) * SETTINGS_ROW - 2 * ARROW)
    C.height = LIST_TOP + W.visible * ROW - 160
    C.frame:SetDimensions(WIDTH - 2 * PAD - BAR - 6, C.height)
    C.bar:SetDimensions(BAR, C.height - 2 * ARROW)
end
W.fit = fit
function LF.confirmManualBackup(n, oldest, go)
    confirm(L.window.back_up_now, count(L.window.replace_backups_ask, n, oldest), L.window.back_up_now, go)
end
function W.buildBackupFooter(win, y)
    W.recording[2] = button(win, L.window.back_up_now, PAD, y, 150, function()
        LF.requestManualBackup(function() W.list.backups, W.offset = "hand", 0 end)
    end, L.window.tip_back_up)
    local right = WIDTH - PAD
    W.backupLimit = label(win, "ZoFontGame", right - 370, y, 280, 28, ZO_NORMAL_TEXT)
    W.backupLimit:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    local function adjust(delta)
        local kind = W.list.backups
        LF.setBackupLimit(kind, LF.backupLimit(kind) + delta)
    end
    W.fewerBackups = button(win, "−", right - 76, y, 36, function() adjust(-1) end, L.window.tip_backup_limit)
    W.moreBackups = button(win, "+", right - 36, y, 36, function() adjust(1) end, L.window.tip_backup_limit)
    W.footers.backups = { W.recording[2], W.backupLimit, W.fewerBackups, W.moreBackups }
end
local function build()
    local win = WINDOW_MANAGER:CreateTopLevelWindow("LetsFurnishWindow")
    local place = type(LF.saved.place) == "table" and LF.saved.place or nil
    if place and tonumber(place.x) and tonumber(place.y) then
        win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, tonumber(place.x), tonumber(place.y))
    else
        win:SetAnchor(RIGHT, GuiRoot, RIGHT, -40, 0)
    end
    win:SetMovable(true)
    win:SetMouseEnabled(true)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetHandler("OnMoveStop", function()
        LF.saved.place = { x = win:GetLeft(), y = win:GetTop() }
    end)
    win:SetHandler("OnShow", function()
        EVENT_MANAGER:RegisterForUpdate(WHERE_UPDATE, WHERE_MS, whereNow)
    end)
    win:SetHandler("OnHide", function()
        EVENT_MANAGER:UnregisterForUpdate(WHERE_UPDATE)
        if P.side then P.side:SetHidden(true) end
        if C.edit then C.edit:LoseFocus() end
        hideTips()
    end)
    SCENE_MANAGER:RegisterTopLevel(win, false)
    WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_DefaultBackdrop")
    local close = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CloseButton")
    close:SetHandler("OnClicked", function() W.hide() end)
    local function wheel(_, delta)
        if W.tab == "needs" and W.list.needs == "crafting" then
            P.scroll(1, -delta)
        else
            scroll(-delta)
        end
    end
    win:SetHandler("OnMouseWheel", wheel)
    label(win, "ZoFontWinH2", PAD, 8, 300, 34):SetText("LetsFurnish!")
    W.tabs = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_LabelButtonBar")
    W.tabs:SetAnchor(TOPRIGHT, win, TOPRIGHT, -PAD - 24, 22)
    W.title = label(win, "ZoFontGame", PAD, 72, WIDTH - 2 * PAD, 24, ZO_NORMAL_TEXT)
    W.title:SetMouseEnabled(true)
    W.title:SetHandler("OnMouseEnter", function() textTip(W.title, W.title:GetText()) end)
    W.title:SetHandler("OnMouseExit", hideTips)
    for _, tab in ipairs(TABS) do
        local icon = ART .. tab[3]
        ZO_MenuBar_AddButton(W.tabs, { descriptor = tab[1], categoryName = tab[2], normal = icon .. "_up.dds", pressed = icon .. "_down.dds",
                                       highlight = icon .. "_over.dds", callback = function()
                                           if W.tab ~= tab[1] then LF.lastRun = nil end
                                           W.tab, W.offset = tab[1], 0
                                           W.tabs:GetNamedChild("Label"):SetText(tab[2])
                                           paint()
                                       end })
    end
    local divider = texture(win, PAD, 98, WIDTH - 2 * PAD, 8)
    divider:SetTexture(ART .. "Miscellaneous/horizontalDivider.dds")
    W.lead = label(win, "ZoFontGameSmall", PAD, 105, WIDTH - 2 * PAD, 34, ZO_NORMAL_TEXT)
    local barX = WIDTH - PAD - STOP - 12 - PROGRESS_WIDTH
    W.busy = { words = label(win, "ZoFontGameSmall", PAD, 105, barX - 12 - PAD, 34, ZO_NORMAL_TEXT),
               bar = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_ArrowProgressBarWithBG") }
    W.busy.bar:SetAnchor(TOPLEFT, win, TOPLEFT, barX, 105 + (34 - PROGRESS_HEIGHT) / 2)
    W.busy.bar:SetDimensions(PROGRESS_WIDTH, PROGRESS_HEIGHT)
    ZO_StatusBar_SetGradientColor(W.busy.bar, ZO_XP_BAR_GRADIENT_COLORS)
    W.busy.label = W.busy.bar:GetNamedChild("Progress")
    W.busy.stop = button(win, L.window.stop, WIDTH - PAD - STOP, 105 + (34 - 28) / 2, STOP, function()
        local p = LF.progress()
        if p and p.stop then p.stop() end
    end, L.window.tip_stop)
    for _, c in ipairs({ W.busy.words, W.busy.bar, W.busy.stop }) do c:SetHidden(true) end
    local groups = {}
    for _, entry in ipairs(LISTS) do groups[entry[1]] = (groups[entry[1]] or 0) + 1 end
    local n = {}
    for _, entry in ipairs(LISTS) do
        local width = (WIDTH - 2 * PAD) / groups[entry[1]]
        n[entry[1]] = (n[entry[1]] or 0) + 1
        local x = PAD + (n[entry[1]] - 1) * width
        local shown = { tab = entry[1], key = entry[2], text = entry[3], mark = texture(win, x, 140, width - 4, 28) }
        shown.mark:SetTexture(ART .. "Contacts/social_list_bgStrip_highlight.dds")
        shown.mark:SetTextureCoords(0, 0.7607, 0, 1)
        shown.control = button(win, entry[3], x, 140, width - 4, function()
            W.list[shown.tab], W.offset = shown.key, 0
        end)
        W.lists[#W.lists + 1] = shown
    end
    for i = 1, MOST_ROWS do
        local y = LIST_TOP + (i - 1) * ROW
        local row = { strip = texture(win, PAD, y, LIST_RIGHT - PAD, ROW), highlight = texture(win, PAD, y, LIST_RIGHT - PAD, ROW),
                      over = texture(win, PAD, y, LIST_RIGHT - PAD, ROW), icon = texture(win, PAD + 6, y + (ROW - ICON) / 2, ICON, ICON),
                      name = label(win, "ZoFontGame", NAME_X, y, NAMES.apply, ROW),
                      note = label(win, "ZoFontGameSmall", 0, 0, 0, ROW, ZO_NORMAL_TEXT),
                      where = label(win, "ZoFontGameSmall", BUTTON_X - 12 - POINTER - 6 - WHERE, y, WHERE, ROW, ZO_NORMAL_TEXT),
                      pointer = texture(win, BUTTON_X - 12 - POINTER, y + (ROW - POINTER) / 2, POINTER, POINTER) }
        row.stack = label(row.icon, "ZoFontGameOutline", 1, 1, ICON - 5, ICON - 2)
        row.stack:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.stack:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        row.where:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.pointer:SetTexture(POINTER_ART)
        row.note:ClearAnchors()
        row.note:SetAnchor(TOPLEFT, row.name, TOPRIGHT, 8, 0)
        row.strip:SetTexture(ART .. "Miscellaneous/listItem_backdrop.dds")
        row.strip:SetTextureCoords(0, 1, 0, 0.8125)
        row.highlight:SetTexture(ART .. "Contacts/social_list_bgStrip_highlight.dds")
        row.highlight:SetTextureCoords(0, 0.7607, 0, 1)
        row.over:SetTexture(ART .. "Miscellaneous/listItem_highlight.dds")
        row.over:SetTextureCoords(0, 1, 0, 0.625)
        row.over:SetHidden(true)
        for _, part in ipairs({ row.icon, row.name, row.note }) do
            part:SetMouseEnabled(true)
            part:SetHandler("OnMouseWheel", wheel)
            part:SetHandler("OnMouseEnter", function() enter(row) end)
            part:SetHandler("OnMouseExit", function() leave(row) end)
            part:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
                local entry = row.entry
                if not entry or upInside == false then return end
                if mouseButton == MOUSE_BUTTON_INDEX_RIGHT then return menu(row) end
                if ask(IsShiftKeyDown) and chatLink(entry) then return linkInChat(chatLink(entry)) end
                local click = (part == row.note and entry.turn) or entry.pick
                if click then
                    click()
                    paint()
                end
            end)
            part:SetHandler("OnMouseDoubleClick", function(_, mouseButton)
                local entry = row.entry
                if entry and entry.double and mouseButton ~= MOUSE_BUTTON_INDEX_RIGHT then
                    entry.double()
                    paint()
                end
            end)
        end
        row.button = button(win, "", BUTTON_X, y + (ROW - 28) / 2, BUTTON, function()
            if row.entry and row.entry.button then row.entry.button[2]() end
        end)
        row.second = button(win, "", BUTTON_X - BUTTON - 4, y + (ROW - 28) / 2, BUTTON, function()
            if row.entry and row.entry.second then row.entry.second[2]() end
        end)
        row.price = W.priceCell(win)
        W.placePrice(row.price, win, LIST_RIGHT - 8 - PRICE, y, PRICE)
        W.rows[i] = row
    end
    buildCraft(win)
    buildSettings(win)
    W.empty = label(win, "ZoFontWinH4", PAD, LIST_TOP + 20, LIST_RIGHT - PAD, 30, ZO_SELECTED_TEXT)
    W.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    W.hint = label(win, "ZoFontGameSmall", PAD, LIST_TOP + 54, LIST_RIGHT - PAD, 20, ZO_NORMAL_TEXT)
    W.hint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    W.bar = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_VerticalScrollbarBase")
    W.bar:SetAnchor(TOPLEFT, win, TOPLEFT, WIDTH - PAD - BAR, LIST_TOP + ARROW)
    W.bar:SetValueStep(1)
    W.bar:SetHandler("OnMouseWheel", wheel)
    W.bar:SetHandler("OnValueChanged", function(_, value, reason)
        if reason == EVENT_REASON_HARDWARE then
            W.offset = math.floor(value + 0.5)
            show()
        end
    end)
    W.bar:GetNamedChild("Up"):SetHandler("OnMouseDown", function() scroll(-1) end)
    W.bar:GetNamedChild("Down"):SetHandler("OnMouseDown", function() scroll(1) end)
    C.note = label(win, "ZoFontGameSmall", PAD, 108, WIDTH - 2 * PAD, 44, ZO_NORMAL_TEXT)
    C.frame = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_MultiLineEditBackdrop_Keyboard")
    C.frame:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, 160)
    C.edit = WINDOW_MANAGER:CreateControlFromVirtual(name(), C.frame, "ZO_DefaultEditMultiLineForBackdrop")
    C.edit:SetMaxInputChars(LF.CODE_MOST)
    C.edit:SetHandler("OnTextChanged", function()
        if C.mode == "share" and C.code and C.edit:GetText() ~= C.code then C.edit:SetText(C.code) end
        C.sync()
    end)
    C.edit:SetHandler("OnMouseWheel", function(_, delta, _, _, shift)
        scrollBox(-(shift and delta * 10 or delta))
    end)
    C.bar = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_VerticalScrollbarBase")
    C.bar:SetAnchor(TOPLEFT, win, TOPLEFT, WIDTH - PAD - BAR, 160 + ARROW)
    C.bar:SetValueStep(1)
    C.bar:SetHandler("OnMouseWheel", function(_, delta) scrollBox(-delta) end)
    C.bar:SetHandler("OnValueChanged", function(_, value, reason)
        if reason == EVENT_REASON_HARDWARE then scrollBox(0, math.floor(value + 0.5) + 1) end
    end)
    C.bar:GetNamedChild("Up"):SetHandler("OnMouseDown", function() scrollBox(-1) end)
    C.bar:GetNamedChild("Down"):SetHandler("OnMouseDown", function() scrollBox(1) end)
    local line, buttons = 8 - FOOT, -16 - 28
    W.status = label(win, "ZoFontGameSmall", PAD, line, WIDTH - 2 * PAD - 170, 20, ZO_NORMAL_TEXT)
    W.refusal = label(win, "ZoFontGameSmall", PAD, line, WIDTH - 2 * PAD - 170, 20)
    W.range = label(win, "ZoFontGameSmall", WIDTH - PAD - 160, line, 160, 20, ZO_NORMAL_TEXT)
    W.range:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    W.recording[1] = button(win, L.window.record_house, PAD, buttons, 170, recordNamed, L.window.tip_record)
    W.footers.layouts = { W.recording[1], button(win, L.window.paste_code, PAD + 174, buttons, 150, function() LF.showPaste() end, L.window.tip_paste),
                          button(win, L.window.get_app, WIDTH - PAD - 240, buttons, 240, LF.openSite, L.window.tip_get_app) }
    W.footers.needs = {}
    local column = (WIDTH - 2 * PAD - 170) / 4
    local grid = { backpack = { 0, 0 }, bank = { 1, 0 }, vault = { 2, 0 }, storage = { 3, 0 }, placed_here = { 0, 1 }, placed_elsewhere = { 2, 1 } }
    for i, key in ipairs(LF.SOURCES) do
        local check = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CheckButton")
        local at = grid[key] or { i - 1, 0 }
        check:SetAnchor(TOPLEFT, win, BOTTOMLEFT, PAD + 4 + at[1] * column, (at[2] == 0 and line or buttons) + 6)
        if key == "placed_here" or key == "placed_elsewhere" then
            ZO_CheckButton_SetTooltipText(check, key == "placed_here" and L.stock.placed_here_tip or L.stock.placed_elsewhere_tip)
        end
        ZO_CheckButton_SetLabelText(check, LF.sourceLabels[key])
        ZO_CheckButton_SetToggleFunction(check, function(_, checked)
            LF.setSource(key, checked)
            paint()
        end)
        W.checks[i] = { key = key, control = check }
    end
    W.placeAll = button(win, L.window.place_all, PAD, buttons, 150, function() runAll("place") end, L.window.tip_place_all)
    W.moveAll = button(win, L.window.move_all, PAD + 154, buttons, 150, function() runAll("move") end, L.window.tip_move_all)
    W.removeAll = button(win, L.window.remove_all, PAD + 308, buttons, 150, removeAll, L.window.tip_remove_all)
    W.into = button(win, L.window.open_settings, WIDTH - PAD - 180, buttons, 180, function() openSettings("put") end, L.window.tip_removed_to)
    W.footers.apply = { W.placeAll, W.moveAll, W.removeAll, W.into }
    W.buildBackupFooter(win, buttons)
    W.recording[3] = button(win, L.window.house_code, PAD, buttons, 200, function() shareNamed("") end, L.window.tip_house_code)
    C.read = button(win, L.window.read_code, PAD + 204, buttons, 200, readCode, L.window.tip_read_code)
    W.footers.share = { W.recording[3], C.read, button(win, L.window.clear, PAD + 408, buttons, 120, pasteHere, L.window.tip_clear) }
    local debugCheck = WINDOW_MANAGER:CreateControlFromVirtual(name(), win, "ZO_CheckButton")
    W.settings.debug = debugCheck
    debugCheck:SetAnchor(TOPLEFT, win, BOTTOMLEFT, PAD + 236, buttons + 6)
    ZO_CheckButton_SetLabelText(debugCheck, L.window.debug_mode)
    ZO_CheckButton_SetTooltipText(debugCheck, L.window.tip_debug_mode)
    ZO_CheckButton_SetToggleFunction(debugCheck, function(_, checked) LF.setDebug(checked) end)
    W.footers.settings = { button(win, L.window.reset, PAD, buttons, 220, function()
        LF.setDebug(false)
        LF.resetPlaces()
        LF.resetPrices()
    end, L.window.tip_reset),
                           button(win, L.window.read_patterns, WIDTH - PAD - 260, buttons, 260, function() LF.readPatterns(true) end, L.window.tip_read_patterns) }
    C.previous = button(win, L.window.previous_part, PAD + 532, buttons, 110, function() showPart(math.max(1, C.at - 1)) end, L.window.tip_previous)
    C.next = button(win, L.window.next_part, PAD + 646, buttons, 110, function() showPart(math.min(#C.parts, C.at + 1)) end, L.window.tip_next)
    C.forget = button(win, L.window.forget_parts, PAD + 532, buttons, 224, function()
        LF.forgetParts()
        if C.mode == "paste" then note(L.window.paste_note) end
    end, L.window.tip_forget)
    for _, c in ipairs({ C.previous, C.next, C.forget }) do c:SetHidden(true) end
    W.control = win
    fit()
    note(L.window.share_note)
end
function W.hide()
    if W.control and not W.control:IsHidden() then SCENE_MANAGER:HideTopLevel(W.control) end
end
local function open(tab)
    if not W.control then build() end
    if W.control:IsHidden() then
        fit()
        SCENE_MANAGER:ShowTopLevel(W.control)
        ZO_VerticalScrollbarBase_OnScrollAreaEnter(W.bar)
    end
    local layout = not tab and chosen()
    local done = layout and applied(layout)
    W.select(tab or ((layout and not (done and done.finished)) and "apply" or "layouts"))
end
function LF.showProblem(kind, title, text)
    ZO_Dialogs_ShowDialog(PROBLEM_DIALOG, { kind = kind, title = title, text = text })
end
function LF.toggleWindow()
    if W.control and not W.control:IsHidden() then W.hide() else open() end
end
function LF.showShare(houseName)
    open("share")
    shareHouse(houseName)
end
function LF.showPaste()
    open("share")
    pasteHere()
end
local HOUSE_CHANGES = { "EVENT_HOUSING_FURNITURE_PLACED", "EVENT_HOUSING_FURNITURE_REMOVED", "EVENT_HOUSING_FURNITURE_MOVED",
                        "EVENT_HOUSING_FURNITURE_STATE_CHANGED", "EVENT_HOUSING_FURNITURE_PATH_DATA_CHANGED",
                        "EVENT_HOUSING_FURNITURE_PATH_NODE_ADDED", "EVENT_HOUSING_FURNITURE_PATH_NODE_REMOVED", "EVENT_HOUSING_FURNITURE_PATH_NODE_MOVED",
                        "EVENT_HOUSING_FURNITURE_PATH_STARTING_NODE_INDEX_CHANGED", "EVENT_HOUSING_FURNITURE_PATH_NODES_RESTORED" }
local HELD_CHANGES = { "EVENT_INVENTORY_SINGLE_SLOT_UPDATE", "EVENT_INVENTORY_FULL_UPDATE", "EVENT_COLLECTIBLE_UPDATED", "EVENT_PLAYER_ACTIVATED" }
function LF.onLoadedWindow()
    for _, names in ipairs({ HOUSE_CHANGES, HELD_CHANGES }) do
        for _, name in ipairs(names) do
            if _G[name] then EVENT_MANAGER:RegisterForEvent(LF.name .. "Window", _G[name], soon) end
        end
    end
    for _, name in ipairs(HOUSE_CHANGES) do
        if _G[name] then
            EVENT_MANAGER:RegisterForEvent(LF.name .. "Code", _G[name], function()
                if not LF.selecting then codeOutdated(L.window.code_outdated_changed) end
            end)
        end
    end
    EVENT_MANAGER:RegisterForEvent(LF.name .. "Code", EVENT_PLAYER_ACTIVATED, function()
        if C.house ~= LF.houseKey() then codeOutdated(L.window.code_outdated_left) end
    end)
    if EVENT_ALL_GUI_SCREENS_RESIZED then
        EVENT_MANAGER:RegisterForEvent(LF.name .. "Window", EVENT_ALL_GUI_SCREENS_RESIZED, function()
            if W.control then
                fit()
                paint()
            end
        end)
    end
    ZO_Dialogs_RegisterCustomDialog(DIALOG, {
        title = { text = function(dialog) return dialog.data.title end },
        mainText = { text = function(dialog) return dialog.data.text end },
        buttons = { { keybind = "DIALOG_PRIMARY", text = function(dialog) return dialog.data.yes end, callback = function(dialog) dialog.data.go() end },
                    { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL } },
    })
    ZO_Dialogs_RegisterCustomDialog(PROBLEM_DIALOG, {
        title = { text = function(dialog) return dialog.data.title end },
        mainText = { text = function(dialog) return dialog.data.text end },
        buttons = { { keybind = "DIALOG_PRIMARY", text = function() return L.window.open_settings end,
                      callback = function(dialog) openSettings(dialog.data.kind) end },
                    { keybind = "DIALOG_NEGATIVE", text = function() return game(SI_OK, L.window.ok) end } },
    })
    ZO_Dialogs_RegisterCustomDialog(NAME_DIALOG, {
        title = { text = function(dialog) return dialog.data.title end },
        mainText = { text = function(dialog) return dialog.data.why and (dialog.data.text .. "\n" .. red(dialog.data.why)) or dialog.data.text end },
        editBox = { maxInputCharacters = LF.NAME_MOST, selectAll = true },
        buttons = { { keybind = "DIALOG_PRIMARY", requiresTextInput = true, noReleaseOnClick = true, text = function(dialog) return dialog.data.yes end,
                      callback = function(dialog) W.named(dialog) end },
                    { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL } },
    })
end
