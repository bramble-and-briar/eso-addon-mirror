-- shared
-- What the character is wearing, read from the game. One text per filled slot:
--   c.gear = { "slot|item name|quality|trait|set name|pieces of that set worn", ... }
-- slot = a number from the SLOTS list below; quality = the game's quality number (1 white ... 5 gold, 6 mythic).
local CT = FurysCharacterTracker
local U = CT.Util

-- Slot names in board order (the reader below lists the game's slots in the same order).
local SLOTS = { "Head", "Shoulders", "Chest", "Hands", "Waist", "Legs", "Feet", "Necklace", "Ring", "Ring",
                "Main hand", "Off hand", "Back bar", "Back bar off hand" }
-- The game's item quality colors.
local QUALITY_COLOR = { [0] = "8A86B0", [1] = "ECEAF8", [2] = "2DC50E", [3] = "3A92FF", [4] = "A02EF7", [5] = "EECA2A", [6] = "FF8200" }

-- The saved gear of a character as a list of { slot =, name =, quality =, trait =, set =, pieces = }.
local function Items(c)
    local list = {}
    for _, text in ipairs(c.gear or {}) do
        local p = U.Split(text, "|")
        list[#list + 1] = { slot = SLOTS[tonumber(p[1]) or 0] or "?", name = p[2] or "", quality = tonumber(p[3]) or 1, trait = p[4] or "",
                            set = p[5] or "", pieces = tonumber(p[6]) or 0 }
    end
    return list
end

-- The sets being worn, most pieces first: { { name =, pieces = }, ... }.
local function Sets(c)
    local bySet, list = {}, {}
    for _, item in ipairs(Items(c)) do
        if item.set ~= "" then
            if not bySet[item.set] then
                bySet[item.set] = { name = item.set, pieces = 0 }
                list[#list + 1] = bySet[item.set]
            end
            bySet[item.set].pieces = math.max(bySet[item.set].pieces, item.pieces)
        end
    end
    table.sort(list, function(a, b)
        if a.pieces ~= b.pieces then return a.pieces > b.pieces end
        return a.name < b.name
    end)
    return list
end

local function SetsText(c, separator)
    local parts = {}
    for i, set in ipairs(Sets(c)) do parts[i] = U.Whole(set.pieces) .. " " .. set.name end
    return table.concat(parts, separator)
end
CT.GearSets = SetsText

local function ItemLine(item, colored)
    local name = colored and string.format("|c%s%s|r", QUALITY_COLOR[item.quality] or QUALITY_COLOR[1], item.name) or item.name
    local text = string.format("%s: %s", item.slot, name)
    if item.trait ~= "" then text = text .. "  ·  " .. item.trait end
    return text
end

CT.Track({
    id = "gear",
    read = function(c)
        local slots = { EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS,
                        EQUIP_SLOT_FEET, EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2, EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND,
                        EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }
        local gear = {}
        for index, slot in ipairs(slots) do
            local link = GetItemLink(BAG_WORN, slot, LINK_STYLE_DEFAULT)
            if link ~= "" then
                local hasSet, setName, _, normal, _, _, perfected = GetItemLinkSetInfo(link, true)
                local traitType = GetItemLinkTraitInfo(link)
                local trait = traitType ~= ITEM_TRAIT_TYPE_NONE and U.Plain(GetString("SI_ITEMTRAITTYPE", traitType)) or ""
                gear[#gear + 1] = table.concat({ index, U.Clean(U.Plain(GetItemLinkName(link))), GetItemLinkDisplayQuality(link), U.Clean(trait),
                                                 hasSet and U.Clean(U.Plain(setName)) or "", hasSet and ((normal or 0) + (perfected or 0)) or 0 }, "|")
            end
        end
        c.gear = gear
    end,
    start = function(queue)
        EVENT_MANAGER:RegisterForEvent(CT.name .. "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, queue)
        EVENT_MANAGER:AddFilterForEvent(CT.name .. "Worn", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end,
    columns = {
        { key = "wearing", title = "Wearing", width = 270, align = "left",
          head = "Wearing: the sets this character had on when it was last read, with how many pieces of each.\nHover a cell for every slot.",
          value = function(e) return SetsText(e.c, "  ·  ") end,
          display = function(v, e) return v ~= "" and v or (e.c.gear and #e.c.gear > 0 and "no sets" or "-") end,
          dim = function(v) return v == "" end,
          tip = function(e)
              if not e.c.gear then return "Not read yet: log in on this character once." end
              if #e.c.gear == 0 then return "Nothing equipped." end
              local lines = {}
              for _, set in ipairs(Sets(e.c)) do lines[#lines + 1] = string.format("%d  %s", set.pieces, set.name) end
              if #lines > 0 then lines[#lines + 1] = "" end
              for _, item in ipairs(Items(e.c)) do lines[#lines + 1] = ItemLine(item, true) end
              return table.concat(lines, "\n")
          end },
    },
    sections = function(e)
        if not e.c.gear or #e.c.gear == 0 then return nil end
        local section = { title = "Wearing", lines = {} }
        local sets = SetsText(e.c, "  ·  ")
        if sets ~= "" then section.lines[1] = { sets, bold = true } end
        for _, item in ipairs(Items(e.c)) do
            local text = ItemLine(item, true)
            if item.set ~= "" then text = text .. "  ·  " .. item.set end
            section.lines[#section.lines + 1] = "    " .. text
        end
        return { section }
    end,
    export = { { "Wearing", function(e) return SetsText(e.c, ", ") end } },
})
