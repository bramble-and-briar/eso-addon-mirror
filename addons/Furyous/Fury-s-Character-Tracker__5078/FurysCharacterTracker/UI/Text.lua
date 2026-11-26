-- The text window, used two ways:
--   text to copy: the board for Discord, one character for Discord. Addons can't write to the
--     clipboard, so the text opens selected and you press Ctrl+C.
--   a note: the note you keep on a character, with Save and Clear.
local CT = FurysCharacterTracker
local Window = {}
CT.TextWindow = Window

local MAX_COPY_CHARS = 12000
local MAX_NOTE_CHARS = 300

local function Box() return FurysCharacterTracker_TextEditBox end

function Window:Build()
    if self.built then return end
    self.built = true
    SCENE_MANAGER:RegisterTopLevel(FurysCharacterTracker_Text, false)
    -- Without these the edit box drops line breaks and everything runs together.
    Box():SetMultiLine(true)
    Box():SetNewLineEnabled(true)
    local parent, Button = FurysCharacterTracker_TextButtons, CT.Window.Button
    self.selectAll = Button("FurysCharacterTracker_TextSelect", parent, "Select all", 150,
                            "Selects all the text. Then press Ctrl+C to copy it.", function() self:Select() end)
    self.selectAll:SetAnchor(RIGHT, parent, RIGHT, 0, 0)
    self.save = Button("FurysCharacterTracker_TextSave", parent, "Save note", 150, "Saves the note and closes this window.", function() self:SaveNote() end)
    self.save:SetAnchor(RIGHT, parent, RIGHT, 0, 0)
    self.clear = Button("FurysCharacterTracker_TextClear", parent, "Clear note", 150, "Removes this character's note.", function()
        Box():SetText("")
        self:SaveNote()
    end)
    self.clear:SetAnchor(RIGHT, self.save, LEFT, -8, 0)
end

-- Pop-ups draw on the high tier, and each one shown goes above the one before.
local popupLevel = 0
local function ShowOnTop(control)
    if control:IsHidden() then SCENE_MANAGER:ShowTopLevel(control) end
    popupLevel = popupLevel + 1
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLevel(popupLevel)
end

function Window:Open(title, hint, text, maxChars, isNote)
    self:Build()
    self.noteFor = nil
    FurysCharacterTracker_TextTitle:SetText(title)
    FurysCharacterTracker_TextHint:SetText(hint)
    Box():SetMaxInputChars(maxChars)
    Box():SetText(text)
    self.selectAll:SetHidden(isNote)
    self.save:SetHidden(not isNote)
    self.clear:SetHidden(not isNote)
    ShowOnTop(FurysCharacterTracker_Text)
    Box():TakeFocus()
end

function Window:Select()
    Box():TakeFocus()
    Box():SelectAll()
end

-- `text` to copy, with `note` as the line above it.
function Window:ShowCopy(text, note)
    self:Open("Copy for Discord", note or "Press Ctrl+C to copy, then paste.", text, MAX_COPY_CHARS, false)
    Box():SelectAll()
end

function Window:ShowNote(id)
    local e = CT.Roster:Entry(id)
    if not e then return end
    self:Open("Note for " .. e.name, string.format("Anything you want to remember about this character, up to %d letters. It shows on the Roles & gear tab and when you hover the name.", MAX_NOTE_CHARS),
              e.m.note or "", MAX_NOTE_CHARS, true)
    self.noteFor = id
end

function Window:SaveNote()
    if self.noteFor then
        -- One line: a note sits in one cell of the board.
        local note = zo_strtrim((Box():GetText():gsub("%s+", " ")))
        CT.Roster:SetManual(self.noteFor, "note", note)
        CT.Refresh()
    end
    self:Hide()
end

function Window:Hide()
    Box():LoseFocus()
    SCENE_MANAGER:HideTopLevel(FurysCharacterTracker_Text)
end
