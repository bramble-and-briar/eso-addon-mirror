local LeoAltholic = LeoAltholic
function LeoAltholic.UI.InitTrackedPanel()
    local charList = LeoAltholic.ExportCharacters()
    local control
    local anchorY = 112;
    control = WINDOW_MANAGER:GetControlByName('LeoAltholicWindowTrackedPanelScrollChild')
    control:SetHeight(#charList * anchorY)

    local numRows = 1

    for x,char in pairs(charList) do

        if char.quests ~= nil and char.quests.tracked ~= nil then
            local count = 0
            for i = 1, 10 do
                if char.quests.tracked[i] ~= nil then
                    count = count + 1
                end
            end
            if count > 0 then
                local bg
                local row
                local sc = WINDOW_MANAGER:GetControlByName("LeoAltholicWindowTrackedPanelScrollChild")
                row = CreateControlFromVirtual("LeoAltholicTrackedRow" .. numRows, sc, "LeoAltholicTrackedRowTemplate")
                row:SetHidden(false)

                row:SetAnchor(TOPLEFT,sc,TOPLEFT,0,(numRows - 1) * anchorY)
                bg = row:GetNamedChild("BG")
                if char.bio.name == LeoAltholic.CharName then
                    bg:SetCenterColor(unpack({0.1,0.1,0.1,1 }))
                    bg:SetEdgeColor(0.2,0.7,0.2,1)
                end

                control = row:GetNamedChild("Name")
                control:SetText(char.bio.name)

                control = row:GetNamedChild("Alliance")
                local icon = ZO_GetAllianceIcon(char.bio.alliance.id)
                control:SetText("|cF1FF77|t50:90:" .. icon .. "|t|r ")
                control.data = char.bio.alliance.name

                control = row:GetNamedChild("RaceClass")
                control:SetText(char.bio.race .. " " .. char.bio.class)

                row = WINDOW_MANAGER:GetControlByName('LeoAltholicTrackedRow'..numRows)
                local index = 1
                for i = 1, 10 do
                    if char.quests.tracked[i] ~= nil then
                        local label = row:GetNamedChild("Quest" .. index .. "Label")
                        local done = row:GetNamedChild("Quest" .. index .. "Done")
                        label:SetText(char.quests.tracked[i].name)
                        label:SetHandler('OnMouseUp', function(control, button, upInside)
                            if upInside == true and button == MOUSE_BUTTON_INDEX_RIGHT then
                                LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_REMOVED_FROM), label:GetText(), char.bio.name))
                                table.remove(LeoAltholic.globalData.CharList[char.bio.name].quests.tracked, i)
                                control:SetHidden(true)
                                control:GetParent():GetNamedChild("Quest" .. index .. "Done"):SetHidden(true)
                            end
                        end)
                        if char.quests.tracked[i].lastDone ~= nil then
                            if LeoAltholic.IsBeforeReset(char.quests.tracked[i].lastDone) then
                                done:SetText("|cCB110E"..GetString(LEOALT_NOT_DONE_TODAY).."|r")
                            else
                                local diff = GetTimeStamp() - char.quests.tracked[i].lastDone
                                if diff < 3600 then
                                    done:SetText(ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_MINUTES_DESC), math.floor(diff / 60))))
                                elseif diff < 86400 then
                                    done:SetText(ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_HOURS_DESC), math.floor(diff / 3600))))
                                else
                                    done:SetText(ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_DAYS_DESC), math.floor(diff / 86400))))
                                end
                            end
                        else
                            done:SetText("|cCB110E"..GetString(LEOALT_NOT_DONE_TODAY).."|r")
                        end
                        index = index + 1
                    end
                end
                numRows = numRows + 1
            end
        end
    end
end
