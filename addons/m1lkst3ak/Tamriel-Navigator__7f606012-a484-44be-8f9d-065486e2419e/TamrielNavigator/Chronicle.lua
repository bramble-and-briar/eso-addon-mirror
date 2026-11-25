local N=TamrielNavigator
local function call(name,...)
 local f=_G[name]; if type(f)~='function' then return end
 local ok,a,b,c,d,e=pcall(f,...); if ok then return a,b,c,d,e end
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function N:chronicleInit()
 self.s.chronicle=self.s.chronicle or {quests={},zones={}}
 self.ch=self.s.chronicle
end
function N:recordZone()
 local z=call('GetUnitZone','player'); if type(z)=='string' and z~='' then self.ch.zones[z]=true end
end
function N:chronicleShow()
 self:recordZone()
 local ch=self.ch; local quests={}; local known=0; local tested=0
 if LibUespQuestData and LibUespQuestData.quests then
  for id in pairs(LibUespQuestData.quests) do
   local done=call('IsQuestComplete',id); if type(done)=='boolean' then tested=tested+1; if done then quests[id]=true end end
  end
 end
 for id in pairs(ch.quests) do quests[id]=true end
 local traits={Guardian=0,Explorer=0,Scholar=0,Mercenary=0,Outlaw=0,Patriot=0,Assassin=0}; local categories={}; local personal,account,unknown=0,0,0; local seen={}; local titles={}
 local function scan(c,s,n)
  for i=1,n or 0 do
   local id=call('GetAchievementId',c,s,i)
   if id and id>0 and not seen[id] then
    seen[id]=true
    local name,_,_,_,done=call('GetAchievementInfo',id)
    if done then
     local p=call('GetAchievementPersistenceLevel',id)
     local owner=call('GetCharIdForCompletedAchievement',id)
     local current=call('GetCurrentCharacterId')
     if (p~=nil and ACHIEVEMENT_PERSISTENCE_CHARACTER~=nil and p==ACHIEVEMENT_PERSISTENCE_CHARACTER) or (owner and current and tostring(owner)==tostring(current)) then
      personal=personal+1
      local label=((call('GetAchievementCategoryInfo',c) or '')..' '..(s and call('GetAchievementSubCategoryInfo',c,s) or '')):lower()
      local patterns={Explorer={'exploration','skyshard'},Scholar={'lore','mages guild'},Mercenary={'dungeon','undaunted','trial'},Outlaw={'thieves guild','justice'},Patriot={'alliance war','cyrodiil'},Assassin={'dark brotherhood'},Guardian={'healing'}}
      for trait,words in pairs(patterns) do for _,word in ipairs(words) do if label:find(word,1,true) then traits[trait]=traits[trait]+1; break end end end
      categories[c]=(categories[c] or 0)+1
      local has,title=call('GetAchievementRewardTitle',id); if has and title and #titles<5 then titles[#titles+1]=title end
     elseif owner and current then account=account+1 else unknown=unknown+1 end
    end
   end
  end
 end
 for c=1,call('GetNumAchievementCategories') or 0 do
  local _,subs,n=call('GetAchievementCategoryInfo',c); scan(c,nil,n)
  for s=1,subs or 0 do local _,sn=call('GetAchievementSubCategoryInfo',c,s); scan(c,s,sn) end
 end
 local top={}; for c,n in pairs(categories) do top[#top+1]={name=call('GetAchievementCategoryInfo',c) or '?',n=n} end
 table.sort(top,function(a,b) return a.n>b.n end)
 local lines={call('GetUnitName','player') or 'Adventurer', 'Completed quests identified: '..count(quests)..(tested>0 and ' (directory scan)' or ' (observed only)'), 'Regions visited since installation: '..count(ch.zones), 'Character-attributed achievements: '..personal, 'Other character / uncertain achievements: '..account..' / '..unknown}
 local zone=call('GetUnitZone','player'); if zone then lines[#lines+1]='Current region: '..zone end
 local bounty=call('GetBounty'); if type(bounty)=='number' then lines[#lines+1]='Current bounty: '..math.floor(bounty)..' gold' end
 lines[#lines+1]='IDENTITY: '..(top[1] and ('Your strongest recorded achievement field is '..top[1].name..'.') or 'Not enough attributed evidence yet.')
 for i=1,math.min(3,#top) do lines[#lines+1]=top[i].name..': '..top[i].n end
 if #titles>0 then lines[#lines+1]='Accolades: '..table.concat(titles,', ') end
 local ranked={}; for k,v in pairs(traits) do if v>0 then ranked[#ranked+1]={k=k,v=v} end end
 table.sort(ranked,function(a,b) if a.v==b.v then return a.k<b.k end; return a.v>b.v end)
 self.ch.traits=traits
 if ranked[1] then
  local identity={}; for i=1,math.min(3,#ranked) do identity[#identity+1]=ranked[i].k..' '..ranked[i].v end
  lines[#lines+1]='Identity evidence: '..table.concat(identity,' | ')
  lines[#lines+1]='Biography: Your attributed achievements most strongly reflect the path of a '..ranked[1].k:lower()..'.'
 end
 if traits.Outlaw>0 or traits.Assassin>0 then lines[#lines+1]='Conduct: documented underworld achievements; individual choices unknown.' end
 lines[#lines+1]='MORALITY: Intent unknown. Counts are evidence, not virtue scores.'
 self.title:SetText('TAMRIEL NAVIGATOR | LIVING CHRONICLE'); self.body:SetText(table.concat(lines,'\n')); self.token=(self.token or 0)+1; self:fit(); self.hud:SetHidden(false)
end
