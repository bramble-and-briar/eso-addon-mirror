CompanionSidekick={name="CompanionSidekick",version="0.1.2"}
local C=CompanionSidekick
-- Collectible identifiers identify companions, not per-character unlocks.
-- Recruitment IDs are read from ESO. Story IDs are resolved from game quest
-- names in small startup batches; unresolved entries remain explicitly unknown.
C.seeds={9245,9353,9911,9912,11113,11114,12172,12173}
C.stories={
    [9245]={"Things Lost, Things Found","Family Secrets"},
    [9353]={"A Mother's Obsession","Dead Weight"},
    [9911]={"Cold Trail","Cold Blood, Old Pain","Green with Envy"},
    [9912]={"The Lost Symbol","A Mother's Request","The Princess Detective"},
    [11113]={"Between a Rock and Whetstone","Dim and Distant Pasts","Light the Way to Freedom"},
    [11114]={"Paths Unwalked","Adversarial Adventures","Tempting Fate"},
    [12172]={"Thorns and Blossoms","Uprooted","Of Crowns and Flowers"},
    [12173]={"Beyond a Veil of Twilight","Paths Out of Darkness","The Dark Behind the World"},
}
C.aliases={ ["Of Crown and Flowers"]="Of Crowns and Flowers",["Of Crowns and Thorns"]="Of Crowns and Flowers",
    ["Path Out of Darkness"]="Paths Out of Darkness" }
C.knownQuestIds={["Things Lost, Things Found"]=6662,["Family Secrets"]=6664,
    ["A Mother's Obsession"]=6666,["Dead Weight"]=6667}
function C.Clean(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x",""):gsub("|r",""):gsub("%^[%a]+","")
end
function C.InitStore(db)
    db.characters=db.characters or {};db.shared=db.shared or {};db.settings=db.settings or {}
    C.db=db
end
function C.Character(id,name)
    local record=C.db.characters[id]
    if not record then record={companions={}};C.db.characters[id]=record end
    record.name=name or record.name or "Unknown character"
    return record
end
function C.GetCharacterCompanion(char,id)
    char.companions=char.companions or {}
    char.companions[id]=char.companions[id] or {}
    return char.companions[id]
end
function C.UnlockText(record)
    if not record or record.unlocked==nil then return "Unknown" end
    return record.unlocked and "Unlocked" or "Recruit first"
end
function C.QuestSummary(entry,record)
    if not record or not record.quests then return "Not scanned" end
    for _,quest in ipairs(record.quests)do
        if quest.active then return quest.name end
    end
    if not record.unlocked then return "Recruitment" end
    for i,quest in ipairs(record.quests)do
        if i>1 and quest.complete~=true then return "Next: "..quest.name end
    end
    return "Story complete"
end
function C.Progress(entry,record)
    if not record then return "Unknown" end
    local build=C.db.shared[entry.id]
    if record.unlocked~=true then return C.UnlockText(record)end
    local storyDone=record.quests and #record.quests>1
    for _,q in ipairs(record.quests or {})do if q.complete~=true then storyDone=false end end
    if storyDone and build and build.level and build.level>=20 and entry.keepsakeUnlocked==true then return "Complete" end
    return "In progress"
end
function C.RapportText(record)
    if not record or record.rapport==nil then return "Not scanned" end
    return tostring(record.rapport).." / "..tostring(record.rapportMax or "?").."  "..(record.rapportName or "")
end
function C.AccountCounts(id)
    local unlocked,scanned,total=0,0,0
    for _,char in pairs(C.db.characters)do
        total=total+1;local r=char.companions and char.companions[id]
        if r and r.unlocked~=nil then scanned=scanned+1;if r.unlocked then unlocked=unlocked+1 end end
    end
    return unlocked,scanned,total
end
