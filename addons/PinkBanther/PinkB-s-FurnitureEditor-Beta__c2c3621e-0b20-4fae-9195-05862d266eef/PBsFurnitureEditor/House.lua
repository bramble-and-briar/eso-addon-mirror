-- PB's FurnitureEditor -- reading a house, finding its linked groups, and the clipboard
--
-- Reading needs nothing open: a previous add-on measured 202 furnishings walked, with names,
-- data ids and bounds, from the street side of a house door with the editor closed. The same
-- walk gives each furnishing's position, orientation, parent and children, so a house can be
-- read as a forest of link trees: a root is a furnishing with children and no parent, and a
-- "group" is a root with everything below it.

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local IdKey, IsNoId = addon.IdKey, addon.IsNoId
local Print, Line = addon.Print, addon.Line

local MAX_FURNISHINGS = 20000

-- ---------------------------------------------------------------------------------------
-- Where we are, and whether we may look
--
-- Copying is limited to houses the player can edit. Reading a stranger's house works for a
-- visitor too, but a link tree is somebody's evening of work, and the point of this add-on is
-- moving your own builds between your own houses.
-- ---------------------------------------------------------------------------------------

function addon:HouseAccess()
	local houseId = Try1(GetCurrentZoneHouseId) or 0
	if houseId == 0 then
		return nil, "you are not in a house"
	end

	local owner = Try1(IsOwnerOfCurrentHouse) and true or false
	local editor = owner or (Try1(HasAnyEditingPermissionsForCurrentHouse) and true or false)

	return {
		houseId = houseId,
		owner = owner,
		editor = editor,
		ownerName = Try1(GetCurrentHouseOwner) or "?",
	}
end

function addon:PlayerPose()
	local results = Call(GetPlayerWorldPositionInHouse)
	if not results or results[1] == nil then
		return nil
	end
	return { x = results[1], y = results[2], z = results[3], rot = results[4] or 0 }
end

-- ---------------------------------------------------------------------------------------
-- Reading one furnishing
-- ---------------------------------------------------------------------------------------

-- Item or collectible? The client's own housing code (furnitureclasses_shared.lua) asks
-- GetPlacedFurnitureLink for an item link and a collectible link, and when the collectible link is not
-- empty takes the collectible id from it. GetCollectibleIdFromFurnitureId, which nothing in the client
-- calls, is NOT to be trusted: on the console it answered a non-zero number for ordinary items, and a
-- first real paste refused a whole group of stone slabs as "a collectible you cannot place".
--
-- Returns the collectible id, or 0 for an item, and which source decided.
local function ReadCollectibleId(id, dataId)
	local links = Call(GetPlacedFurnitureLink, id, LINK_STYLE_BRACKETS or 1)
	if links then
		local collectibleLink = links[2]
		if type(collectibleLink) == "string" and collectibleLink ~= "" then
			local collectibleId = Try1(GetCollectibleIdFromLink, collectibleLink)
			if collectibleId and collectibleId ~= 0 then
				return collectibleId, "link"
			end
		end
		return 0, "link"
	end

	-- No link call in this build: the raw call is believed only when the collectible it names
	-- really is this furnishing (its own furniture data id is the one we read).
	local raw = Try1(GetCollectibleIdFromFurnitureId, id)
	if raw and raw > 0 and dataId and dataId ~= 0 then
		local own = Try1(GetCollectibleFurnitureDataId, raw)
		if own ~= nil and own == dataId then
			return raw, "raw"
		end
	end
	return 0, "none"
end

local function ReadEntry(id)
	local entry = { id = id, key = IdKey(id) }

	local info = Call(GetPlacedHousingFurnitureInfo, id)
	if info then
		entry.name = addon.Clean(info[1])
		entry.dataId = info[3] or 0
	else
		entry.name = "?"
		entry.dataId = 0
	end

	local position = Call(HousingEditorGetFurnitureWorldPosition, id)
	if position then
		entry.x, entry.y, entry.z = position[1], position[2], position[3]
	end

	local orientation = Call(HousingEditorGetFurnitureOrientation, id)
	if orientation then
		entry.pitch, entry.yaw, entry.roll = orientation[1] or 0, orientation[2] or 0, orientation[3] or 0
	end

	local parent = Try1(GetPlacedFurnitureParent, id)
	if parent ~= nil and not IsNoId(parent) then
		entry.parentId = parent
		entry.parentKey = IdKey(parent)
	end

	entry.childKeys = {}
	entry.childIds = {}
	local children = Call(GetPlacedFurnitureChildren, id)
	if children then
		for i = 1, #children do
			if children[i] ~= nil and not IsNoId(children[i]) then
				entry.childIds[#entry.childIds + 1] = children[i]
				entry.childKeys[#entry.childKeys + 1] = IdKey(children[i])
			end
		end
	end

	entry.collectibleId, entry.kindFrom = ReadCollectibleId(id, entry.dataId)
	entry.state = Try1(GetPlacedHousingFurnitureCurrentObjectStateIndex, id)
	entry.numStates = Try1(GetPlacedHousingFurnitureNumObjectStates, id) or 0
	entry.pathNodes = Try1(HousingEditorGetNumPathNodesForFurniture, id) or 0

	return entry
end

addon.ReadEntry = ReadEntry

-- ---------------------------------------------------------------------------------------
-- Reading the house
--
-- house = { list = {entry...}, byKey = {key -> entry}, linked = n, inconsistent = n }
--
-- The two ends of a link are read separately (a furnishing's parent, and a furnishing's list of
-- children), and a client that disagreed with itself would otherwise lose half a group, so the
-- children of an entry are the union of both and the disagreements are counted.
-- ---------------------------------------------------------------------------------------

function addon:ReadHouse()
	local house = { list = {}, byKey = {}, linked = 0, inconsistent = 0 }

	local id = Try1(GetNextPlacedHousingFurnitureId, nil)
	while id ~= nil and not IsNoId(id) and #house.list < MAX_FURNISHINGS do
		local entry = ReadEntry(id)
		house.list[#house.list + 1] = entry
		house.byKey[entry.key] = entry
		id = Try1(GetNextPlacedHousingFurnitureId, id)
	end

	-- children implied by parents
	for _, entry in ipairs(house.list) do
		local parent = entry.parentKey and house.byKey[entry.parentKey]
		if parent then
			local known = false
			for _, childKey in ipairs(parent.childKeys) do
				if childKey == entry.key then
					known = true
					break
				end
			end
			if not known then
				parent.childKeys[#parent.childKeys + 1] = entry.key
				parent.childIds[#parent.childIds + 1] = entry.id
				house.inconsistent = house.inconsistent + 1
			end
		end
	end

	-- parents implied by children
	for _, entry in ipairs(house.list) do
		for _, childKey in ipairs(entry.childKeys) do
			local child = house.byKey[childKey]
			if child and not child.parentKey then
				child.parentKey = entry.key
				child.parentId = entry.id
				house.inconsistent = house.inconsistent + 1
			end
		end
	end

	for _, entry in ipairs(house.list) do
		if entry.parentKey or #entry.childKeys > 0 then
			house.linked = house.linked + 1
		end
	end

	return house
end

-- ---------------------------------------------------------------------------------------
-- Groups
--
-- A group lists its members parent-first (pre-order), so that a replay can place a parent
-- before its children and a child's parent index is always smaller than its own.
-- ---------------------------------------------------------------------------------------

local function Distance(pose, entry)
	if not pose or not entry.x then
		return nil
	end
	local dx, dy, dz = entry.x - pose.x, entry.y - pose.y, entry.z - pose.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function CollectGroup(house, root)
	local members = {}
	local seen = {}

	local function visit(entry)
		if seen[entry.key] then
			return
		end
		seen[entry.key] = true
		members[#members + 1] = entry

		-- a stable order, so that the same house always yields the same clipboard
		local kids = {}
		for _, childKey in ipairs(entry.childKeys) do
			local child = house.byKey[childKey]
			if child then
				kids[#kids + 1] = child
			end
		end
		table.sort(kids, function(a, b)
			if (a.dataId or 0) ~= (b.dataId or 0) then
				return (a.dataId or 0) < (b.dataId or 0)
			end
			return a.key < b.key
		end)
		for _, child in ipairs(kids) do
			visit(child)
		end
	end

	visit(root)
	return members
end

-- All the linked groups of a house, nearest to `pose` first (by name when there is no pose).
function addon:BuildGroups(house, pose)
	local groups = {}

	for _, entry in ipairs(house.list) do
		if not entry.parentKey and #entry.childKeys > 0 then
			local members = CollectGroup(house, entry)
			groups[#groups + 1] = {
				root = entry,
				members = members,
				count = #members,
				distance = Distance(pose, entry),
			}
		end
	end

	table.sort(groups, function(a, b)
		if a.distance and b.distance and a.distance ~= b.distance then
			return a.distance < b.distance
		end
		if a.root.name ~= b.root.name then
			return a.root.name < b.root.name
		end
		return a.root.key < b.root.key
	end)

	return groups
end

-- The root of the tree an entry belongs to, however deep it sits.
function addon:RootOf(house, entry)
	local current = entry
	local guard = 0
	while current.parentKey and house.byKey[current.parentKey] and guard < 1000 do
		current = house.byKey[current.parentKey]
		guard = guard + 1
	end
	return current
end

-- A single furnishing, or a whole tree, as a group.
function addon:GroupFromRoot(house, root, pose)
	local members = CollectGroup(house, root)
	return {
		root = root,
		members = members,
		count = #members,
		distance = Distance(pose, root),
	}
end

-- ---------------------------------------------------------------------------------------
-- The clipboard
--
-- clip = {
--   version, takenAt, houseId, owner,
--   anchor = { x, y, z, rot },          where the player stood when copying
--   nodes  = { { srcKey, dataId, collectibleId, name, x, y, z, pitch, yaw, roll,
--                state, numStates, parent = index or nil, pathNodes }, ... },
--   cut    = true while a "cut" has taken the furnishings out of their house and a paste has
--            not yet put them back (srcKey is the furnishing's id there, as a string),
-- }
--
-- Plain numbers and strings only: it goes into SavedVariables as it is.
-- ---------------------------------------------------------------------------------------

-- Whether an item stacks in a bag, and whether it is unique (only one may be owned), from its item link.
-- A cut needs the first to know how many bag slots the pieces will take. Nothing for a collectible.
local function ItemTraits(id)
	local links = Call(GetPlacedFurnitureLink, id, LINK_STYLE_BRACKETS or 1)
	local link = links and links[1]
	if type(link) ~= "string" or link == "" then
		return nil, nil
	end
	return Try1(IsItemLinkStackable, link), Try1(IsItemLinkUnique, link)
end

function addon:MakeClip(groups, access, pose)
	local nodes = {}

	for _, group in ipairs(groups) do
		local index = {}
		for _, member in ipairs(group.members) do
			local stackable, unique
			if (member.collectibleId or 0) == 0 then
				stackable, unique = ItemTraits(member.id)
			end
			nodes[#nodes + 1] = {
				srcKey = member.key,
				dataId = member.dataId,
				collectibleId = member.collectibleId or 0,
				name = member.name,
				x = member.x,
				y = member.y,
				z = member.z,
				pitch = member.pitch or 0,
				yaw = member.yaw or 0,
				roll = member.roll or 0,
				state = member.state,
				numStates = member.numStates or 0,
				pathNodes = member.pathNodes or 0,
				stackable = stackable,
				unique = unique,
				parent = member.parentKey and index[member.parentKey] or nil,
			}
			index[member.key] = #nodes
		end
	end

	local root = groups[1] and groups[1].root
	local anchor = pose and { x = pose.x, y = pose.y, z = pose.z, rot = pose.rot }
		or (root and { x = root.x, y = root.y, z = root.z, rot = 0 })

	return {
		version = 1,
		takenAt = Try1(GetTimeStamp) or 0,
		houseId = access.houseId,
		owner = access.ownerName,
		groups = #groups,
		anchor = anchor,
		nodes = nodes,
	}
end

function addon:ClipSummary(clip)
	local items, collectibles, links, paths = 0, 0, 0, 0
	for _, node in ipairs(clip.nodes) do
		if (node.collectibleId or 0) ~= 0 then
			collectibles = collectibles + 1
		else
			items = items + 1
		end
		if node.parent then
			links = links + 1
		end
		if (node.pathNodes or 0) > 0 then
			paths = paths + 1
		end
	end
	return items, collectibles, links, paths
end

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = DeepCopy(v)
	end
	return copy
end

addon.DeepCopy = DeepCopy

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

local function Meters(cm)
	if not cm then
		return "?"
	end
	return string.format("%.1f m", cm / 100)
end

local function ReadForCopy(self)
	local access, why = self:HouseAccess()
	if not access then
		Print("%s", why)
		return nil
	end

	if not access.editor then
		Print("you can only copy from a house you can edit")
		return nil
	end

	local house = self:ReadHouse()
	if #house.list == 0 then
		Print("no furnishings read here (is the house still loading?)")
		return nil
	end

	return access, house, self:PlayerPose()
end

addon:AddCommand("list", "  /pbfe list              the linked groups in this house, nearest first", function(self)
	local access, house, pose = ReadForCopy(self)
	if not access then
		return
	end

	local groups = self:BuildGroups(house, pose)
	self.lastGroups = {}
	for i, group in ipairs(groups) do
		self.lastGroups[i] = group.root.key
	end

	Print("house %d: %d furnishings, %d of them linked, %d groups",
		access.houseId, #house.list, house.linked, #groups)
	if house.inconsistent > 0 then
		Print("the client disagreed with itself on %d links; both ends were used", house.inconsistent)
	end

	for i = 1, math.min(#groups, 15) do
		local group = groups[i]
		Line("  #%d  %d items  %s  %s", i, group.count, Meters(group.distance), group.root.name)
	end
	if #groups > 15 then
		Line("  ... and %d more; /pbfe copy near takes the first", #groups - 15)
	end
	if #groups > 0 then
		Line("  /pbfe copy 1   copies #1 (also: copy near, copy sel, copy all, copy 1 3 4)")
	end
end)

-- The furnishing the player has selected, or failing that the one under the reticle.
local function SelectedFurnitureId()
	local selected = Try1(HousingEditorGetSelectedFurnitureId)
	if selected ~= nil and not IsNoId(selected) then
		return selected
	end

	local target = Try1(HousingEditorGetTargetInfo)
	if target ~= nil and not IsNoId(target) then
		return target
	end

	return nil
end

-- Words that say how, not which: taken out of the argument list wherever they stand.
local function TakeFlag(words, flag)
	local found = false
	for i = #words, 1, -1 do
		if words[i] == flag then
			table.remove(words, i)
			found = true
		end
	end
	return found
end

addon.TakeFlag = TakeFlag

-- A cut has taken furnishings out of a house and they have not been put back anywhere yet. The
-- clipboard is the only record of where they went, so it is not replaced without being asked.
function addon:PendingCutBlocks(force)
	local clip = self.sv.clip
	if clip and clip.cut and not force then
		Print("the clipboard holds a cut that has not been pasted (%d furnishings).", #clip.nodes)
		if self.PrintCutAdvice then
			self:PrintCutAdvice(clip)
		end
		Print("paste it, or /pbfe save <name> it, or add 'force' to throw it away")
		return true
	end
	return false
end

-- Which groups the words name: <n> ... (numbers from the last /pbfe list), near, sel, all.
-- Returns access, house, pose, chosen -- or nil after saying why not. `verb` is for the messages.
function addon:SelectGroups(words, verb)
	local access, house, pose = ReadForCopy(self)
	if not access then
		return nil
	end

	local groups = self:BuildGroups(house, pose)
	local chosen = {}

	local what = words[1]
	if not what then
		Print("say which: /pbfe %s 1   (see /pbfe list)   or near, sel, all", verb)
		return nil
	elseif what == "all" then
		chosen = groups
	elseif what == "near" then
		if not groups[1] then
			Print("no linked groups here")
			return nil
		end
		chosen = { groups[1] }
	elseif what == "sel" then
		local id = SelectedFurnitureId()
		if not id then
			Print("nothing selected or under the reticle")
			return nil
		end
		local entry = house.byKey[IdKey(id)]
		if not entry then
			Print("that furnishing is not in the house list")
			return nil
		end
		chosen = { self:GroupFromRoot(house, self:RootOf(house, entry), pose) }
	else
		local byRoot = {}
		for _, group in ipairs(groups) do
			byRoot[group.root.key] = group
		end
		for _, word in ipairs(words) do
			local number = tonumber(word)
			local key = number and self.lastGroups and self.lastGroups[number]
			local group = key and byRoot[key]
			if not group then
				Print("no group #%s -- /pbfe list first, the numbers change as you walk", word)
				return nil
			end
			chosen[#chosen + 1] = group
		end
	end

	if #chosen == 0 then
		Print("nothing to %s", verb)
		return nil
	end

	return access, house, pose, chosen
end

addon:AddCommand("copy", "  /pbfe copy <n>|near|sel|all   put linked groups on the clipboard", function(self, words)
	local force = TakeFlag(words, "force")
	if self:PendingCutBlocks(force) then
		return
	end

	local access, _, pose, chosen = self:SelectGroups(words, "copy")
	if not access then
		return
	end

	local clip = self:MakeClip(chosen, access, pose)
	self.sv.clip = clip
	self.sv.clipFresh = true

	local items, collectibles, links, paths = self:ClipSummary(clip)
	Print("copied %d furnishings in %d groups (%d items, %d collectibles, %d links)",
		#clip.nodes, #chosen, items, collectibles, links)
	if paths > 0 then
		Print("%d of them follow a path; the path is NOT copied", paths)
	end
	if not pose then
		Print("could not read your position; paste will use the first group's root")
	end
	Print("go to a house of yours: the quickslot wheel offers Paste (or /pbfe paste)")
	self:AnnounceMenu()
end)

addon:AddCommand("show", "  /pbfe show              what is on the clipboard", function(self)
	local clip = self.sv.clip
	if not clip then
		Print("the clipboard is empty")
		return
	end

	local items, collectibles, links, paths = self:ClipSummary(clip)
	Print("clipboard: %d furnishings, %d groups, from house %s (owner %s)",
		#clip.nodes, clip.groups or 1, tostring(clip.houseId), tostring(clip.owner))
	Print("%d items, %d collectibles, %d links, %d on paths", items, collectibles, links, paths)
	if addon.ClipKinds then
		Print("by the house's limits: %s", addon:ClipKinds(clip.nodes))
	end
	if clip.cut then
		Print("this is a CUT: the furnishings are out of house %s and in your bags, not yet pasted", tostring(clip.houseId))
	end

	for i = 1, math.min(#clip.nodes, 10) do
		local node = clip.nodes[i]
		Line("  %d%s  %s%s", i, node.parent and (" <- " .. node.parent) or "", node.name or "?",
			(node.collectibleId or 0) ~= 0 and " (collectible)" or "")
	end
	if #clip.nodes > 10 then
		Line("  ... and %d more", #clip.nodes - 10)
	end
end)

addon:AddCommand("clear", nil, function(self, words)
	if self:PendingCutBlocks(TakeFlag(words, "force")) then
		return
	end
	self.sv.clip = nil
	self.sv.clipFresh = false
	Print("clipboard emptied")
end)

addon:AddCommand("save", "  /pbfe save|load|drop <name>, saved   keep clipboards under a name", function(self, words)
	local name = words[1]
	if not name then
		Print("save under what name?")
		return
	end
	if not self.sv.clip then
		Print("the clipboard is empty")
		return
	end
	self.sv.library[name] = addon.DeepCopy(self.sv.clip)
	Print("saved as %s", name)
end)

addon:AddCommand("load", nil, function(self, words)
	if self:PendingCutBlocks(TakeFlag(words, "force")) then
		return
	end
	local saved = words[1] and self.sv.library[words[1]]
	if not saved then
		Print("nothing saved under that name (/pbfe saved)")
		return
	end
	self.sv.clip = addon.DeepCopy(saved)
	self.sv.clipFresh = true
	Print("%s is on the clipboard: %d furnishings", words[1], #saved.nodes)
end)

addon:AddCommand("drop", nil, function(self, words)
	if words[1] and self.sv.library[words[1]] then
		self.sv.library[words[1]] = nil
		Print("dropped %s", words[1])
	else
		Print("nothing saved under that name")
	end
end)

addon:AddCommand("saved", nil, function(self)
	local any = false
	local names = {}
	for name in pairs(self.sv.library) do
		names[#names + 1] = name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		any = true
		Line("  %s: %d furnishings", name, #self.sv.library[name].nodes)
	end
	if not any then
		Print("nothing saved")
	end
end)
