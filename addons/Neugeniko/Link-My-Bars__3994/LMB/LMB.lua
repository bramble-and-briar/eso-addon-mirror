local gearlist = {}
local gearalist = {}
local gearolist = {}
local gearflist = {}
local ind = 1
local nheavy = 0
local nmedium = 0
local nlight = 0

local slotprio = {
	[EQUIP_SLOT_HEAD] = 9,
	[EQUIP_SLOT_SHOULDERS] = 10,
	[EQUIP_SLOT_CHEST] = 7,
	[EQUIP_SLOT_HAND] = 12,
	[EQUIP_SLOT_WAIST] = 13,
	[EQUIP_SLOT_LEGS] = 8,
	[EQUIP_SLOT_FEET] = 11,
	[EQUIP_SLOT_NECK] = 14,
	[EQUIP_SLOT_RING1] = 15,
	[EQUIP_SLOT_RING2] = 16,
	[EQUIP_SLOT_MAIN_HAND] = 3,
	[EQUIP_SLOT_OFF_HAND] = 5,
	[EQUIP_SLOT_BACKUP_MAIN] = 4,
	[EQUIP_SLOT_BACKUP_OFF] = 6,
}

local orderprio = {
	[EQUIP_SLOT_HEAD] = 1,
	[EQUIP_SLOT_SHOULDERS] = 2,
	[EQUIP_SLOT_CHEST] = 3,
	[EQUIP_SLOT_HAND] = 4,
	[EQUIP_SLOT_WAIST] = 5,
	[EQUIP_SLOT_LEGS] = 6,
	[EQUIP_SLOT_FEET] = 7,
	[EQUIP_SLOT_NECK] = 8,
	[EQUIP_SLOT_RING1] = 9,
	[EQUIP_SLOT_RING2] = 10,
	[EQUIP_SLOT_MAIN_HAND] = 11,
	[EQUIP_SLOT_OFF_HAND] = 12,
	[EQUIP_SLOT_BACKUP_MAIN] = 13,
	[EQUIP_SLOT_BACKUP_OFF] = 14,
}

local frontbar = {
	EQUIP_SLOT_MAIN_HAND,
	EQUIP_SLOT_OFF_HAND,
}

local backbar = {
	EQUIP_SLOT_BACKUP_MAIN,
	EQUIP_SLOT_BACKUP_OFF,
}

local body = {
	EQUIP_SLOT_HEAD,
	EQUIP_SLOT_SHOULDERS,
	EQUIP_SLOT_CHEST,
	EQUIP_SLOT_HAND,
	EQUIP_SLOT_WAIST,
	EQUIP_SLOT_LEGS,
	EQUIP_SLOT_FEET,
	EQUIP_SLOT_NECK,
	EQUIP_SLOT_RING1,
	EQUIP_SLOT_RING2,
}

local two_handers = {
    WEAPONTYPE_FIRE_STAFF,
    WEAPONTYPE_FROST_STAFF,
    WEAPONTYPE_HEALING_STAFF,
    WEAPONTYPE_LIGHTNING_STAFF,
    WEAPONTYPE_TWO_HANDED_AXE,
    WEAPONTYPE_TWO_HANDED_HAMMER,
    WEAPONTYPE_TWO_HANDED_SWORD,
    WEAPONTYPE_BOW,
}

local gearslots = {
	EQUIP_SLOT_HEAD,
	EQUIP_SLOT_SHOULDERS,
	EQUIP_SLOT_CHEST,
	EQUIP_SLOT_HAND,
	EQUIP_SLOT_WAIST,
	EQUIP_SLOT_LEGS,
	EQUIP_SLOT_FEET,
	EQUIP_SLOT_NECK,
	EQUIP_SLOT_RING1,
	EQUIP_SLOT_RING2,
	EQUIP_SLOT_MAIN_HAND,
	EQUIP_SLOT_OFF_HAND,
	EQUIP_SLOT_BACKUP_MAIN,
	EQUIP_SLOT_BACKUP_OFF,
}

local mundusAbs = {
  [13984] = 60599, -- shadow
  [13985] = 60554, -- tower
  [13940] = 60462, -- warrior
  [13974] = 60594, -- serpent
  [13943] = 60550, -- mage
  [13978] = 60579, -- lord
  [13977] = 60604, -- steed
  [13976] = 60574, -- lady
  [13979] = 60556, -- apprentice
  [13980] = 60589, -- ritual
  [13981] = 60584, -- lover
  [13982] = 60569, -- atronach
  [13975] = 60610, -- thief
}

local FoodAbs = {
    [68411] =  64711,  -- Crown Fortifying Meal
    [68416] =  64712,  -- Crown Refreshing Drink
    [61259] =  68233,  -- Garlic-and-Pepper Venison Steak
    [61259] =  68234,  -- Millet and Beef Stuffed Peppers
    [61259] =  68235,  -- Lilmoth Garlic Hagfish
    [61260] =  68236,  -- Firsthold Fruit and Cheese Plate
    [61260] =  68237,  -- Thrice-Baked Gorapple Pie
    [61260] =  68238,  -- Tomato Garlic Chutney
    [61261] =  68239,  -- Hearty Garlic Corn Chowder
    [61261] =  68240,  -- Bravil's Best Beet Risotto
    [61261] =  68241,  -- Tenmar Millet-Carrot Couscous
    [61257] =  68242,  -- Mistral Banana-Bunny Hash
    [61257] =  68243,  -- Melon-Baked Parmesan Pork
    [61257] =  68244,  -- Solitude Salmon-Millet Soup
    [61255] =  68245,  -- Sticky Pork and Radish Noodles
    [61255] =  68246,  -- Garlic Cod with Potato Crust
    [61255] =  68247,  -- Braised Rabbit with Spring Vegetables
    [61294] =  68248,  -- Chevre-Radish Salad with Pumpkin Seeds
    [61294] =  68249,  -- Grapes and Ash Yam Falafel
    [61294] =  68250,  -- Late Hearthfire Vegetable Tart
    [61218] =  68251,  -- Capon Tomato-Beet Casserole
    [61218] =  68252,  -- Jugged Rabbit in Preserves
    [61218] =  68253,  -- Longfin Pasty with Melon Sauce
    [61218] =  68254,  -- Withered Tree Inn Venison Pot Roast
    [61322] =  68255,  -- Kragenmoor Zinger Mazte
    [61322] =  68256,  -- Colovian Ginger Beer
    [61322] =  68257,  -- Markarth Mead
    [61325] =  68258,  -- Heart's Day Rose Tea
    [61325] =  68259,  -- Soothing Bard's-Throat Tea
    [61325] =  68260,  -- Muthsera's Remorse
    [61328] =  68261,  -- Fredas Night Infusion
    [61328] =  68262,  -- Old Hegathe Lemon Kaveh
    [61328] =  68263,  -- Hagraven's Tonic
    [61335] =  68264,  -- Port Hunding Pinot Noir
    [61335] =  68265,  -- Dragontail Blended Whisky
    [61335] =  68266,  -- Bravil Bitter Barley Beer
    [61340] =  68267,  -- Wide-Eye Double Rye
    [61340] =  68268,  -- Camlorn Sweet Brown Ale
    [61340] =  68269,  -- Flowing Bowl Green Port
    [61345] =  68270,  -- Honest Lassie Honey Tea
    [61345] =  68271,  -- Rosy Disposition Tonic
    [61345] =  68272,  -- Cloudrest Clarified Coffee
    [61350] =  68273,  -- Senche-Tiger Single Malt
    [61350] =  68274,  -- Velothi View Vintage Malbec
    [61350] =  68275,  -- Orcrest Agony Pale Ale
    [61350] =  68276,  -- Lusty Argonian Maid Mazte
    [72816] =  71056,  -- Orzorga's Red Frothgar
    [72819] =  71057,  -- Orzorga's Tripe Trifle Pocket
    [72822] =  71058,  -- Orzorga's Blood Price Pie
    [72824] =  71059,  -- Orzorga's Smoked Bear Haunch
    [84678] =  87685,  -- Sweet Sanguine Apples
    [84681] =  87686,  -- Crisp and Crunchy Pumpkin Snack Skewer
    [84700] =  87687,  -- Bowl of "Peeled Eyeballs"
    [84704] =  87690,  -- Witchmother's Party Punch
    [84709] =  87691,  -- Crunchy Spider Skewer
    [84720] =  87695,  -- Ghastly Eye Bowl
    [84725] =  87696,  -- Frosted Brains
    [84731] =  87697,  -- Witchmother's Potent Brew
    [84735] =  87699,  -- Purifying Bloody Mara
    [85484] =  94437,  -- Crown Crate Fortifying Meal
    [85497] =  94438,  -- Crown Crate Refreshing Drink
    [86559] =  101879,  -- Hissmir Fish-Eye Rye
    [86673] =  112425,  -- Lava Foot Soup-and-Saltrice
    [86677] =  112426,  -- Bergama Warning Fire
    [86746] =  112433,  -- Betnikh Twice-Spiked Ale
    [86749] =  112434,  -- Jagga-Drenched "Mud Ball"
    [84678] =  112435,  -- Old Aldmeri Orphan Gruel
    [86787] =  112438,  -- Rajhin's Sugar Claws
    [86789] =  112439,  -- Alcaire Festival Sword-Pie
    [86791] =  112440,  -- Snow Bear Glow-Wine
    [84678] =  120436,  -- Princess's Delight
    [89955] =  120762,  -- Candied Jester's Coins
    [89957] =  120763,  -- Dubious Camoran Throne
    [89971] =  120764,  -- Jewels of Misrule
    [100502] =  133554,  -- Deregulated Mushroom Stew
    [100488] =  133555,  -- Spring-Loaded Infusion
    [100498] =  133556,  -- Clockwork Citrus Filet
    [107748] =  139016,  -- Artaeum Pickled Fish Bowl
    [107789] =  139018,  -- Artaeum Takeaway Broth
    [127531] =  153625,  -- Corrupting Bloody Mara
    [127572] =  153627,  -- Pack Leader's Bone Broth
    [127596] =  153629,  -- Bewitched Sugar Skulls
    [148633] =  171322,  -- Sparkling Mudcrab Apple Cider
}

local function getCurrentMundus()
	local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
		if mundusAbs[id] then return id end
	end
	return false
end

local function getCurrentFood()
	local numBuffs = GetNumBuffs("player")
    for i = 1, numBuffs do
        local _, _, _, _, _, _, _, _, _, _, id = GetUnitBuffInfo("player", i)
		if FoodAbs[id] then return id end
	end
	return false

end

local function ListMyClassMasteries()
    -- Loop through all skill lines to find the "Class Mastery" line
    local compactMast = ""
    local foundIt = 0
    for skillType = 1, GetNumSkillTypes() do
        for skillLineIndex = 1, GetNumSkillLines(skillType) do
            local skillLineName, _, _, _, _, _, _, _, _ = GetSkillLineInfo(skillType, skillLineIndex)
            if skillLineName == "Class Mastery" then
                local numAbilities = GetNumSkillAbilities(skillType, skillLineIndex)
                -- Loop through the 5 masteries in this line
                for abilityIndex = 1, numAbilities do
                    local name, _, _, _, _, isPurchased, _, _, _ = GetSkillAbilityInfo(skillType, skillLineIndex, abilityIndex)
                    -- Check if you have allocated a mastery point to this passive
                    local abilityId = GetSkillAbilityId(skillType, skillLineIndex, abilityIndex, false)

                    -- 2. Convert the Ability ID into a formatted Skill Link
                    local skillLink = GetAbilityLink(abilityId, LINK_STYLE_BRACKETS)
                    if isPurchased then
                        compactMast = compactMast .. skillLink
                        foundIt = 1
                    end
                end
            end
        end
    end
    if foundIt == 1 then
        return compactMast
    else
        return false
    end
end

local function ListMySubclassLines()
    local skillType = SKILL_TYPE_CLASS -- Class Skill Category
    local numSkillLines = GetNumSkillLines(skillType)
    local compactLines = ""
    for i = 1, numSkillLines do
        -- Get the name and details of the class skill lines currently loaded
        local name, rank, available, skillLineId = GetSkillLineInfo(skillType, i)

        if available then
            -- Optional: Check if it's active or mastered
            local firstWord = name:match("^([%S]+)")
            if firstWord == "Class" then
                skip = 1
            else
                compactLines = compactLines .. firstWord .. "/"
            end
        end
    end
    finalStr = string.sub(compactLines, 1 , -2)
    return finalStr
end



local function LinkMyBar(hotbarCategory)
    local barabilities = ""
    for slotNum = 3,8 do
        local abilityId = GetSlotBoundId(slotNum,hotbarCategory)
        local thisabilitylink = ""
        local abilitylink = GetAbilityLink(abilityId, LINK_STYLE_BRACKETS)
            local a,b,c = GetCraftedAbilityActiveScriptIds(abilityId)
            if a > 0 and b > 0 and c >0 then
                thisabilitylink = GetCraftedAbilityLink(abilityId,a,b,c,LINK_STYLE_BRACKETS)
            else
                thisabilitylink = abilitylink
            end
        barabilities = barabilities .. thisabilitylink
    end
    return barabilities
end

local function ls_addchatchamp(_, ChannelType, fromName, _, _, fromDisplayName)
    if fromDisplayName == GetDisplayName() or CHAT_CHANNEL_WHISPER_SENT==ChannelType then
        local mast = ListMyClassMasteries()

        if mast then
            submaster = " Masteries: " .. mast
        else
            submaster = " Class Lines: " .. ListMySubclassLines()
        end
        StartChatInput(submaster)
        EVENT_MANAGER:UnregisterForEvent("LMB", EVENT_CHAT_MESSAGE_CHANNEL)
    end
end

function LinkMyChampandmisc()
    local chlinks = ""
    for i=2,3 do
        if i == 2 then
            chlinks = chlinks .. "Blue CP: "
        else
            chlinks = chlinks .. " Red CP: "
        end
        for j=1,4 do
			local mySlot = (i-1) * 4 + j
			local mySk = GetSlotBoundId(mySlot, HOTBAR_CATEGORY_CHAMPION)
            local abilityId = GetChampionAbilityId(mySk)
            local abilitylink = GetAbilityLink(abilityId, LINK_STYLE_BRACKETS)
            chlinks = chlinks .. abilitylink
        end
	end
    local mundus = getCurrentMundus()
    local munduslink = GetAbilityLink(mundus, LINK_STYLE_BRACKETS)
    local food = getCurrentFood()
    local foodlink = ""
    if food then
        foodlink = GetAbilityLink(food, LINK_STYLE_BRACKETS)
    end
    local slot = GetCurrentQuickslot()
    local pot = zo_strformat("[<<1>>]", GetSlotItemLink(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL))

    StartChatInput(chlinks .. " Mundus: " .. munduslink .. " Food: " .. foodlink .. " Quick: " .. pot)

    EVENT_MANAGER:RegisterForEvent("LMB", EVENT_CHAT_MESSAGE_CHANNEL, ls_addchatchamp)
end

function LinkMyBars()
    local firstbar = LinkMyBar(HOTBAR_CATEGORY_PRIMARY)
    local secondbar = LinkMyBar(HOTBAR_CATEGORY_BACKUP)
    StartChatInput("Front Bar: " .. firstbar .. " Back Bar: " .. secondbar)
end

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function subdetail(setnamea, pce, mxneed)
    for _, gearab in ipairs( gearlist) do
        local limitused = string.find(gearab,"*")
        local limitlink = string.find(gearab,"*", limitused+1)
        local limitenc = string.find(gearab,"*", limitlink+1)
        if setnamea == string.sub(gearab,1, limitused) then
            local fill = ""
            if not(mxneed == pce) then
                fill = "" .. string.format("%i", pce) .. "-"
            end
            local gearabmod = string.sub(gearab,1, limitenc) .. fill .. string.sub(gearab,limitenc+5)
            table.insert(gearalist, gearabmod)
        end
    end

end

local function ordersets()
    gearlist = {}
    gearalist = {}
    gearolist = {}
    gearflist = {}

    if WEAPONTYPE_SHIELD ==
            GetItemLinkWeaponType(GetItemLink( BAG_WORN, EQUIP_SLOT_OFF_HAND, LINK_STYLE_BRACKETS )) then
        slotprio[EQUIP_SLOT_MAIN_HAND] = 5
        slotprio[EQUIP_SLOT_OFF_HAND] = 3
    else
        slotprio[EQUIP_SLOT_MAIN_HAND] = 3
        slotprio[EQUIP_SLOT_OFF_HAND] = 5
    end
    if WEAPONTYPE_SHIELD ==
            GetItemLinkWeaponType(GetItemLink( BAG_WORN, EQUIP_SLOT_BACKUP_OFF, LINK_STYLE_BRACKETS )) then
        slotprio[EQUIP_SLOT_BACKUP_MAIN] = 6
        slotprio[EQUIP_SLOT_BACKUP_OFF] = 4
    else
        slotprio[EQUIP_SLOT_BACKUP_MAIN] = 4
        slotprio[EQUIP_SLOT_BACKUP_OFF] = 6
    end
    nheavy = 0
    nmedium = 0
    nlight = 0
    for _, gearSlot in ipairs( gearslots ) do
        local _, asetNm, _, _, maxeq, _, _ = GetItemLinkSetInfo(GetItemLink( BAG_WORN, gearSlot, LINK_STYLE_BRACKETS ))
        asetNm = string.gsub(asetNm, "Perfected ", "")
        local wtype = GetItemLinkWeaponType(GetItemLink( BAG_WORN, gearSlot, LINK_STYLE_BRACKETS ))
        local numslots = 1
        if has_value(two_handers, wtype) then
            numslots = 2
        end
        local slotype = "X"
        if has_value(frontbar, gearSlot) then
            slotype = "F"
        elseif has_value(backbar, gearSlot) then
            slotype = "K"
        elseif has_value(body, gearSlot) then
            slotype = "B"
        end
        local weight = GetItemLinkArmorType(GetItemLink( BAG_WORN, gearSlot, LINK_STYLE_BRACKETS ))
        if weight == ARMORTYPE_HEAVY then
            nheavy = nheavy + 1
        elseif weight == ARMORTYPE_MEDIUM then
            nmedium = nmedium + 1
        elseif weight == ARMORTYPE_LIGHT then
            nlight = nlight + 1
        end

        local valuedd = asetNm .. "*" .. string.format("%02i", slotprio[gearSlot]) .. "*"
                .. string.format("%02i", orderprio[gearSlot]) .. "*"
                .. string.format("%01i", numslots) .. string.format("%02i", maxeq)
                .. slotype .. GetItemLink( BAG_WORN, gearSlot, LINK_STYLE_BRACKETS )

        table.insert(gearlist, valuedd)
    end

    table.sort(gearlist)

    local nameset = ""
    local countf = 0
    local countk = 0
    local countb = 0
    local repl = 0
    local maxneed = 0
    local doublebarset = ""
    local doublebarsetdo = 2
    for x, geara in ipairs( gearlist) do
        local sslen = string.len(geara)
        if sslen > 11 then
            local limitused = string.find(geara,"*")
            local limitlink = string.find(geara,"*", limitused+1)
            local limitenc = string.find(geara,"*", limitlink+1)
            local slotstakenf = 0
            local slotstakenk = 0
            local slotstakenb = 0
            if not (nameset == "") and not (nameset == string.sub(geara,1, limitused)) then
                subdetail(nameset, repl, maxneed)
                countf = 0
                countk = 0
                countb = 0
            end
            if string.sub(geara,limitenc+4, limitenc+4) == "F" then
                slotstakenf = tonumber(string.sub(geara,limitenc+1, limitenc+1))

            elseif string.sub(geara,limitenc+4, limitenc+4) == "K" then
                slotstakenk =  tonumber(string.sub(geara,limitenc+1, limitenc+1))

            elseif string.sub(geara,limitenc+4, limitenc+4) == "B" then
                slotstakenb = tonumber(string.sub(geara,limitenc+1, limitenc+1))
            end
            maxneed = tonumber(string.sub(geara,limitenc+2, limitenc+3))
            countf = countf + slotstakenf
            countk = countk + slotstakenk
            countb = countb + slotstakenb
            local bar1 = countf + countb
            local bar2 = countk + countb
            if bar1 >= maxneed or bar2 >= maxneed then
                repl = maxneed
            else
                repl = math.max(bar1, bar2)
            end
            if countf == 2 and countk == 2 and bar2 >= maxneed and bar1 >= maxneed then
                doublebarset = string.sub(geara,1, limitused)
            end
            nameset = string.sub(geara,1, limitused)
        end
    end

    if not (nameset == "") then
        subdetail(nameset, repl, maxneed)
    end

    local nameset = ""
    for _, gear in ipairs( gearalist) do
        local sslen = string.len(gear)
        if sslen > 11 then
            local limitused = string.find(gear,"*")
            local limitlink = string.find(gear,"*", limitused+1)
            if not (nameset == string.sub(gear,1, limitused))
                    or (doublebarset == string.sub(gear,1, limitused) and doublebarsetdo>0) then
                table.insert(gearolist, string.sub(gear,limitlink +1))
                if  (doublebarset == string.sub(gear,1, limitused)) then
                    doublebarsetdo = doublebarsetdo - 1
                end
            end
            nameset = string.sub(gear,1, limitused)
        end
    end

    table.sort(gearolist)
    for _, final in ipairs( gearolist) do
        table.insert(gearflist, string.sub(final,4))
    end
end



local function ls_addchat(_, ChannelType, fromName, _, _, fromDisplayName)
    if fromDisplayName == GetDisplayName() or CHAT_CHANNEL_WHISPER_SENT==ChannelType then
        ind = ind + 4
        local nextfour = ""
        for i = math.min(ind,#gearflist), math.min(ind+3,#gearflist) do
            nextfour = nextfour .. gearflist[i]
        end
        StartChatInput("Sets: " .. nextfour)
        if (ind + 4 > #gearflist ) then
            EVENT_MANAGER:UnregisterForEvent("LMB", EVENT_CHAT_MESSAGE_CHANNEL)
        end
    end
end



function LinkMySets()
    ordersets()
    ind = 1
    if (#gearflist > 0) then
        local nextfour = ""
        for i = math.min(ind,#gearflist), math.min(ind+3,#gearflist) do
            nextfour = nextfour .. gearflist[i]
        end
        StartChatInput("Weights: " .. string.format("%01i", nheavy)
                .. string.format("%01i", nmedium) .. string.format("%01i", nlight)
                .. " Sets: " .. nextfour)
        if (#gearflist > 4) then
            EVENT_MANAGER:RegisterForEvent("LMB", EVENT_CHAT_MESSAGE_CHANNEL, ls_addchat)
        end
    end
end

SLASH_COMMANDS["/lmb"] = LinkMyBars
SLASH_COMMANDS["/lmc"] = LinkMyChampandmisc
SLASH_COMMANDS["/lmd"] = LinkMySets

local function OnAddonLoaded(event, addonName)
    if addonName == "LMB" then
        d("LMB Addon Loaded")
        EVENT_MANAGER:UnregisterForEvent("LMB", EVENT_ADD_ON_LOADED)
    end
end

local function sort_on_values(t,...)
    local a = {...}
    table.sort(t, function (u,v)
        for i = 1, #a do
            if u[a[i]] > v[a[i]] then return false end
            if u[a[i]] < v[a[i]] then return true end
        end
    end)
end

EVENT_MANAGER:RegisterForEvent("LMB", EVENT_ADD_ON_LOADED, OnAddonLoaded)
