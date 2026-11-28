-- The two conversations of a daily writ: taking it at the board, handing it in at the crate.
--
-- Board: interacting with a writ board starts a chatter whose options include one CHATTER_START_NEW_QUEST_BESTOWAL
-- option per writ on offer. Picking one makes the game offer the quest (EVENT_QUEST_OFFERED), AcceptOfferedQuest()
-- takes it, and the board's chatter starts again with what is left. When no writ option is left, the board is closed
-- (EndInteraction) if the player wants that and we took something.
--
-- Crate: the delivery crate offers "place the goods" (CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS) or "sign
-- the manifest" (CHATTER_START_COMPLETE_QUEST). Picking it brings the completion dialog (EVENT_QUEST_COMPLETE_DIALOG
-- with the journal index), and CompleteQuest() finishes the writ. CompleteQuest is called only right after our own
-- pick, and only for a crafting quest, so no other quest is ever completed by this add-on.
--
-- The option types alone do not tell a writ from any other quest giver, so the option text must contain a word of
-- the game's own wording, per client language (the table below; words as the game writes them). A language that is
-- not in the table gets nothing automated here -- crafting, bank and boxes do not depend on text.
--
-- The client's own handlers for these events are registered before any add-on file runs, so ours run after the
-- client has built its window; the calls we make are the same calls the client's buttons make.

local A = PBS_CRAFT_ASSIST

-- `writ`: a word in every writ option on a board. `place` / `sign`: the crate's two options (place may be a Lua
-- pattern: `placePattern = true`). `crafts`: a word naming each craft in the board's options, to honour the per-craft
-- switches (when none matches, the offer is taken and the craft switch is applied when crafting).
A.WORDS = {
	en = { writ = "Writ", place = "Place the goods", sign = "Sign the Manifest",
		crafts = { bs = "Blacksmith", cl = "Clothier", ww = "Woodworker", jw = "Jewelry", en = "Enchanter", al = "Alchemist", pr = "Provisioner" } },
	jp = { writ = "依頼", place = "品物を.+の中に置く", placePattern = true, sign = "伝票に署名する",
		crafts = { bs = "鍛冶", cl = "仕立", ww = "木工", jw = "宝飾", en = "付呪", al = "錬金術", pr = "調理" } },
	de = { writ = "schrieb", place = "Die Waren in die Kiste legen", sign = "Das Manifest unterschreiben",
		crafts = { bs = "Schmiede", cl = "Schneider", ww = "Schreiner", jw = "Schmuck", en = "Verzauberer", al = "Alchemisten", pr = "Versorger" } },
	fr = { writ = "Commande", place = "Placer les produits dans la caisse", sign = "Signer le manifeste" },
	es = { writ = "Encargo", place = "Colocar los objetos", sign = "Firmar el manifiesto" },
}

function A:Words()
	if self.words == nil then
		local lang = GetCVar and GetCVar("language.2") or "en"
		self.lang = lang
		self.words = self.WORDS[lang] or false
	end
	return self.words or nil
end

-- plain search; nil-safe
local function Has(text, word)
	return type(text) == "string" and type(word) == "string" and text:find(word, 1, true) ~= nil
end

-- Which craft a board option names (option key), or nil.
function A:OfferCraft(text)
	local words = self:Words()
	local crafts = words and words.crafts
	if not crafts then
		return nil
	end
	for i = 1, #self.CRAFT_ORDER do
		local key = self.CRAFT_ORDER[i]
		if Has(text, crafts[key]) then
			return key
		end
	end
	return nil
end

function A:IsWritOffer(text)
	local words = self:Words()
	if not (words and Has(text, words.writ)) then
		return false
	end
	-- where the language has craft words, one of them must be there too ("依頼" alone is too common a word in Japanese
	-- quest text), and that craft must be switched on
	if words.crafts then
		local key = self:OfferCraft(text)
		return key ~= nil and self.sv[key] == true
	end
	return true
end

function A:IsDeliverOption(text)
	local words = self:Words()
	if not words or type(text) ~= "string" then
		return false
	end
	if Has(text, words.sign) then
		return true
	end
	if words.placePattern then
		return text:find(words.place) ~= nil
	end
	return Has(text, words.place)
end

-- state of the current conversation (one table, reused)
A.talk = { offerAt = nil, deliverAt = nil, tookHere = 0, lastOptions = 0 }

-- The options of the last conversation, up to the one picked (for /pbwrit talk: when a language's words are wrong,
-- this is the measurement that shows the right ones). Two reused arrays.
A.seenText, A.seenType, A.seenCount = {}, {}, 0
local MAX_SEEN = 6
function A:NoteOption(i, text, optionType)
	if i == 1 then
		self.seenCount = 0
	end
	if i <= MAX_SEEN then
		self.seenText[i], self.seenType[i] = text, optionType
		self.seenCount = i
	end
end

function A:OnChatterBegin(optionCount)
	local sv = self.sv
	local talk = self.talk
	optionCount = tonumber(optionCount) or 0
	talk.lastOptions = optionCount
	if not (sv.autoAccept or sv.autoDeliver) then
		return
	end
	local now = GetGameTimeMilliseconds()
	if optionCount == 0 then
		self.seenCount = 0
	end
	for i = 1, optionCount do
		local text, optionType = GetChatterOption(i)
		self:NoteOption(i, text, optionType)
		if optionType == CHATTER_START_NEW_QUEST_BESTOWAL and sv.autoAccept then
			if self:IsWritOffer(text) then
				talk.offerAt = now
				self:Try(SelectChatterOption, i)
				return
			end
		elseif (optionType == CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS or optionType == CHATTER_START_COMPLETE_QUEST)
			and sv.autoDeliver and self:IsDeliverOption(text) then
			talk.deliverAt = now
			self:Try(SelectChatterOption, i)
			return
		end
	end
	-- nothing (more) to take here: leave the board if we took something from it in this conversation
	if talk.tookHere > 0 and sv.closeBoard and INTERACTION_CONVERSATION then
		talk.tookHere = 0
		self:Try(EndInteraction, INTERACTION_CONVERSATION)
	end
end

function A:OnQuestOffered()
	local talk = self.talk
	if not talk.offerAt then
		return
	end
	local fresh = GetGameTimeMilliseconds() - talk.offerAt <= self.OFFER_MS
	talk.offerAt = nil
	if fresh and self.sv.autoAccept then
		local ok = self:Try(AcceptOfferedQuest)
		if ok then
			talk.tookHere = talk.tookHere + 1
			self.stats.accepted = self.stats.accepted + 1
		end
	end
end

function A:OnQuestCompleteDialog(journalIndex)
	local talk = self.talk
	local crafting = self:IsCraftingQuest(journalIndex)
	if crafting and self.sv.boxes then
		self:RememberBoxesBeforeDelivery()
	end
	if not talk.deliverAt then
		return
	end
	local fresh = GetGameTimeMilliseconds() - talk.deliverAt <= self.DELIVER_MS
	talk.deliverAt = nil
	if fresh and self.sv.autoDeliver and crafting then
		-- the reward box may arrive before EVENT_QUEST_COMPLETE: open the window now
		self.rewardUntil = GetGameTimeMilliseconds() + self.REWARD_WINDOW_MS
		self.completedAt = GetGameTimeMilliseconds()
		local ok = self:Try(CompleteQuest)
		if ok then
			self.stats.delivered = self.stats.delivered + 1
		end
	end
end

function A:OnChatterEnd()
	local talk = self.talk
	talk.offerAt, talk.deliverAt, talk.tookHere = nil, nil, 0
end

-- A crafting quest was completed (by us or by hand): the box that arrives next is a reward box.
function A:OnQuestComplete(questType)
	if questType == QUEST_TYPE_CRAFTING then
		self.stats.completed = self.stats.completed + 1
		self.sv.totals.writs = self.sv.totals.writs + 1
		local now = GetGameTimeMilliseconds()
		self.completedAt = now
		if self.boxesBeforeDelivery then
			self:Later("boxDelivery", self.OPEN_GAP_MS, "CheckDeliveredBoxes")
		end
		-- a box that came in just before the event (the order of the two is not known): it was the reward
		local last = self.lastBox
		if last.at and now - last.at <= self.BOX_BEFORE_MS then
			last.at = nil
			self.rewardUntil = nil
			if not self.sv.boxIds[last.id] then
				self:LearnBox(last.id)
				if self.sv.boxes and GetItemId(BAG_BACKPACK, last.slot) == last.id then
					self:QueueBox(last.slot)
				end
			end
		elseif not (self.boxTakenAt and now - self.boxTakenAt <= self.BOX_BEFORE_MS) then
			-- (unless the window of our own hand-in has just taken its box)
			self.rewardUntil = now + self.REWARD_WINDOW_MS
		end
	end
end

PBS_CA_MARK("Dialog")
