-- This file is part of CyrHUD
--
-- (C) 2015 Scott Yeskie (Sasky)
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- Setup class
CyrHUD = CyrHUD or {}

CyrHUD.Label = {}
CyrHUD.Label.__index = CyrHUD.Label

setmetatable(CyrHUD.Label, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

local Label = CyrHUD.Label

function Label.new()
    local self = setmetatable({}, CyrHUD.Label)

    self.labelType = "uninit"
    self.num = (Label.entryCount or 0) + 1
    self.entryName = "CyrHUDEntry"..self.num
    Label.entryCount = self.num
    self.entry = {}

    local entry = self.entry

    --Main control/backdrop
    self.main = WINDOW_MANAGER:CreateControl(self.entryName .. "main", CyrHUD_UI, CT_BACKDROP)
    self.main:SetDimensions(CyrHUD.width, 35)
    self.main:SetAnchor(TOPLEFT, CyrHUD_UI, TOPLEFT, 0, self.num*35-5)
    self.main:SetCenterColor(CyrHUD.info.defaultBGColor:UnpackRGBA())
    self.main:SetEdgeColor(CyrHUD.info.invisColor:UnpackRGBA())

    -- Images
    entry.img1 = WINDOW_MANAGER:CreateControl(self.entryName .. "img1", self.main, CT_TEXTURE)
    entry.img2 = WINDOW_MANAGER:CreateControl(self.entryName .. "img2", self.main, CT_TEXTURE)
    entry.img3 = WINDOW_MANAGER:CreateControl(self.entryName .. "img3", self.main, CT_TEXTURE)
	entry.img4 = WINDOW_MANAGER:CreateControl(self.entryName .. "img4", self.main, CT_TEXTURE)
	
	entry.img5 = WINDOW_MANAGER:CreateControl(self.entryName .. "img5", self.main, CT_TEXTURE)
	entry.img6 = WINDOW_MANAGER:CreateControl(self.entryName .. "img6", self.main, CT_TEXTURE)
	entry.img7 = WINDOW_MANAGER:CreateControl(self.entryName .. "img7", self.main, CT_TEXTURE)
	
	entry.img8 = WINDOW_MANAGER:CreateControl(self.entryName .. "img8", self.main, CT_TEXTURE)
	
	entry.img9 = WINDOW_MANAGER:CreateControl(self.entryName .. "img9", self.main, CT_TEXTURE)
	entry.img10 = WINDOW_MANAGER:CreateControl(self.entryName .. "img10", self.main, CT_TEXTURE)
	entry.img11 = WINDOW_MANAGER:CreateControl(self.entryName .. "img11", self.main, CT_TEXTURE)
	
	entry.img12 = WINDOW_MANAGER:CreateControl(self.entryName .. "img12", self.main, CT_TEXTURE)
	entry.img13 = WINDOW_MANAGER:CreateControl(self.entryName .. "img13", self.main, CT_TEXTURE)
	entry.img14 = WINDOW_MANAGER:CreateControl(self.entryName .. "img14", self.main, CT_TEXTURE)
	
	entry.img15 = WINDOW_MANAGER:CreateControl(self.entryName .. "img15", self.main, CT_TEXTURE)
	entry.img16 = WINDOW_MANAGER:CreateControl(self.entryName .. "img16", self.main, CT_TEXTURE)
	
	entry.img17 = WINDOW_MANAGER:CreateControl(self.entryName .. "img17", self.main, CT_TEXTURE)
	
	entry.img18 = WINDOW_MANAGER:CreateControl(self.entryName .. "img18", self.main, CT_TEXTURE)
	
	entry.img19 = WINDOW_MANAGER:CreateControl(self.entryName .. "img19", self.main, CT_TEXTURE)
	entry.img20 = WINDOW_MANAGER:CreateControl(self.entryName .. "img20", self.main, CT_TEXTURE)
	entry.img21 = WINDOW_MANAGER:CreateControl(self.entryName .. "img21", self.main, CT_TEXTURE)
	
	entry.img22 = WINDOW_MANAGER:CreateControl(self.entryName .. "img22", self.main, CT_TEXTURE)
	entry.img23 = WINDOW_MANAGER:CreateControl(self.entryName .. "img23", self.main, CT_TEXTURE)
	entry.img24 = WINDOW_MANAGER:CreateControl(self.entryName .. "img24", self.main, CT_TEXTURE)
	
	entry.img25 = WINDOW_MANAGER:CreateControl(self.entryName .. "img25", self.main, CT_TEXTURE)
	
	entry.img26 = WINDOW_MANAGER:CreateControl(self.entryName .. "img26", self.main, CT_TEXTURE)
	entry.img27 = WINDOW_MANAGER:CreateControl(self.entryName .. "img27", self.main, CT_TEXTURE)
	entry.img28 = WINDOW_MANAGER:CreateControl(self.entryName .. "img28", self.main, CT_TEXTURE)
	entry.img29 = WINDOW_MANAGER:CreateControl(self.entryName .. "img29", self.main, CT_TEXTURE)
	entry.img30 = WINDOW_MANAGER:CreateControl(self.entryName .. "img30", self.main, CT_TEXTURE)
	entry.img31 = WINDOW_MANAGER:CreateControl(self.entryName .. "img31", self.main, CT_TEXTURE)
	
	entry.img32 = WINDOW_MANAGER:CreateControl(self.entryName .. "img32", self.main, CT_TEXTURE)
	entry.img33 = WINDOW_MANAGER:CreateControl(self.entryName .. "img33", self.main, CT_TEXTURE)
	entry.img34 = WINDOW_MANAGER:CreateControl(self.entryName .. "img34", self.main, CT_TEXTURE)
	entry.img35 = WINDOW_MANAGER:CreateControl(self.entryName .. "img35", self.main, CT_TEXTURE)
	entry.img36 = WINDOW_MANAGER:CreateControl(self.entryName .. "img36", self.main, CT_TEXTURE)
	entry.img37 = WINDOW_MANAGER:CreateControl(self.entryName .. "img37", self.main, CT_TEXTURE)


    --Labels
    entry.txt1 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt1", self.main, CT_LABEL)
    entry.txt2 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt2", self.main, CT_LABEL)
    entry.txt3 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt3", self.main, CT_LABEL)
    entry.txt4 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt4", self.main, CT_LABEL)
	
	entry.txt5 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt5", self.main, CT_LABEL)
    entry.txt6 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt6", self.main, CT_LABEL)
    entry.txt7 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt7", self.main, CT_LABEL)
	
	entry.txt8 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt8", self.main, CT_LABEL)
    entry.txt9 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt9", self.main, CT_LABEL)
    entry.txt10 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt10", self.main, CT_LABEL)
	
	entry.txt11 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt11", self.main, CT_LABEL)
    entry.txt12 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt12", self.main, CT_LABEL)
    entry.txt13 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt13", self.main, CT_LABEL)
	
	entry.txt14 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt14", self.main, CT_LABEL)
	entry.txt15 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt15", self.main, CT_LABEL)
	
	entry.txt16 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt16", self.main, CT_LABEL)
	
	entry.txt17 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt17", self.main, CT_LABEL)
	entry.txt18 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt18", self.main, CT_LABEL)
	entry.txt19 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt19", self.main, CT_LABEL)
	entry.txt20 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt20", self.main, CT_LABEL)
	entry.txt21 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt21", self.main, CT_LABEL)
	entry.txt22 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt22", self.main, CT_LABEL)
	
	entry.txt23 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt23", self.main, CT_LABEL)
	entry.txt24 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt24", self.main, CT_LABEL)
	entry.txt25 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt25", self.main, CT_LABEL)
	entry.txt26 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt26", self.main, CT_LABEL)
	entry.txt27 = WINDOW_MANAGER:CreateControl(self.entryName .. "txt27", self.main, CT_LABEL)
	

    entry.txt1:SetFont(CyrHUD.info.fontMain)
    entry.txt2:SetFont(CyrHUD.info.fontMain)
    entry.txt3:SetFont(CyrHUD.info.fontMain)
    entry.txt4:SetFont(CyrHUD.info.fontMain)
    entry.txt5:SetFont(CyrHUD.info.fontSmall)
    entry.txt6:SetFont(CyrHUD.info.fontSmall)
    entry.txt7:SetFont(CyrHUD.info.fontSmall)
    entry.txt8:SetFont(CyrHUD.info.fontSmall)
    entry.txt9:SetFont(CyrHUD.info.fontSmall)
    entry.txt10:SetFont(CyrHUD.info.fontSmall)
	entry.txt11:SetFont(CyrHUD.info.fontSmall)
    entry.txt12:SetFont(CyrHUD.info.fontSmall)
    entry.txt13:SetFont(CyrHUD.info.fontSmall)
    entry.txt14:SetFont(CyrHUD.info.fontSmall)
    entry.txt15:SetFont(CyrHUD.info.fontSmall)	
	entry.txt16:SetFont(CyrHUD.info.fontSmall)
	entry.txt17:SetFont(CyrHUD.info.fontMain)
	entry.txt18:SetFont(CyrHUD.info.fontMain)
	entry.txt19:SetFont(CyrHUD.info.fontMain)
	entry.txt20:SetFont(CyrHUD.info.fontMain)
	entry.txt21:SetFont(CyrHUD.info.fontMain)
	entry.txt22:SetFont(CyrHUD.info.fontMain)
	entry.txt23:SetFont(CyrHUD.info.fontSmall)
    entry.txt24:SetFont(CyrHUD.info.fontSmall)
    entry.txt25:SetFont(CyrHUD.info.fontSmall)
    entry.txt26:SetFont(CyrHUD.info.fontSmall)
    entry.txt27:SetFont(CyrHUD.info.fontSmall)

    return self
end

function Label:hide()
    self.main:SetHidden(true)
end

function Label:show()
    self.main:SetHidden(false)
end

function Label:getControl(name)
    return self.entry[name]
end

function Label:moveControl(name, x, y)
    if self.entry[name] then
        self.entry[name]:ClearAnchors()
        self.entry[name]:SetAnchor(TOPLEFT, self.entry.main, TOPLEFT, x, y)
    end
end

function Label:resizeControl(name, width, height)
    if self.entry[name] then
        self.entry[name]:SetDimensions(width, height)
    end
end

function Label:positionControl(name, width, height, x, y)
    if self.entry[name] then
        self.entry[name]:ClearAnchors()
        self.entry[name]:SetAnchor(TOPLEFT, self.entry.main, TOPLEFT, x, y)
        self.entry[name]:SetDimensions(width, height)
    end
end

function Label:exposeControls(nImg, nText)
    for i=1,4 do
        self.entry["img"..i]:SetHidden(i > nImg)
    end

    for i=1,4 do
        self.entry["txt"..i]:SetHidden(i > nText)
    end
end

function Label:update(model)

    if self.type ~= model.type then
        --TODO: Handle some form of reset
        model:configureLabel(self)
        self.type = model.type
        self:show()
    end


    model:updateLabel(self)
end
