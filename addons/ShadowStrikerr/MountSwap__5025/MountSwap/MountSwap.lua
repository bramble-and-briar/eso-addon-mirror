MountSwap = {}
local M = MountSwap
M.version = '0.8.9'
local NAME = 'MountSwap'
function M:Chat(message, force)
    local saved = self.saved
    if force or not saved or saved.chatMessages ~= false then
        d('|c88CCFFMountSwap:|r ' .. M.L(message))
    end
end
local function say(message) M:Chat(message) end
local function mountInfo(id)
    if type(id) ~= 'number' or id <= 0 then return end
    local name, _, _, _, unlocked, _, _, category = GetCollectibleInfo(id)
    if unlocked and category == COLLECTIBLE_CATEGORY_TYPE_MOUNT then return name end
end
-- Prefer the actual Collections category; wording is a fallback only.
function M:MountGroup(id)
    if not self.categoryGroups then self:Mounts() end
    local official = self.categoryGroups[id]
    if official then return official end
    local saved = self.saved
    local groups = saved and saved.groups
    local override = groups and groups[id]
    if override == 'multi' or override == 'single' then return override end
    local observedGroups = saved and saved.observedGroups
    local observed = observedGroups and observedGroups[id]
    if observed == 'multi' or observed == 'single' then return observed end
    local name, description = GetCollectibleInfo(id)
    local text = string.lower((name or '') .. ' ' .. (description or ''))
    if GetNumCollectibleTags and GetCollectibleTagInfo then
        for index = 1, GetNumCollectibleTags(id) do
            local tag = GetCollectibleTagInfo(id, index)
            text = text .. ' ' .. string.lower(tag or '')
        end
    end
    for _, marker in ipairs({'multi-rider', 'multi rider', 'two riders', 'additional rider', 'one passenger', 'two-seater', 'two seater', 'multiple riders'}) do
        if string.find(text, marker, 1, true) then return 'multi' end
    end
    for _, marker in ipairs({'single-rider', 'single rider'}) do
        if string.find(text, marker, 1, true) then return 'single' end
    end
    return 'review'
end
-- ESO exposes group-mount status for the mount being ridden, not arbitrary collectibles.
function M:ObserveMountedGroup()
    if not self.saved or not GetTargetMountedStateInfo or not GetUnitName or not MOUNTED_STATE_MOUNT_RIDER then return end
    local state, isGroupMount = GetTargetMountedStateInfo(GetUnitName('player'))
    if state ~= MOUNTED_STATE_MOUNT_RIDER or type(isGroupMount) ~= 'boolean' then return end
    local id = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if mountInfo(id) then
        self.saved.observedGroups[id] = isGroupMount and 'multi' or 'single'
    end
end
function M:SetGroup(group)
    if not self.saved or not mountInfo(self.selectedMountId) then
        say('Choose a mount in one of the lists first.'); return
    end
    if group ~= nil and group ~= 'multi' and group ~= 'single' then return end
    if self.categoryGroups and self.categoryGroups[self.selectedMountId] then
        say('ESO Collections identifies this mount as ' .. M.L(self.categoryGroups[self.selectedMountId] == 'multi' and 'Multi-Rider.' or 'Single-Rider.'))
        self:Refresh(); return
    end
    self.saved.groups[self.selectedMountId] = group
    self:Refresh()
end
function M:Mounts()
    local result, seen = {}, {}
    local memberships, multiCategories, foundMulti = {}, {}, {}
    self.categoryGroups = {}
    local categoryGroups = self.categoryGroups
    -- Stable collectible identities, not translated category names or fixed
    -- category positions. Grand Pillion Draft Horse and Nightmare Pillion
    -- Courser are multi-rider references; locked collectibles still have metadata.
    local referenceTop, referenceSub, inconsistent
    if GetCategoryInfoFromCollectibleId then
        for _, id in ipairs({9576,11887}) do
            local _, _, _, _, _, _, _, kind=GetCollectibleInfo(id)
            if kind==COLLECTIBLE_CATEGORY_TYPE_MOUNT then
                local top,sub,index=GetCategoryInfoFromCollectibleId(id)
                if type(top)=='number' and top>0 and type(sub)=='number' and sub>0 and
                    type(index)=='number' and index>0 and top<=GetNumCollectibleCategories() then
                    local _,count=GetCollectibleCategoryInfo(top)
                    if type(count)=='number' and sub<=count and
                        index<=GetNumCollectiblesInCollectibleCategory(top,sub) and GetCollectibleId(top,sub,index)==id then
                        if referenceTop and (referenceTop~=top or referenceSub~=sub) then inconsistent=true end
                        referenceTop,referenceSub=top,sub
                    end
                end
            end
        end
    end
    if inconsistent then referenceTop,referenceSub=nil,nil end
    local function scan(category, subcategory)
        for index = 1, GetNumCollectiblesInCollectibleCategory(category, subcategory) do
            local id = GetCollectibleId(category, subcategory, index)
            local name = mountInfo(id)
            if name and subcategory then
                memberships[id] = memberships[id] or {}
                memberships[id][#memberships[id] + 1] = {top = category, sub = subcategory}
            end
            if name and not seen[id] then
                seen[id] = true
                result[#result + 1] = { id = id, name = zo_strformat('<<1>>', name) }
            end
        end
    end
    for category = 1, GetNumCollectibleCategories() do
        scan(category, nil)
        local _, count = GetCollectibleCategoryInfo(category)
        for subcategory = 1, count do
            local name = GetCollectibleSubCategoryInfo(category, subcategory)
            local key = string.lower(zo_strformat('<<1>>', name or '')):gsub('[%s%-]', '')
            if (category==referenceTop and subcategory==referenceSub) or
                (not referenceTop and key == 'multirider') then
                multiCategories[category] = multiCategories[category] or {}
                multiCategories[category][subcategory] = true
                foundMulti[category] = true
            end
            scan(category, subcategory)
        end
    end
    -- Require a recognized Multi-Rider sibling before treating other mount
    -- subcategories as single-rider. Multi membership wins for duplicate entries.
    for id, categories in pairs(memberships) do
        for _, category in ipairs(categories) do
            if multiCategories[category.top] and multiCategories[category.top][category.sub] then
                categoryGroups[id] = 'multi'
                break
            elseif foundMulti[category.top] then
                categoryGroups[id] = 'single'
            end
        end
    end
    table.sort(result, function(a, b)
        local aKey, bKey = string.lower(a.name), string.lower(b.name)
        if aKey == bKey then return a.id < b.id end
        return aKey < bKey
    end)
    return result
end
local function slotName(slot)
    return slot <= 4 and ('M' .. slot) or ('S' .. (slot - 4))
end
function M:NotifyMessage(title, message, icon)
    if not self.notice then
        local w = WINDOW_MANAGER:CreateTopLevelWindow('MountSwapNotice')
        self.notice = w
        w:SetDimensions(520, 76)
        w:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -36, 72)
        w:SetDrawTier(DT_HIGH)
        w:SetMouseEnabled(false)
        local text = WINDOW_MANAGER:CreateControl(nil, w, CT_LABEL)
        self.noticeText = text
        text:SetDimensions(440, 70)
        text:SetAnchor(TOPRIGHT, w, TOPRIGHT, -76, 0)
        text:SetFont('ZoFontGameBold')
        text:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        local texture = WINDOW_MANAGER:CreateControl(nil, w, CT_TEXTURE)
        self.noticeIcon = texture
        texture:SetDimensions(64, 64)
        texture:SetAnchor(TOPRIGHT, w, TOPRIGHT, 0, 0)
    end
    self.noticeText:SetText(M.L(title) .. '\n|c66D6C9' .. message .. '|r')
    self.noticeIcon:SetTexture(icon or '')
    self.noticeIcon:SetHidden(not icon or icon == '')
    self.notice:SetHidden(false)
    self.noticeSequence = (self.noticeSequence or 0) + 1
    local sequence = self.noticeSequence
    zo_callLater(function()
        if self.noticeSequence == sequence then self.notice:SetHidden(true) end
    end, 4000)
end
function M:NotifyMount(id, title)
    local name, _, icon = GetCollectibleInfo(id)
    if name and name ~= '' then self:NotifyMessage(title, zo_strformat('<<1>>', name), icon) end
end
function M:ConfirmMountChange()
    local request = self.pendingMount
    if not request then return end
    local active = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if active == request.id then
        self.pendingMount = nil
        self:NotifyMount(request.id, 'Mount selected')
        say(request.source .. ': selected ' .. zo_strformat('<<1>>', mountInfo(request.id) or 'mount') .. '.')
    end
end
function M:Activate(id, source)
    if not self.saved then return end
    source = source or 'Mount'
    local name = mountInfo(id)
    if not name then say(source .. ': no unlocked mount is saved here.'); return end
    if GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER) == id then
        self:NotifyMount(id, 'Already selected')
        say(source .. ': ' .. zo_strformat('<<1>>', name) .. ' is already selected.'); return
    end
    if not IsCollectibleUsable(id, GAMEPLAY_ACTOR_CATEGORY_PLAYER) then
        say(source .. ': ESO does not allow switching to ' .. zo_strformat('<<1>>', name) .. ' right now.'); return
    end
    local request = {id = id, source = source}
    self.pendingMount = request
    UseCollectible(id, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    self:ConfirmMountChange()
    zo_callLater(function()
        if self.pendingMount ~= request then return end
        self:ConfirmMountChange()
        if self.pendingMount == request then
            self.pendingMount = nil
            say(source .. ': ESO did not confirm switching to ' .. zo_strformat('<<1>>', name) .. '. Check Bug Catcher and try /mountswap debug.')
        end
    end, 2500)
end
function M:Slot(slot)
    if not self.saved then return end
    local id = self.saved.slots[slot]
    if mountInfo(id) and self:MountGroup(id) ~= (slot <= 4 and 'multi' or 'single') then
        say(slotName(slot) .. ': this favorite needs reclassification or reassignment to the matching section.'); return
    end
    self:Activate(id, slotName(slot))
end
function M:Debug()
    local function debug(message) self:Chat(message, true) end
    debug(self:ControllerDiagnostics())
    local active = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    local slots = self.saved.slots
    debug('Version ' .. self.version .. ' | World: ' .. GetWorldName() .. ' | Active ID: ' .. tostring(active))
    for slot = 1, 8 do
        local id = slots[slot]
        debug(slotName(slot) .. ': ID ' .. tostring(id) .. ' | ' .. (mountInfo(id) or M.L('empty/unavailable')))
    end
end
function M:Random()
    if not self.saved then return end
    local active = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    local candidates = {}
    for _, mount in ipairs(self:Mounts()) do
        if mount.id ~= active and IsCollectibleUsable(mount.id, GAMEPLAY_ACTOR_CATEGORY_PLAYER) then
            candidates[#candidates + 1] = mount.id
        end
    end
    if #candidates == 0 then say('No other usable unlocked mounts were found.'); return end
    self:Activate(candidates[math.random(#candidates)], 'Random')
end
function M:Assign(slot, id)
    if not self.saved or not mountInfo(id) then return false end
    local expected = slot <= 4 and 'multi' or 'single'
    if self:MountGroup(id) ~= expected then
        say('Choose a ' .. M.L(expected == 'multi' and 'Multi-Rider' or 'Single-Rider') .. ' mount for this slot. Classify uncertain mounts first.')
        return false
    end
    self.saved.slots[slot] = id
    return true
end
function M:Save(slot)
    if not self.saved then return end
    local id = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if not mountInfo(id) then say('Select a mount in Collections first.'); return end
    self:ObserveMountedGroup()
    if self:Assign(slot, id) then say('Saved current mount to slot ' .. slot .. '.') end
    if self.window then self:Refresh() end
end
local COLORS = {
    text = {0.88, 0.92, 0.96, 1}, muted = {0.60, 0.68, 0.76, 1},
    multi = {0.40, 0.84, 0.79, 1}, single = {0.49, 0.72, 0.98, 1},
    review = {0.72, 0.72, 0.82, 1},
}
local function button(parent, text, x, y, width, callback)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    control:SetDimensions(width, 30)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetFont('ZoFontGame')
    control:SetMouseEnabled(true)
    control:SetNormalFontColor(unpack(COLORS.text))
    control:SetMouseOverFontColor(1, 1, 1, 1)
    control:SetPressedFontColor(unpack(COLORS.multi))
    local backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetDrawLayer(DL_BACKGROUND)
    backdrop:SetCenterColor(0.10, 0.14, 0.19, 1)
    backdrop:SetEdgeTexture('EsoUI/Art/Miscellaneous/white.dds', 1, 1, 1, 0)
    backdrop:SetEdgeColor(0.25, 0.34, 0.43, 1)
    control.backdrop = backdrop
    control:SetText(M.L(text))
    M:FitLocalizedButton(control)
    control:SetHandler('OnMouseEnter', function()
        backdrop:SetCenterColor(0.16, 0.23, 0.29, 1)
    end)
    control:SetHandler('OnMouseExit', function()
        backdrop:SetCenterColor(0.10, 0.14, 0.19, 1)
    end)
    control:SetHandler('OnClicked', callback)
    M:RegisterGamepadTarget(control,callback,function()
        local description=control.mountSwapDescription
        if type(description)=='function' then return description() end
        return description or control:GetText()
    end)
    return control
end
local function label(parent, text, x, y, width, color)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    control:SetFont('ZoFontGame')
    control:SetDimensions(width, 28)
    control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    control:SetText(M.L(text))
    control:SetColor(unpack(color or COLORS.text))
    M:FitLocalizedButton(control)
    return control
end
local function backdrop(parent, color)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    control:SetAnchorFill(parent)
    control:SetDrawLayer(DL_BACKGROUND)
    control:SetCenterColor(unpack(color or {0.025, 0.035, 0.05, 0.99}))
    control:SetEdgeTexture('EsoUI/Art/Miscellaneous/white.dds', 1, 1, 1, 0)
    control:SetEdgeColor(0.25, 0.34, 0.43, 1)
    return control
end
M.UI={button=button,label=label,backdrop=backdrop}
function M:ClosePicker()
    if not self.picker then return end
    self.pickerSearch:LoseFocus()
    self:SetWindowHidden(self.picker,true)
    self.pickerBlocker:SetHidden(true)
    self.pickerSlot = nil
    self:SyncGamepad()
end
function M:Refresh()
    self:ObserveMountedGroup()
    local slots = self.saved.slots
    for slot, control in ipairs(self.slotButtons or {}) do
        local name = mountInfo(slots[slot])
        local prefix = slot <= 4 and 'M' or 'S'
        local number = slot <= 4 and slot or slot - 4
        control:SetText(prefix .. number .. ': ' .. (name and zo_strformat('<<1>>', name) or M.L('Choose a mount...')))
        self:FitLocalizedButton(control)
        control.backdrop:SetEdgeColor(unpack(self.pickerSlot == slot and COLORS[slot <= 4 and 'multi' or 'single'] or COLORS.muted))
    end
    if self.picker and not self.picker:IsHidden() then self:RefreshPicker(false) end
    self:SyncGamepad()
end
function M:ScrollPicker(offset)
    local maximum = math.max(0, #self.pickerList - 8)
    self.pickerOffset = math.max(0, math.min(math.floor(offset + 0.5), maximum))
    for index, row in ipairs(self.pickerRows) do
        local mount = self.pickerList[self.pickerOffset + index]
        row.mountId = mount and mount.id
        local prefix = ''
        if mount and self.manageMode then
            local group = self:MountGroup(mount.id)
            prefix = M.L(group == 'multi' and '[Multi]' or group == 'single' and '[Single]' or '[Review]') .. ' '
        end
        row:SetText(mount and (prefix .. mount.name) or '')
        self:FitLocalizedButton(row)
        row:SetHidden(not mount)
    end
    self.updatingSlider = true
    self.pickerSlider:SetMinMax(0, math.max(1, maximum))
    self.pickerSlider:SetValue(self.pickerOffset)
    self.updatingSlider = false
    self.pickerSlider:SetHidden(maximum == 0)
    self.pickerTrack:SetHidden(maximum == 0)
    self.pickerEmpty:SetHidden(#self.pickerList > 0)
    self.pickerCount:SetText(M.L(#self.pickerList == 0 and '0 mounts' or
        (self.pickerOffset + 1) .. '-' .. math.min(self.pickerOffset + 8, #self.pickerList) .. ' of ' .. #self.pickerList .. ' mounts'))
    self:FitLocalizedButton(self.pickerCount)
    self:SyncGamepad()
end
function M:RefreshPicker(reset)
    local query = string.lower(self.pickerSearch:GetText() or '')
    self.pickerList = {}
    for _, mount in ipairs(self:Mounts()) do
        if (self.manageMode or self:MountGroup(mount.id) == self.pickerGroup) and
            string.find(string.lower(mount.name), query, 1, true) then
            self.pickerList[#self.pickerList + 1] = mount
        end
    end
    self:ScrollPicker(reset and 0 or (self.pickerOffset or 0))
end
function M:OpenPicker(slot, manage, fromSettings)
    if not self.saved then return end
    if self.saved.standalonePanel == false and not fromSettings then
        local controller = IsInGamepadPreferredMode and IsInGamepadPreferredMode()
        if LibAddonMenu2 or controller then self:Toggle(); return end
        -- Keyboard fallback remains usable without altering the saved OFF preference.
    end
    if not self.window then self:CreateWindow() end
    if not self.picker then self:CreatePicker() end
    self.manageMode = manage == true
    self.pickerSlot = self.manageMode and nil or slot
    self.pickerGroup = slot and (slot <= 4 and 'multi' or 'single') or nil
    self.selectedMountId = nil
    self.pickerTitle:SetText(M.L(self.manageMode and 'Manage mount categories' or
        ('Choose a ' .. (self.pickerGroup == 'multi' and 'Multi-Rider' or 'Single-Rider') .. ' mount')))
    self.pickerTitle:SetColor(unpack(COLORS[self.pickerGroup] or COLORS.review))
    self.pickerSubtitle:SetText(M.L(self.manageMode and 'Select a mount, then choose a category below.' or
        ('For favorite ' .. (slot <= 4 and 'M' .. slot or 'S' .. (slot - 4)) .. ' | Your unlocked mounts | A-Z')))
    self.suppressPickerSearch = true
    self.pickerSearch:SetText('')
    self.suppressPickerSearch = false
    self.pickerHint:SetText(M.L(self.manageMode and 'Category choices apply only when ESO category data is unavailable.' or 'Choose a mount to save it and close this picker.'))
    self:FitLocalizedButton(self.pickerTitle)
    self:FitLocalizedButton(self.pickerSubtitle)
    self:FitLocalizedButton(self.pickerHint)
    self.pickerClear:SetHidden(self.manageMode)
    for _, control in ipairs(self.categoryButtons) do control:SetHidden(not self.manageMode) end
    self.pickerBlocker:SetHidden(false)
    self:SetWindowHidden(self.picker,false)
    self:RefreshPicker(true)
    self:Refresh()
    if self.gamepadLayerActive then self:FocusControl(self.pickerRows[1]) end
end
function M:CreatePicker()
    local w = WINDOW_MANAGER:CreateTopLevelWindow('MountSwapPicker')
    self.picker = w
    w:SetDimensions(650, 590)
    w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    w:SetDrawTier(DT_HIGH)
    w:SetMouseEnabled(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    backdrop(w)
    w:SetHandler('OnHide', function()
        self.pickerSearch:LoseFocus()
        self.pickerBlocker:SetHidden(true)
        self.pickerSlot = nil
    end)
    self.pickerTitle = label(w, '', 24, 20, 540, COLORS.multi)
    self.pickerSubtitle = label(w, '', 24, 56, 600, COLORS.muted)
    self.pickerSubtitle:SetDimensions(600,38)
    button(w, 'X', 586, 16, 40, function() self:ClosePicker(); self:Refresh() end)
    label(w, 'Search:', 24, 100, 104, COLORS.muted)
    local searchBg = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    searchBg:SetDimensions(492, 34)
    searchBg:SetAnchor(TOPLEFT, w, TOPLEFT, 134, 96)
    searchBg:SetCenterColor(0.10, 0.16, 0.22, 1)
    local search = WINDOW_MANAGER:CreateControl(nil, w, CT_EDITBOX)
    self.pickerSearch = search
    search:SetDimensions(500, 30)
    search:SetAnchor(TOPLEFT, searchBg, TOPLEFT, 8, 2)
    search:SetFont('ZoFontEdit')
    search:SetMouseEnabled(true)
    search:SetEditEnabled(true)
    search:SetColor(unpack(COLORS.text))
    search:SetDefaultText(M.L('Type a mount name...'))
    search:SetDefaultTextColor(unpack(COLORS.muted))
    search:SetHandler('OnMouseDown', function(control) control:TakeFocus() end)
    search:SetHandler('OnEnter', function(control) control:LoseFocus() end)
    searchBg:SetMouseEnabled(true)
    searchBg:SetHandler('OnMouseDown', function() search:TakeFocus() end)
    search:SetMaxInputChars(100)
    search:SetHandler('OnTextChanged', function()
        if not self.suppressPickerSearch then self:RefreshPicker(true) end
    end)
    search:SetHandler('OnEscape', function() self:ClosePicker(); self:Refresh() end)
    self:HookTextEntry(search,w,true)
    self:RegisterGamepadTarget(search,function(control) control:TakeFocus() end,function() return 'Search unlocked mounts by name. Leave the field to resume navigation.' end)
    self.pickerCount = label(w, '', 24, 140, 580, COLORS.muted)
    self.pickerEmpty = label(w, 'No matching mounts. Try another search or Manage categories.', 24, 190, 580, COLORS.muted)
    self.pickerEmpty:SetDimensions(580,64)
    local function wheel(_, delta) self:ScrollPicker((self.pickerOffset or 0) - delta * 3) end
    w:SetHandler('OnMouseWheel', wheel)
    self.pickerRows = {}
    for index = 1, 8 do
        local row
        row = button(w, '', 24, 178 + (index - 1) * 36, 566, function()
            local id = row.mountId
            self:Mounts() -- revalidate category membership before committing a selection
            if not mountInfo(id) then
                self:RefreshPicker(false); say('That mount is no longer available.'); return
            end
            self.selectedMountId = id
            if self.manageMode then
                self.pickerHint:SetText(M.L('Selected: ' .. zo_strformat('<<1>>', mountInfo(id))))
                self:FitLocalizedButton(self.pickerHint)
            elseif self.pickerSlot and self:Assign(self.pickerSlot, id) then
                self:NotifyMount(id, slotName(self.pickerSlot) .. ' favorite saved')
                self:ClosePicker(); self:Refresh()
            else self:RefreshPicker(false) end
        end)
        row:SetHandler('OnMouseWheel', wheel)
        self.pickerRows[index] = row
    end
    local track = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    self.pickerTrack = track
    track:SetDimensions(16, 282)
    track:SetAnchor(TOPLEFT, w, TOPLEFT, 608, 178)
    track:SetCenterColor(0.13, 0.19, 0.25, 1)
    local slider = WINDOW_MANAGER:CreateControl(nil, w, CT_SLIDER)
    self.pickerSlider = slider
    slider:SetDimensions(16, 282)
    slider:SetAnchor(TOPLEFT, w, TOPLEFT, 608, 178)
    slider:SetOrientation(ORIENTATION_VERTICAL)
    slider:SetMouseEnabled(true)
    slider:SetEnabled(true)
    slider:SetValueStep(1)
    local texture = 'EsoUI/Art/Miscellaneous/scrollbox_elevator.dds'
    local disabledTexture = 'EsoUI/Art/Miscellaneous/scrollbox_elevator_disabled.dds'
    slider:SetThumbTexture(texture, disabledTexture, texture, 16, 32, 0, 0, 1, 1)
    slider:SetHandler('OnValueChanged', function(_, value)
        if not self.updatingSlider then self:ScrollPicker(value) end
    end)
    slider:SetHandler('OnMouseWheel', wheel)
    self.pickerHint = label(w, '', 24, 476, 602, COLORS.muted)
    self.pickerHint:SetDimensions(602,40)
    self.pickerClear = button(w, 'Clear slot', 24, 538, 150, function()
        if self.pickerSlot then self.saved.slots[self.pickerSlot] = nil end
        self:ClosePicker(); self:Refresh()
    end)
    self.categoryButtons = {
        button(w, 'Multi-Rider', 24, 518, 150, function() self:SetGroup('multi') end),
        button(w, 'Single-Rider', 184, 518, 150, function() self:SetGroup('single') end),
        button(w, 'Automatic', 344, 518, 140, function() self:SetGroup(nil) end),
    }
    button(w, 'Cancel', 506, 538, 120, function() self:ClosePicker(); self:Refresh() end)
    self:ManageWindow(w,650,590)
end
function M:Toggle()
    if not self.saved then return end
    if self.saved.standalonePanel == false then
        if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
            if self.controllerMenu and not self.controllerMenu:IsHidden() then self:CloseWindows() else self:OpenSettings() end
            return
        end
        if LibAddonMenu2 then self:OpenSettings(); return end
        self:Chat('Settings library unavailable; opening a temporary dashboard. Your dashboard OFF preference is preserved.', true)
    end
    if not self.window then self:CreateWindow() end
    if self.window:IsHidden() then self:Refresh(); self:SetWindowHidden(self.window,false)
    else self:CloseWindows() end
end
function M:CreateWindow()
    local w = WINDOW_MANAGER:CreateTopLevelWindow('MountSwapWindow')
    self.window = w
    w:SetDimensions(1020, 380)
    w:SetAnchor(TOP, GuiRoot, TOP, 0, 160)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    backdrop(w)
    w:SetHandler('OnHide', function()
        self:ClosePicker()
        if not self.keepControllerMenu then
            if self.controllerMenu then self:SetWindowHidden(self.controllerMenu,true); self.menuState=nil; self.menuStack={} end
            if self.textWindow then self.cancelText=true; self:SetWindowHidden(self.textWindow,true) end
        end
    end)
    label(w, 'MountSwap — Your Stable', 20, 16, 700)
    button(w, 'Keybindings', 740, 12, 150, function() self:OpenKeybindings() end)
    button(w, 'Close', 900, 12, 100, function() self:CloseWindows() end)
    label(w, 'Click a favorite slot to choose a mount. Set your own keys in Controls.', 20, 49, 980, COLORS.muted)
    label(w, 'MULTI-RIDER FAVORITES', 20, 82, 480, COLORS.multi)
    label(w, 'SINGLE-RIDER FAVORITES', 520, 82, 480, COLORS.single)
    self.slotButtons, self.useButtons = {}, {}
    for slot = 1, 8 do
        local s = slot
        local x = s <= 4 and 20 or 520
        local row = s <= 4 and s or s - 4
        local y = 112 + (row - 1) * 36
        self.slotButtons[s] = button(w, '', x, y, 390, function(control) self:OpenPicker(control.slotIndex) end)
        self.slotButtons[s].slotIndex = s
        self.useButtons[s] = button(w, 'Use', x + 400, y, 80, function(control) self:Slot(control.slotIndex) end)
        self.useButtons[s].slotIndex = s
    end
    label(w, 'Choose a mount in the picker to save it. Use selects your saved mount.', 20, 270, 980, COLORS.muted)
    button(w, 'Settings', 750, 270, 250, function() self:OpenSettings() end)
    button(w, 'Manage mount categories', 20, 326, 280, function() self:OpenPicker(nil, true) end)
    button(w, 'Use nearest multi-rider mount', 320, 326, 410, function() self:NearestPassenger() end)
    button(w, 'Random mount', 750, 326, 250, function() self:Random() end)
    local blocker = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    self.pickerBlocker = blocker
    blocker:SetAnchorFill(w)
    blocker:SetCenterColor(0, 0, 0, 0.65)
    blocker:SetDrawLayer(DL_OVERLAY)
    blocker:SetMouseEnabled(true)
    blocker:SetHidden(true)
    self:ManageWindow(w,1020,380)
end
local function loaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    local defaults = { slots = {}, groups = {}, observedGroups = {}, chatMessages = true, standalonePanel = true }
    -- ESO's default profile is shared across worlds unless a profile is explicit.
    local legacy = ZO_SavedVars:NewAccountWide('MountSwapSavedVariables', 1, nil, defaults)
    M.saved = ZO_SavedVars:NewAccountWide('MountSwapSavedVariables', 1, nil, defaults, GetWorldName())
    if not M.saved.worldProfileInitialized then
        -- Retain the earlier prototype's choices when those mounts are unlocked here.
        for _, key in ipairs({'slots', 'groups', 'observedGroups', 'legacySlots'}) do
            if type(legacy[key]) == 'table' then
                if type(M.saved[key]) ~= 'table' then M.saved[key] = {} end
                for id, value in pairs(legacy[key]) do
                    if M.saved[key][id] == nil and
                        ((key ~= 'slots' and key ~= 'legacySlots') or mountInfo(value)) then
                        M.saved[key][id] = value
                    end
                end
            end
        end
        if M.saved.favoriteLayout == nil then M.saved.favoriteLayout = legacy.favoriteLayout end
        M.saved.worldProfileInitialized = true
    end
    if type(M.saved.slots) ~= 'table' then M.saved.slots = {} end
    if type(M.saved.groups) ~= 'table' then M.saved.groups = {} end
    if type(M.saved.observedGroups) ~= 'table' then M.saved.observedGroups = {} end
    if M.saved.favoriteLayout ~= 2 then
        local previous = M.saved.slots
        M.saved.legacySlots = previous
        M.saved.slots = {}
        local positions = {multi = 1, single = 5}
        for oldSlot = 1, 4 do
            local id = previous[oldSlot]
            if mountInfo(id) then
                local group = M:MountGroup(id)
                local target = positions[group]
                if target then
                    M.saved.slots[target] = id
                    positions[group] = target + 1
                end
            end
        end
        M.saved.favoriteLayout = 2
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_MOUNTED_STATE_CHANGED, function(_, mounted)
        if mounted then
            M:ConfirmPassenger()
            M:ObserveMountedGroup()
            if M.window and not M.window:IsHidden() then M:Refresh() end
        end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME .. 'Activation', EVENT_ACTIVE_MOUNT_CHANGED, function() M:ConfirmMountChange() end)
    SLASH_COMMANDS['/mountswap'] = function(argument)
        if argument == 'debug' then M:Debug(); return end
        if argument == 'settings' then M:OpenSettings(); return end
        if argument == 'chat off' then M.saved.chatMessages = false; return end
        if argument == 'chat on' then M.saved.chatMessages = true; say('Chat messages enabled.'); return end
        local slot = (argument or ''):match('^save%s+([1-8])$')
        if slot then M:Save(tonumber(slot)) else M:Toggle() end
    end
    for slot = 1, 8 do
        local s = slot
        SLASH_COMMANDS['/mountswap' .. s] = function() M:Slot(s) end
    end
    SLASH_COMMANDS['/mountswapr'] = function() M:Random() end
    SLASH_COMMANDS['/mountswapnear'] = function() M:NearestPassenger() end
    M:InitializeLanguage()
    M:InitializeCommands()
    M:InitializeNavigation()
    -- Check again after all addons load; do not reclaim a shortcut taken by a later addon.
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(NAME .. 'Commands', EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(NAME .. 'Commands', EVENT_PLAYER_ACTIVATED)
            M:ApplyCommands()
            if next(M.commandErrors) then M:Chat(M:CommandStatus(), true) end
        end)
    end
    M:InitializeSettings()
end
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, loaded)
M.bindingTexts={MOUNTSWAP_MENU='Open mount selector',MOUNTSWAP_GAMEPAD_MENU='Open MountSwap (controller)',
    MOUNTSWAP_RANDOM='Select random mount',MOUNTSWAP_PASSENGER='Use nearest multi-rider mount'}
for slot=1,8 do
    M.bindingTexts['MOUNTSWAP_SLOT'..slot]='Select '..(slot<=4 and 'Multi-Rider' or 'Single-Rider')..' favorite '..(slot<=4 and slot or slot-4)
end
for action,text in pairs(M.bindingTexts) do ZO_CreateStringId('SI_BINDING_NAME_'..action,text) end
