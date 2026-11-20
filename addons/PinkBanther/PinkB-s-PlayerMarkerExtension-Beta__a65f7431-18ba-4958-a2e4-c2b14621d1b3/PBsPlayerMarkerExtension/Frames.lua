-- The extra markers in the group frames: the names at the top left of the HUD, where the game shows its own markers.
--
-- HOW THE GAME SHOWS ITS OWN MARKER THERE (esoui/ingame/unitframes/unitframes.lua, ZO_UnitFrameObject:UpdateName; read, not
-- measured): the marker is not a control of its own, it is an inline picture at the FRONT OF THE FRAME'S NAME LABEL:
--
--     nameText = zo_iconTextFormatNoSpace(iconPath, "100%", "100%", name)       -- "|t100%:100%:<path>|t<name>"
--     self.nameLabel:SetText(nameText)
--
-- and ZO_UnitFrames_Manager:UpdateNames() runs it again on EVENT_TARGET_MARKER_UPDATE, on group changes and so on. An add-on
-- cannot give the game's marker another picture, and hooking UpdateName is out (the client's code stays untouched: PB's note
-- "ESO add-on code is insecure"). What a text label allows without any client function is the same inline picture put in front of
-- the label's CURRENT text, so that is what is done:
--
--   * the frames are read as data: UNIT_FRAMES.groupFrames[tag] / .raidFrames[tag] (the client's own tables, by unit tag),
--     each frame's `nameLabel`, and its `hidden` flag (the frame that is not on screen is left alone). No client function is called;
--   * a label is changed with its own SetText/GetText only, and only for a person who has an extra marker, is online, and has no
--     marker of the game's on them (the game's own picture is there then);
--   * the game writes the label again whenever it redraws the names (a marker changed, the group changed), which takes ours away:
--     each frame this add-on looks at the labels it carries and puts the picture back (GetText, a plain find, nothing built while
--     the picture is there). The set of labels is worked out ten times a second and at once when a marker or the group changes;
--   * a picture whose marker is gone is taken off the text again; the game never reads the label's text back (checked in the
--     client source), so the markup cannot reach any other code.
--
-- The switch is the setting "frameMarks". A label that the game rewrites every frame would be fought over: more than 40 writes in a
-- second on one label switches this part off for the session and puts every label back (`/pbpme status` says so).
--
-- NOT MEASURED ON A PS5: that the picture of this add-on's folder shows in a label (it is the same file the 3D markers use), that the
-- game's group frames are the objects described above on a console, and how often the game rewrites the names.
local A, S = PBS_PME, PBS_PME_STRINGS

local FRAME_MS = 100 -- the set of labels to carry a picture is worked out this often (and at once when something changed)
local BURST_LIMIT = 40 -- writes to one label in one second before this is given up

A.frames = {
	items = {}, -- label -> { label, icon, prefix, tag, keep, burst, burstAt }
	list = {}, -- the same items as an array, for the walk every frame
	count = 0,
	prefixes = {}, -- icon -> { path, text } for every picture that was put on a label (so that all of them can be taken off)
	rebuiltAt = -1e9,
	dirty = true,
	patched = 0, -- writes that put a picture on a label
	restored = 0, -- writes that took one off
	errors = 0,
	errorsInRow = 0,
	lastError = nil,
	off = nil, -- why this part is off for the session
	found = nil, -- did UNIT_FRAMES exist the last time it was asked
}

local function NoneType()
	return TARGET_MARKER_TYPE_NONE or 0
end

-- The inline picture for an icon, in the form the game itself writes it ("|t100%:100%:path|t").
function A:FramePrefix(icon)
	local f = self.frames
	local path = A.IconPath(icon)
	local entry = f.prefixes[icon]
	if not entry or entry.path ~= path then
		entry = { path = path, text = "|t100%:100%:" .. path .. "|t" }
		f.prefixes[icon] = entry
	end
	return entry.text
end

-- A text without any picture of this add-on at its front (every picture it ever wrote, in case the folder changed).
local function Strip(f, text)
	local again = true
	while again do
		again = false
		for _, entry in pairs(f.prefixes) do
			local n = #entry.text
			if text:sub(1, n) == entry.text then
				text = text:sub(n + 1)
				again = true
				break
			end
		end
	end
	return text
end

-- The name label of the frame for `tag` when that frame is on screen.
local function LabelOf(frames, tag)
	local frame = type(frames) == "table" and frames[tag] or nil
	if type(frame) == "table" and frame.hidden == false then
		return frame.nameLabel
	end
	return nil
end

-- The labels of the group frame and the raid frame for a unit tag (the game keeps both sets; only one is on screen).
function A:FrameLabels(tag)
	local manager = _G.UNIT_FRAMES
	local f = self.frames
	if type(manager) ~= "table" then
		f.found = false
		return nil, nil
	end
	f.found = true
	return LabelOf(manager.groupFrames, tag), LabelOf(manager.raidFrames, tag)
end

local function Want(self, label, icon, tag)
	local f = self.frames
	local item = f.items[label]
	if item then
		item.keep = true
		if item.icon ~= icon then
			item.icon = icon
			item.prefix = self:FramePrefix(icon)
		end
	else
		f.items[label] = { label = label, icon = icon, prefix = self:FramePrefix(icon), tag = tag, keep = true, burst = 0, burstAt = 0 }
	end
end

-- The text of a label without our picture (a label that is no longer wanted, or one that is being given another picture).
local function Release(self, item)
	local f = self.frames
	local ok, text = pcall(item.label.GetText, item.label)
	if ok and type(text) == "string" then
		local base = Strip(f, text)
		if base ~= text then
			pcall(item.label.SetText, item.label, base)
			f.restored = f.restored + 1
		end
	end
end

-- Which labels carry a picture now: those of the people with an extra marker who are online and have none of the game's own.
function A:RebuildFrames(now, wanted)
	local f = self.frames
	local sv = self.sv
	f.rebuiltAt, f.dirty = now, false
	local items = f.items
	for _, item in pairs(items) do
		item.keep = false
	end
	if wanted then
		local roster = self.roster
		local none = NoneType()
		for hash, m in pairs(self.marks) do
			local entry = roster.byHash[hash]
			-- (the same people the world draws: not a logged-out member, and not a marker others put on the player when that is off;
			-- the player's own frame is group-something while grouped, and alone there is no frame to write to)
			if entry and entry.online and entry.tag ~= "player" and not (entry.self and not (sv.showSelf or m.mine))
				and self:EngineMarkerOf(entry) == none then
				local a, b = self:FrameLabels(entry.tag)
				if a ~= nil then
					Want(self, a, m.icon, entry.tag)
				end
				if b ~= nil then
					Want(self, b, m.icon, entry.tag)
				end
			end
		end
	end
	for label, item in pairs(items) do
		if not item.keep then
			Release(self, item)
			items[label] = nil
		end
	end
	local list, n = f.list, 0
	for _, item in pairs(items) do
		n = n + 1
		list[n] = item
	end
	for i = n + 1, f.count do
		list[i] = nil
	end
	f.count = n
end

-- Puts every picture back and stops (the game rewrites a label too often, or something raised an error again and again).
function A:FramesOff(reason)
	local f = self.frames
	f.off = reason
	for label, item in pairs(f.items) do
		pcall(Release, self, item)
		f.items[label] = nil
	end
	for i = 1, f.count do
		f.list[i] = nil
	end
	f.count = 0
	self:Trace("frames", "group frames are left alone for this session: " .. tostring(reason))
end

-- Every frame (the tick calls it under its own pcall, so a failure in here never stops the 3D markers).
function A:UpdateFrames(now)
	local f = self.frames
	if f.off then
		return
	end
	local sv = self.sv
	local wanted = sv.enabled and sv.frameMarks and next(self.marks) ~= nil
	if not wanted and f.count == 0 then
		f.dirty = false
		return
	end
	if f.dirty or not wanted or now - f.rebuiltAt >= FRAME_MS then
		self:RebuildFrames(now, wanted)
	end
	local list = f.list
	for i = 1, f.count do
		local item = list[i]
		local text = item.label:GetText()
		if type(text) == "string" and text:find(item.prefix, 1, true) ~= 1 then
			-- the game wrote the name again (or this is the first look): our picture goes in front of it
			if now - item.burstAt > 1000 then
				item.burstAt, item.burst = now, 0
			end
			item.burst = item.burst + 1
			if item.burst > BURST_LIMIT then
				self:FramesOff("the game rewrites a name label more than " .. BURST_LIMIT .. " times a second")
				return
			end
			item.label:SetText(item.prefix .. Strip(f, text))
			f.patched = f.patched + 1
		end
	end
end

-- Called by the tick: a failure counts, and five in a row switch this part off.
function A:FramesTick(now)
	local ok, err = pcall(self.UpdateFrames, self, now)
	local f = self.frames
	if ok then
		f.errorsInRow = 0
		return
	end
	f.errors = f.errors + 1
	f.errorsInRow = f.errorsInRow + 1
	f.lastError = tostring(err)
	if f.errorsInRow >= 5 then
		self:FramesOff("errors: " .. f.lastError)
	end
end

-- A line for /pbpme status.
function A:FramesText()
	local f = self.frames
	if f.off then
		return "OFF for this session: " .. tostring(f.off)
	end
	local sv = self.sv
	local manager = _G.UNIT_FRAMES
	local state = type(manager) ~= "table" and "the game's UNIT_FRAMES is not there" or "UNIT_FRAMES found"
	return string.format("%s | setting %s | labels carrying a marker %d | written %d times, taken off %d times | errors %d%s",
		state, sv and sv.frameMarks and "on" or "off", f.count, f.patched, f.restored, f.errors,
		f.lastError and (" (last: " .. f.lastError .. ")") or "")
end

A.MARK("Frames")
