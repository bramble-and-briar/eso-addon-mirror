local SDC = SimpleDailyCraft

--Turn info to string
function SDC.DD(Type, Info) 
  local Table = {}
----------------------------------
--Dault error
  if Type == 0 then
    Table[1] = GetString(SI_GUILDPROCESSAPPLICATIONRESPONSE3)
  end
--Smith Material left: ItemLink, TotalCount
  if Type == 1 then 
    if Info[2] < SDC.SV.DD_SmithMaterialLeft then --Limit number set by player
      Table[1] = zo_strformat(GetString(SI_SCREEN_NARRATION_TIMER_BAR_DESCENDING_FORMATTER), Info[1]).." x "..Info[2]
    end
  end
  if Type == 1.1 then --Special for style material
    if Info[2] < 10 then --Less then 10
      Table[1] = zo_strformat(GetString(SI_SCREEN_NARRATION_TIMER_BAR_DESCENDING_FORMATTER), Info[1]).." x "..Info[2]
    end
  end
  if Type == 1.2 then --Special for bank item
    if Info[2] < 3 then --Less then 3
      Table[1] = zo_strformat(GetString(SI_SCREEN_NARRATION_TIMER_BAR_DESCENDING_FORMATTER), Info[1]).." x "..Info[2]
    end
  end
--Warning_NO_Master_Skill: Name
  if Type == 2 then 
    Table[1] = GetString(SI_ABILITYPROGRESSIONRESULT1).." -> "..Info[1]
  end
--Warning_NO_Material: ItemLink
  if Type == 3 then
    Table[1] = GetString(SI_TRADESKILLRESULT141).." -> "..Info[1]
  end
  if Type == 3.1 and SDC.SV.DD_Bank then --Special for bank item
    Table[1] = GetString(SI_CRAFTING_MISSING_ITEMS).." -> "..Info[1]
  end
--Warning_Hakeijo: ItemLink
  if Type == 4 then
    Table[1] = GetString(SI_GAMEPAD_MARKET_LOCKED_TITLE).." -> "..Info[1]
  end
--Warning_Alchemy_No_Combo: {{ItemLink, Cause} x 2/3, ["Cost"] = Num}
  if Type == 5 then
    Table[1] = GetString(SI_TRADESKILLRESULT14)
    Table[2] = GetString(SI_TRADING_HOUSE_POSTING_PRICE_TOTAL)..(Info["Cost"] or "/")
    Table[3] = Info[1][1].."  "..Info[1][2]
    Table[4] = Info[2][1].."  "..Info[2][2]
    if Info[3] then 
    Table[5] = Info[3][1].."  "..Info[3][2]
    end
  end
--Alchemy Cost
  if Type == 6 and SDC.SV.DD_AlchemyCost then --IsOn?
    Table[1] = GetString(SI_TRADESKILLTYPE4).." -> "..zo_strformat(GetString(SI_MONEY_FORMAT), Info[1])
  end
--Warning_Craft_Fail: Num
  if Type == 7 then
    Table[1] = GetString("SI_TRADESKILLRESULT", Info[1])
  end
--Warning_Bag_Full: nil
  if Type == 8 then
    Table[1] = GetString(SI_ACTIONRESULT3430).." ("..GetNumBagUsedSlots(1).." / "..(GetNumBagUsedSlots(1)+ GetNumBagFreeSlots(1))..")"
  end
--Bank_Work_Done: nil
  if Type == 9 then
    Table[1] = GetString(SI_CURRENCYLOCATION1).." -> "..GetString(SI_GAMEPAD_TIMED_ACTIVTY_COMPLETED_NARRATION)
  end
--Warning_No_BasicStyle_Material: nil
  if Type == 10 then
    Table[1] = GetString(SI_TRADESKILLRESULT142)
  end
--Warning_Set_Not_Unlocked: nil
  if Type == 10.5 then
    Table[1] = GetString(SI_GAMEPAD_MARKET_LOCKED_TITLE).." -> "..Info[1]
  end
--Warning_Alchemy_Quest_BanList: ItemLink
  if Type == 11 then
    Table[1] = GetString(SI_GUILD_RECRUITMENT_CATEGORY_BLACKLIST).." -> "..Info[1]
  end
--None_For_WW: nil
  if Type == 12 then
    Table[1] = GetString(SI_WORLD_MAP_NO_QUESTS)
  end
--WW_Info: TotalNum, TotalRound
  if Type == 13 then
    Table[1] = Info[1].." |t25:25:esoui/art/icons/master_writ_alchemy.dds|t".." / "..Info[2].." "..GetString(SI_ENDLESSDUNGEONCOUNTERTYPE1)
  end
--Warning_WW_Journal_FUll: NumNeed
  if Type == 14 then
    Table[1] = GetString(SI_ERROR_QUEST_LOG_FULL).." -> "..GetString(SI_UNIT_FRAME_EMPTY_SLOT).." > "..Info[1]
  end
--Warning_WW_UndoneMaster_Start: nil
  if Type == 15 then
    Table[1] = GetString(SI_ACHIEVEMENTS_INCOMPLETE).."|t25:25:esoui/art/icons/master_writ_alchemy.dds|t".." -> "..GetString(SI_HOOK_POINT_STORE_CLEAR_SLOT)
  end
--WW_Finish: nil
  if Type == 16 then
    Table[1] = "|t25:25:esoui/art/icons/master_writ_alchemy.dds|t".." -> "..GetString(SI_GAMEPAD_TIMED_ACTIVTY_COMPLETED_NARRATION)
  end
--Warning_Out_Of_Range: nil
  if Type == 17 then
    Table[1] = SDC.MasterNpcName.." -> "..GetString(SI_ACTIONRESULT2100)
  end
--WW_Time_For_Commit: RoundNum
  if Type == 18 then
    Table[1] = Info[1].." "..GetString(SI_ENDLESSDUNGEONCOUNTERTYPE1).." -> "..GetString(SI_GUILD_BROWSER_SUBMIT_APPLICATION_DIALOG_BUTTON_SUBMIT).." ("..GetString(SI_KEYBINDINGS_CATEGORY_INTERACTION)..")"
  end
--Finish_Container: nil
  if Type == 19 then
    Table[1] = GetString(SI_ITEMTYPEDISPLAYCATEGORY26).." -> "..GetString(SI_GAMEPAD_TIMED_ACTIVTY_COMPLETED_NARRATION)
  end
--ResearchUpdate: nil
  if Type == 20 then
    Table[1] = GetString(SI_SPECIALIZEDITEMTYPE101).." -> "..GetString(SI_GAMEPAD_GROUP_FINDER_SEARCH_RESULTS_REFRESH_KEYBIND)
  end
----------------------------------
--Nothing to chat
  if not Table[1] then return end
--Push
  SDC.Chat(Table)
end

--To chat window
function SDC.Chat(Table) 
  for i = 1, #Table do
    d("[SDC] "..Table[i])
  end
  return
end