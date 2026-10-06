--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local STATUS_ICON_TEXTURE = "EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds"
local STATUS_ICON_SIZE = 16
local STATUS_ICON_GAP = 2
local STATUS_ICON_SLOTS = 7
local STATUS_ICON_FOCUS_SCALE = 1.4

local function SetStatusIconGlow(icon, glowing)
	local c = icon.libaph_base_color
	if not c then return end
	if glowing then
		icon.icon_texture:SetColor(math.min(1, c[1] + 0.35), math.min(1, c[2] + 0.35), math.min(1, c[3] + 0.35), 1)
	else
		icon.icon_texture:SetColor(c[1], c[2], c[3], 1)
	end
end

function LibAPH.SetStatusIconFocused(icon, focused, focusScale)
	SetStatusIconGlow(icon, focused)
	icon:SetScale(focused and (focusScale or STATUS_ICON_FOCUS_SCALE) or 1)
end

local function OnStatusIconMouseEnter(icon)
	ClearTooltip(ItemTooltip)
	SetStatusIconGlow(icon, true)
	if icon.libaph_tooltip_text then
		InitializeTooltip(InformationTooltip, icon, BOTTOM, 0, -2)
		SetTooltipText(InformationTooltip, icon.libaph_tooltip_text)
	end
end

local function OnStatusIconMouseExit(icon)
	SetStatusIconGlow(icon, false)
	ClearTooltip(InformationTooltip)
end

local function OnStatusIconClicked(icon, button)
	if button == MOUSE_BUTTON_INDEX_RIGHT then
		if icon.libaph_on_right_click then icon.libaph_on_right_click(icon) end
	elseif icon.libaph_on_click then
		icon.libaph_on_click(icon)
	end
end

function LibAPH.CreateStatusIconStrip(parentControl, selfHandled, slots, size)
	local icons = {}
	size = size or STATUS_ICON_SIZE
	for i = 1, slots or STATUS_ICON_SLOTS do
		local hitbox = WINDOW_MANAGER:CreateControl(nil, parentControl, CT_BUTTON)
		hitbox:SetDimensions(size, size)
		hitbox:SetMouseEnabled(true)
		hitbox:SetDrawLayer(DL_CONTROLS)
		hitbox:SetDrawLevel(5)
		hitbox:SetHidden(true)

		local texture = WINDOW_MANAGER:CreateControl(nil, hitbox, CT_TEXTURE)
		texture:SetTexture(STATUS_ICON_TEXTURE)
		hitbox.libaph_texture = STATUS_ICON_TEXTURE
		texture:SetAnchorFill(hitbox)
		texture:SetMouseEnabled(false)
		hitbox.icon_texture = texture

		if selfHandled then
			hitbox:SetHandler("OnMouseEnter", OnStatusIconMouseEnter)
			hitbox:SetHandler("OnMouseExit", OnStatusIconMouseExit)
			hitbox:EnableMouseButton(MOUSE_BUTTON_INDEX_RIGHT, true)
			hitbox:SetHandler("OnClicked", OnStatusIconClicked)
		end

		icons[i] = hitbox
	end
	return icons
end

function LibAPH.UpdateStatusIconStrip(icons, anchorControl, statusIcons, growLeftward, offsetX, relativePoint)
	offsetX = offsetX or 0
	for slot = 1, #icons do
		local entry = statusIcons[slot]
		local icon = icons[slot]
		if not entry then
			icon:SetHidden(true)
		else
			local texture = entry.texture or STATUS_ICON_TEXTURE
			if icon.libaph_texture ~= texture then
				icon.libaph_texture = texture
				icon.icon_texture:SetTexture(texture)
			end
			icon.libaph_base_color = entry.color
			icon.icon_texture:SetColor(entry.color[1], entry.color[2], entry.color[3], 1)
			icon.libaph_tooltip_text = entry.tooltip
			icon.libaph_on_click = entry.onClick
			icon.libaph_on_right_click = entry.onRightClick
			icon:ClearAnchors()
			if growLeftward then
				if slot == 1 then
					icon:SetAnchor(RIGHT, anchorControl, relativePoint or RIGHT, offsetX, 0)
				else
					icon:SetAnchor(RIGHT, icons[slot - 1], LEFT, -STATUS_ICON_GAP, 0)
				end
			else
				if slot == 1 then
					icon:SetAnchor(LEFT, anchorControl, relativePoint or LEFT, offsetX, 0)
				else
					icon:SetAnchor(LEFT, icons[slot - 1], RIGHT, STATUS_ICON_GAP, 0)
				end
			end
			icon:SetHidden(false)
		end
	end
end
