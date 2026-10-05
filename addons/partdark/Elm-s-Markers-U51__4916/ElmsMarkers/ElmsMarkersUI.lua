ElmsMarkers = ElmsMarkers or { }
ElmsMarkers.UI = { }
local ui = ElmsMarkers.UI

function ElmsMarkers.setupUI()
  local markerEntries = { }
  ui.frame = ElmsMarkers_Frame
  ui.subtitle = ElmsMarkers_Frame_Title_Subtitle
  ui.close = ElmsMarkers_Frame_Title_Close
  ui.placeButton = ElmsMarkers_Frame_Button_Group_Place_Button
  ui.placePublishButton = ElmsMarkers_Frame_Button_Group_Place_Publish_Button
  ui.removePublishButton = ElmsMarkers_Frame_Button_Group_Remove_Publish_Button
  ui.removeButton = ElmsMarkers_Frame_Button_Group_Remove_Button
  ui.shareZoneButton = ElmsMarkers_Frame_Button_Group_Share_Zone_Button
  ui.markerIcon = ElmsMarkers_Frame_Marker_Dropdown_Panel_Marker_Icon
  ui.announcementBanner = ElmsMarkers_Announcement
  ui.announcementBannerLabel = ElmsMarkers_Announcement_Label

  ui.close:SetHandler("OnMouseUp", function() ui.frame:SetHidden(true) end, "ElmsMarkers")

  ui.announcementBannerLabel:SetText("[Elms Markers] REGROUP!")
  ui.announcementBannerLabel:SetColor(1,1,1)
  ui.announcementBannerLabel:SetScale(ElmsMarkers.savedVars.announcementScale)
  ui.announcementBanner:SetHidden(true)

  ui.markerDropdown = ZO_ComboBox_ObjectFromContainer(ElmsMarkers_Frame_Marker_Dropdown_Panel_Marker_Dropdown)
  ui.markerDropdown:SetSortsItems(false)
  ui.markerIcon:SetTexture(ElmsMarkers.iconData[ElmsMarkers.savedVars.selectedIconTexture])

  for k, v in pairs(ElmsMarkers.reverseOptionMap) do
    local entry = ui.markerDropdown:CreateItemEntry(v, function() 
      ElmsMarkers.savedVars.selectedIconTexture = k
      ui.markerIcon:SetTexture(ElmsMarkers.iconData[k])
    end)
		table.insert(markerEntries, entry)
  end

  for k,v in pairs(markerEntries) do
    ui.markerDropdown:AddItem(v)
  end

  ui.markerDropdown:SetSelectedItemText(ElmsMarkers.reverseOptionMap[ElmsMarkers.savedVars.selectedIconTexture])

  ui.placeButton:SetHandler("OnMouseUp", ElmsMarkers.PlaceAtMe, "ElmsMarkers")
  ui.removeButton:SetHandler("OnMouseUp", ElmsMarkers.RemoveNearMe, "ElmsMarkers")
  ui.placePublishButton:SetHandler("OnMouseUp", function() ElmsMarkers.PreparePublish(true) end, "ElmsMarkers")
  ui.removePublishButton:SetHandler("OnMouseUp", function() ElmsMarkers.PreparePublish(false) end, "ElmsMarkers")
  ui.shareZoneButton:SetHandler("OnMouseUp", function() ElmsMarkers.ShareZoneMarkers() end, "ElmsMarkers")
  ElmsMarkers.CheckGroupLead()
end

function ElmsMarkers.SaveAnnouncementPosition()
  ElmsMarkers.savedVars.announcementOffsetX = ElmsMarkers.UI.announcementBanner:GetLeft()
  ElmsMarkers.savedVars.announcementOffsetY = ElmsMarkers.UI.announcementBanner:GetTop()
end

function ElmsMarkers.SetAnnouncementPosition()
	local x, y = ElmsMarkers.savedVars.announcementOffsetX, ElmsMarkers.savedVars.announcementOffsetY
	ElmsMarkers.UI.announcementBanner:ClearAnchors()
	ElmsMarkers.UI.announcementBanner:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function ElmsMarkers.SaveFramePosition()
  ElmsMarkers.savedVars.frameOffsetX = ElmsMarkers.UI.frame:GetLeft()
  ElmsMarkers.savedVars.frameOffsetY = ElmsMarkers.UI.frame:GetTop()
end

function ElmsMarkers.SetFramePosition()
	local x, y = ElmsMarkers.savedVars.frameOffsetX, ElmsMarkers.savedVars.frameOffsetY
	ElmsMarkers.UI.frame:ClearAnchors()
	ElmsMarkers.UI.frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function ElmsMarkers.UnlockUI(unlock)
  ElmsMarkers.savedVars.locked = not unlock
  ElmsMarkers.HideAllUI(not unlock)
  ElmsMarkers.UI.announcementBanner:SetMouseEnabled(unlock)
  ElmsMarkers.UI.announcementBanner:SetMovable(unlock)
end

function ElmsMarkers.HideAllUI(hide)
  ElmsMarkers.UI.announcementBanner:SetHidden(hide)
end

function ElmsMarkers.SetScale(element, value)
  element:SetScale(value)
end