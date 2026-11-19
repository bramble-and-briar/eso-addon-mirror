-- Does the game load this add-on's pictures? Looked at once per session, a moment after the first load screen.
--
-- WHY: a picture the game cannot load is not an error: the control just reports a 1 x 1 placeholder and nothing shows.
-- (PB's note "ESO manifest must list .dds": PBsJanken's pictures were 1 x 1 on a PS5 until the files were in the
-- manifest; PBsFMEGA reads the loader's verdict the same way.) So this file asks the game, with hidden probe controls that
-- are given each picture, whether it came out at its real size (128 x 128), and
--   * says so in the chat and in /pbpme status when pictures did not load, naming the first one and the size it got;
--   * tries the add-on's other possible folder (the path the game's own add-on list gives, as PBsJanken does) when the
--     usual "PBsPlayerMarkerExtension/assets/" gave nothing, and uses the one that works for the wheel and the 3D markers.
-- The textures load a little after SetTexture, so each folder is looked at twice (1.5 s, then 3 s later).
--
-- NOT MEASURED ON A PS5 yet: what the game answers for these files there.
local A, S = PBS_PME, PBS_PME_STRINGS

local EXPECTED = 128 -- the pictures are 128 x 128 (scripts/build_assets.py)
local FIRST_LOOK_MS = 1500
local SECOND_LOOK_MS = 3000

A.tex = {
	started = false,
	done = false,
	ok = nil, -- true: every picture loaded; false: some did not; nil: not known yet
	state = "not checked yet",
	root = nil, -- the folder in use once one has worked
	rootName = nil,
	tries = {}, -- one line per folder looked at
	probes = nil,
	lastError = nil,
}

-- The folders this add-on's pictures could be in: the usual one, and the one the game's add-on list reports.
function A:TextureRoots()
	local roots = { { name = "manifest path", path = A.ICON_PATH_DEFAULT } }
	local okManager, manager = pcall(function()
		return GetAddOnManager and GetAddOnManager()
	end)
	if okManager and manager and manager.GetAddOnRootDirectoryPath and manager.GetNumAddOns and manager.GetAddOnInfo then
		pcall(function()
			for index = 1, manager:GetNumAddOns() do
				if manager:GetAddOnInfo(index) == self.name then
					local root = manager:GetAddOnRootDirectoryPath(index)
					if type(root) == "string" and root ~= "" then
						-- (the trailing slashes are cut, then one is put back: gsub("/*$", "/") gives "//" in Lua 5.1, which the game runs)
						root = root:gsub("\\", "/"):gsub("/+$", "")
						local path = root .. "/assets/"
						if path ~= roots[1].path then
							roots[#roots + 1] = { name = "game's add-on path", path = path }
						end
					end
					return
				end
			end
		end)
	end
	return roots
end

local function FileNames()
	local names = {}
	for id = 1, A.ICON_COUNT do
		names[#names + 1] = string.format("icon%02d.dds", id)
	end
	names[#names + 1] = "clear.dds"
	return names
end

-- "ok", or "missing" (the 1 x 1 placeholder), or "other 64x64" / "not loaded"
local function Classify(control)
	local okSize, w, h = pcall(control.GetTextureFileDimensions, control)
	if not okSize then
		return "unreadable", tostring(w)
	end
	if w == EXPECTED and h == EXPECTED then
		return "ok"
	end
	if w == 1 and h == 1 then
		return "missing", "1x1"
	end
	return "other", tostring(w) .. "x" .. tostring(h)
end

-- Looks at every probe: counts, and the first that is not right.
function A:TextureLook(names)
	local probes = self.tex.probes
	local count = { ok = 0, bad = 0 }
	local first
	for i, name in ipairs(names) do
		local verdict, detail = Classify(probes[i])
		if verdict == "ok" then
			count.ok = count.ok + 1
		else
			count.bad = count.bad + 1
			first = first or (name .. " " .. (detail or verdict))
		end
	end
	return count, first
end

-- The folder works: the wheel and the 3D markers use it from now on.
function A:UseTextureRoot(root)
	local tex = self.tex
	tex.root, tex.rootName = root.path, root.name
	if A.ICON_PATH ~= root.path then
		A.ICON_PATH = root.path
		A.CLEAR_PATH = root.path .. "clear.dds"
		-- the 3D sprites remember which picture they hold: make them ask for it again
		if self.world then
			for _, item in ipairs(self.world.sprites) do
				item.icon = nil
			end
		end
		self:Trace("texture", "the pictures are used from the " .. root.name .. ": " .. root.path)
	end
end

function A:TextureFinish(ok, state)
	local tex = self.tex
	tex.done, tex.ok, tex.state = true, ok, state
end

-- Tries folder number `index`; `later` = this is the second look at it.
function A:TextureTry(roots, index, names, later)
	local tex = self.tex
	local root = roots[index]
	if not later then
		for i, name in ipairs(names) do
			tex.probes[i]:SetTexture(root.path .. name)
		end
	end
	local function look()
		local ok, err = pcall(function()
			local count, first = self:TextureLook(names)
			if count.bad == 0 then
				tex.tries[#tex.tries + 1] = string.format("%s: all %d pictures loaded", root.name, count.ok)
				self:UseTextureRoot(root)
				self:TextureFinish(true, string.format("all %d pictures loaded (%s)", count.ok, root.name))
			elseif not later then
				-- the loader may simply not be done: look once more
				zo_callLater(function()
					local fine, why = pcall(self.TextureTry, self, roots, index, names, true)
					if not fine then
						tex.lastError = tostring(why)
						self:TextureFinish(nil, "the check failed: " .. tex.lastError)
					end
				end, SECOND_LOOK_MS)
			else
				tex.tries[#tex.tries + 1] = string.format("%s: %d of %d did not load (first: %s)", root.name, count.bad, count.ok + count.bad, tostring(first))
				if roots[index + 1] then
					self:TextureTry(roots, index + 1, names, false)
				else
					self:TextureFinish(false, "NOT loaded: " .. table.concat(tex.tries, "; "))
					self:Trace("texture", "pictures did not load: " .. table.concat(tex.tries, "; "))
					self:Print(S.texturesMissing, count.bad, count.ok + count.bad, tostring(first))
				end
			end
		end)
		if not ok then
			tex.lastError = tostring(err)
			self:TextureFinish(nil, "the check failed: " .. tex.lastError)
		end
	end
	if later then
		look()
	else
		zo_callLater(look, FIRST_LOOK_MS)
	end
end

-- Once per session (or again for /pbpme textures).
function A:StartTextureCheck(again)
	local tex = self.tex
	if (tex.started and not again) or not zo_callLater or not WINDOW_MANAGER or not GuiRoot then
		return false
	end
	if again and not tex.done then
		return false -- one check at a time
	end
	tex.started, tex.done, tex.ok, tex.tries, tex.lastError = true, false, nil, {}, nil
	tex.state = "checking ..."
	local names = FileNames()
	if not tex.probes then
		tex.probes = {}
		for i = 1, #names do
			local probe = WINDOW_MANAGER:CreateControl("PBsPlayerMarkerExtensionProbe" .. i, GuiRoot, CT_TEXTURE)
			probe:SetHidden(true)
			probe:SetDimensions(1, 1)
			tex.probes[i] = probe
		end
	end
	-- start from the usual folder, so the pictures in use keep the path they have unless another one is shown to be better
	A.ICON_PATH, A.CLEAR_PATH = A.ICON_PATH_DEFAULT, A.ICON_PATH_DEFAULT .. "clear.dds"
	local ok, err = pcall(self.TextureTry, self, self:TextureRoots(), 1, names, false)
	if not ok then
		tex.lastError = tostring(err)
		self:TextureFinish(nil, "the check failed: " .. tex.lastError)
		return false
	end
	return true
end

A.MARK("Textures")
